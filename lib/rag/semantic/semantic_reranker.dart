import '../../domain/domain.dart';
import '../contact_to_text.dart';
import '../retrieve_contacts.dart';
import 'embedding_cache.dart';
import 'embedding_model.dart';
import 'vector_ops.dart';

/// Re-scores an already-retrieved candidate list by semantic similarity to the
/// query and blends that with the lexical score.
///
/// Lexical scores are unbounded (they grow with field weights and occurrence
/// counts), so they are min-maxed to [0, 1] across the candidate set before
/// blending with cosine similarity (mapped from [-1, 1] to [0, 1]). The blend
/// is `(1 - semanticWeight) * lexical + semanticWeight * semantic`, so
/// `semanticWeight = 0` reproduces the lexical order and `1` is pure semantic.
class SemanticReranker {
  const SemanticReranker({
    this.model = const HashingEmbeddingModel(),
    this.semanticWeight = 0.5,
  }) : assert(
          semanticWeight >= 0 && semanticWeight <= 1,
          'semanticWeight must be in [0, 1]',
        );

  final EmbeddingModel model;
  final double semanticWeight;

  /// Returns [candidates] re-ranked by the blended score. The returned
  /// [RetrievedContact.score] is the blended value in [0, 1] and [matchReason]
  /// is annotated with the cosine contribution. Order is unchanged when
  /// [candidates] has fewer than two entries (nothing to reorder).
  List<RetrievedContact> rerank(
    String userNeed,
    List<RetrievedContact> candidates, {
    EmbeddingCache? cache,
  }) {
    if (candidates.length < 2) {
      return candidates;
    }

    final queryVector = model.embed(userNeed);
    var maxLexical = 0.0;
    for (final candidate in candidates) {
      if (candidate.score > maxLexical) {
        maxLexical = candidate.score;
      }
    }

    final reranked = candidates.map((candidate) {
      final documentVector = cache != null
          ? cache.resolve(candidate.contact, () => _embedContact(candidate))
          : _embedContact(candidate);
      // Clamp to [0, 1]: a negative cosine carries no positive evidence, so it
      // should not pull the blended score below a pure no-match.
      final similarity = cosineSimilarity(queryVector, documentVector).clamp(0.0, 1.0);
      final lexicalNorm = maxLexical > 0 ? candidate.score / maxLexical : 0.0;
      final blended = (1 - semanticWeight) * lexicalNorm + semanticWeight * similarity;

      return _RerankedCandidate(
        contact: candidate.contact,
        blended: blended,
        similarity: similarity.toDouble(),
        matchedFields: candidate.matchedFields,
        baseReason: candidate.matchReason,
      );
    }).toList()
      ..sort((a, b) {
        final byScore = b.blended.compareTo(a.blended);
        if (byScore != 0) {
          return byScore;
        }
        return a.contact.displayName.compareTo(b.contact.displayName);
      });

    return reranked
        .map(
          (item) => RetrievedContact(
            contact: item.contact,
            score: item.blended,
            matchedFields: item.matchedFields,
            matchReason:
                '${item.baseReason} | semantic rerank: cosine ${item.similarity.toStringAsFixed(2)} '
                '(weight ${semanticWeight.toStringAsFixed(2)}).',
          ),
        )
        .toList(growable: false);
  }

  /// Embeds the contact's field *values* (not the "name:"/"company:" keys, which
  /// would inject query-word noise like "company") for the semantic comparison.
  List<double> _embedContact(RetrievedContact candidate) {
    final document = contactToRagDocument(candidate.contact);
    final text = document.fields.values.where((v) => v.isNotEmpty).join(' ');
    return model.embed(text);
  }
}

class _RerankedCandidate {
  const _RerankedCandidate({
    required this.contact,
    required this.blended,
    required this.similarity,
    required this.matchedFields,
    required this.baseReason,
  });

  final Contact contact;
  final double blended;
  final double similarity;
  final List<String> matchedFields;
  final String baseReason;
}
