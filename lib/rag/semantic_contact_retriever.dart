import '../domain/domain.dart';
import 'contact_retriever.dart';
import 'contact_to_text.dart';
import 'retrieve_contacts.dart';
import 'semantic/embedding_model.dart';
import 'semantic/precomputed_embedding_model.dart';
import 'semantic/vector_ops.dart';

/// Pure semantic retriever: embeds the query and every contact, ranks by cosine
/// similarity.
///
/// Unlike the lexical tier this needs no shared tokens, so it *recalls* contacts
/// whose wording differs from the query — synonyms, paraphrase, and especially
/// cross-language intent (a Chinese query against an English contact). It is the
/// recall half of [HybridContactRetriever] and is also a first-class
/// [ContactRetriever], so the eval harness can score it standalone.
///
/// When the query has no embedding (e.g. an arbitrary query outside the
/// precomputed set, which yields a zero vector) it returns nothing rather than
/// ranking by a meaningless all-zero similarity.
class SemanticContactRetriever implements ContactRetriever {
  const SemanticContactRetriever({
    this.model = const PrecomputedEmbeddingModel(),
    this.minSimilarity = 0.2,
  });

  final EmbeddingModel model;

  /// Cosine floor below which a contact is treated as not semantically relevant.
  /// Keeps unrelated contacts (and the deliberate no-match query) out of the
  /// result rather than always returning the full corpus ranked by noise.
  final double minSimilarity;

  @override
  List<RetrievedContact> retrieve(
    String userNeed,
    List<Contact> contacts, {
    int k = 8,
  }) {
    final queryVector = model.embed(userNeed);
    if (queryVector.every((value) => value == 0)) {
      return const <RetrievedContact>[];
    }

    final scored = <RetrievedContact>[];
    for (final contact in contacts) {
      final document = contactToRagDocument(contact);
      final text = document.fields.values.where((v) => v.isNotEmpty).join(' ');
      final similarity = cosineSimilarity(queryVector, model.embed(text));
      if (similarity < minSimilarity) {
        continue;
      }
      scored.add(
        RetrievedContact(
          contact: contact,
          score: similarity,
          matchedFields: const <String>['semantic'],
          matchReason:
              '${contact.displayName}: semantic match (cosine ${similarity.toStringAsFixed(2)}).',
        ),
      );
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.contact.displayName.compareTo(b.contact.displayName);
    });
    return scored.take(k).toList(growable: false);
  }
}
