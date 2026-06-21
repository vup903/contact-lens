import '../../domain/domain.dart';

/// Memoizes contact embeddings so the semantic tier never re-embeds unchanged
/// contacts across queries.
///
/// Entries are keyed by [contactContentHash] — the same content fingerprint the
/// RAG manifest uses to decide when an index needs rebuilding. If a contact's
/// indexable fields change, its hash changes and the stale vector is simply
/// never hit again (the model recomputes under the new key).
///
/// This is intentionally a separate mutable object rather than a field baked
/// into [HybridContactRetriever], which stays `const`-constructible. Callers
/// that want cross-query reuse (e.g. the UI) create one cache and pass it in.
class EmbeddingCache {
  EmbeddingCache();

  final Map<String, List<double>> _store = <String, List<double>>{};

  int get length => _store.length;

  /// Returns the cached vector for [contact], or computes and stores it via
  /// [compute] on first sight of this content hash.
  List<double> resolve(Contact contact, List<double> Function() compute) {
    return _store.putIfAbsent(contactContentHash(contact), compute);
  }

  void clear() => _store.clear();
}
