import 'package:flutter/foundation.dart';

import '../data/data.dart';
import '../domain/domain.dart';
import '../rag/hybrid_retriever.dart';
import '../rag/rag.dart';
import '../rag/semantic/embedding_cache.dart';
import '../scan/scan.dart';

class ContactLensState extends ChangeNotifier {
  ContactLensState({
    ContactRepository repository = const SharedPreferencesContactRepository(),
  }) : _repository = repository;

  final ContactRepository _repository;
  final _recommender = const LocalContactRecommender();

  // Tier-2 retriever. Holds a cross-query embedding cache so unchanged contacts
  // are embedded at most once per session.
  final HybridContactRetriever _hybrid =
      HybridContactRetriever(cache: EmbeddingCache());

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

  LocalRecommendation recommend(String query) {
    final trimmed = query.trim();
    // The lexical-only path (toggle off) and the empty-query case both reuse the
    // recommender's existing copy/empty-state messaging.
    if (!_hybridEnabled || trimmed.isEmpty) {
      _lastRerankFired = false;
      return _recommender.recommend(query, _contacts);
    }

    final retrieved = _hybrid.retrieve(trimmed, _contacts, k: 5);
    _lastRerankFired =
        retrieved.any((item) => item.matchReason.contains('semantic rerank'));
    return _buildHybridRecommendation(trimmed, retrieved);
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
        ? 'hybrid retrieval (lexical candidates + semantic rerank)'
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

