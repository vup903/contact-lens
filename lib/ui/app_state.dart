import 'package:flutter/foundation.dart';

import '../data/data.dart';
import '../domain/domain.dart';
import '../rag/hybrid_retriever.dart';
import '../rag/rag.dart';
import '../rag/semantic_contact_retriever.dart';
import '../rag/semantic/embedding_cache.dart';
import '../rag/semantic/runtime_embedding_model.dart';
import '../rag/semantic/semantic_reranker.dart';
import '../scan/scan.dart';

class ContactLensState extends ChangeNotifier {
  ContactLensState({
    ContactRepository repository = const SharedPreferencesContactRepository(),
  }) : _repository = repository;

  final ContactRepository _repository;
  final _recommender = const LocalContactRecommender();

  // Real multilingual MiniLM embeddings. Known text resolves from baked offline
  // vectors; free-form text is embedded at request time via the local service
  // (tool/embed/serve_embeddings.py) after `warm(...)`. Unreachable service =>
  // zero vector => graceful lexical fallback.
  final RuntimeEmbeddingModel _embedModel = RuntimeEmbeddingModel();

  // Tier-2 retriever: lexical candidates plus a gated semantic tier that both
  // *recalls* contacts lexical missed and *reranks* the pool. A cross-query
  // embedding cache embeds each unchanged contact at most once.
  late final HybridContactRetriever _hybrid = HybridContactRetriever(
    reranker: SemanticReranker(model: _embedModel),
    semantic: SemanticContactRetriever(model: _embedModel),
    cache: EmbeddingCache(),
  );

  var _contacts = <Contact>[];
  var _groups = <ContactGroup>[];
  RagManifest _manifest = RagManifest.build(const <Contact>[]);
  var _isLoading = true;
  var _hybridEnabled = true;
  var _lastRerankFired = false;

  List<Contact> get contacts => List.unmodifiable(_contacts);
  List<ContactGroup> get groups => List.unmodifiable(_groups);
  RagManifest get manifest => _manifest;
  bool get isLoading => _isLoading;

  /// When true, queries go through the hybrid (lexical + gated semantic rerank)
  /// retriever; when false, the lexical-only baseline runs.
  bool get hybridEnabled => _hybridEnabled;

  /// Whether the semantic rerank tier actually fired on the most recent query
  /// (the confidence gate let some queries through on lexical alone).
  bool get lastRerankFired => _lastRerankFired;

  void setHybridEnabled(bool value) {
    if (_hybridEnabled == value) {
      return;
    }
    _hybridEnabled = value;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final dataset = await _repository.load();
    _contacts = dataset.contacts;
    _groups = dataset.groups;
    _manifest = dataset.manifest;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> upsertContact(Contact contact) async {
    final contacts = List<Contact>.from(_contacts);
    final index = contacts.indexWhere((item) => item.id == contact.id);
    final value = contact.copyWith(updatedAt: DateTime.now().toUtc());
    if (index >= 0) {
      contacts[index] = value;
    } else {
      contacts.add(value);
    }
    final dataset = await _repository.saveContacts(contacts);
    _contacts = dataset.contacts;
    _groups = dataset.groups;
    _manifest = dataset.manifest;
    notifyListeners();
  }

  Future<void> deleteContact(String contactId) async {
    final contacts = _contacts.where((item) => item.id != contactId).toList();
    final dataset = await _repository.saveContacts(contacts);
    _contacts = dataset.contacts;
    _groups = dataset.groups;
    _manifest = dataset.manifest;
    notifyListeners();
  }

  Future<void> addContactFromParsedCard(ParsedBusinessCard parsed) async {
    final contact = parsed.toContact(
      id: newLocalId('scan'),
      createdAt: DateTime.now().toUtc(),
    );
    await upsertContact(contact);
  }

  Future<void> resetToSamples() async {
    final dataset = await _repository.resetToSamples();
    _contacts = dataset.contacts;
    _groups = dataset.groups;
    _manifest = dataset.manifest;
    notifyListeners();
  }

  /// Whether the embedding service was reachable on the most recent hybrid query
  /// (false when free-form semantics fell back to precomputed/lexical only).
  bool get embedServiceReachable => _embedModel.serviceReachable;

  Future<LocalRecommendation> recommend(String query) async {
    final trimmed = query.trim();
    // The lexical-only path (toggle off) and the empty-query case both reuse the
    // recommender's existing copy/empty-state messaging.
    if (!_hybridEnabled || trimmed.isEmpty) {
      _lastRerankFired = false;
      return _recommender.recommend(query, _contacts);
    }

    // Warm runtime embeddings for the query (and any not-yet-known contacts) so
    // the semantic tier works on free-form input, not just precomputed queries.
    await _embedModel.warm(<String>[
      trimmed,
      for (final contact in _contacts) _contactEmbedText(contact),
    ]);

    final retrieved = _hybrid.retrieve(trimmed, _contacts, k: 5);
    _lastRerankFired =
        retrieved.any((item) => item.matchReason.contains('semantic rerank'));
    return _buildHybridRecommendation(trimmed, retrieved);
  }

  /// Mirror of the text the semantic tier embeds for a contact (field values,
  /// without the field-name keys), so [recommend] can warm them.
  String _contactEmbedText(Contact contact) {
    final document = contactToRagDocument(contact);
    return document.fields.values.where((value) => value.isNotEmpty).join(' ');
  }

  LocalRecommendation _buildHybridRecommendation(
    String query,
    List<RetrievedContact> retrieved,
  ) {
    if (retrieved.isEmpty) {
      return LocalRecommendation(
        analysis: 'No local contact has enough matching evidence for "$query".',
        recommendations: const <ContactRecommendation>[],
        suggestions:
            'Add more structured notes, groups, industries, or job titles to improve local RAG recall.',
      );
    }

    final topFields = retrieved
        .expand((item) => item.matchedFields)
        .where((field) => field != 'phrase')
        .toSet()
        .toList()
      ..sort();
    final tier = _lastRerankFired
        ? 'hybrid retrieval (lexical candidates + semantic recall & rerank)'
        : 'lexical tier only (confidence gate stayed confident)';

    return LocalRecommendation(
      analysis:
          'Found ${retrieved.length} candidate(s) using $tier. Strongest evidence came from ${topFields.isEmpty ? 'phrase matches' : topFields.join(', ')}.',
      recommendations: retrieved
          .map(
            (item) => ContactRecommendation(
              contact: item.contact,
              reason: item.matchReason,
              score: item.score,
              matchedFields: item.matchedFields,
            ),
          )
          .toList(growable: false),
      suggestions:
          'Review the matched fields before reaching out. This assistant never invents background beyond saved contact data.',
    );
  }
}

