import '../domain/domain.dart';
import 'contact_retriever.dart';
import 'retrieve_contacts.dart';
import 'semantic_contact_retriever.dart';
import 'semantic/embedding_cache.dart';
import 'semantic/semantic_reranker.dart';

/// Decision returned by [ConfidenceGate]: whether Tier 1 was confident enough to
/// skip the semantic rerank, plus the signals that drove the call (handy for the
/// UI and for explaining the cost tradeoff).
class GateDecision {
  const GateDecision({
    required this.shouldRerank,
    required this.topScore,
    required this.margin,
    required this.reason,
  });

  final bool shouldRerank;
  final double topScore;
  final double margin;
  final String reason;
}

/// Cheap, deterministic gate that decides when the lexical tier is "unsure"
/// enough to justify paying for a semantic rerank. It fires when the top score
/// is weak (`topScore < minTopScore`) or the lead over the runner-up is thin
/// (`top1 - top2 < minMargin`) — i.e. exactly the cases where keyword overlap
/// alone is least trustworthy. Thresholds are tuned empirically via the eval.
class ConfidenceGate {
  const ConfidenceGate({
    this.minTopScore = 14,
    this.minMargin = 5,
  });

  final double minTopScore;
  final double minMargin;

  GateDecision evaluate(List<RetrievedContact> ranked) {
    if (ranked.isEmpty) {
      return const GateDecision(
        shouldRerank: false,
        topScore: 0,
        margin: 0,
        reason: 'no lexical candidates to rerank',
      );
    }

    final topScore = ranked.first.score;
    final secondScore = ranked.length > 1 ? ranked[1].score : 0.0;
    final margin = topScore - secondScore;
    final weakTop = topScore < minTopScore;
    final thinMargin = margin < minMargin;

    final reasons = <String>[
      if (weakTop) 'top score $topScore < $minTopScore',
      if (thinMargin) 'margin ${margin.toStringAsFixed(1)} < $minMargin',
    ];

    return GateDecision(
      shouldRerank: weakTop || thinMargin,
      topScore: topScore,
      margin: margin,
      reason: reasons.isEmpty
          ? 'lexical confident (top $topScore, margin ${margin.toStringAsFixed(1)})'
          : reasons.join(' and '),
    );
  }
}

/// Tier 1 (lexical) → confidence gate → Tier 2 (semantic recall + rerank).
///
/// The lexical retriever produces a candidate pool. When the gate judges that
/// pool confident, it is returned as-is (zero extra cost). When it judges the
/// pool unsure — a weak top score, a thin margin, or fewer than two candidates
/// (e.g. a cross-language query with no token overlap) — it pays for the
/// semantic tier:
///
///  1. **Recall** (optional): when a [semantic] retriever is supplied, contacts
///     it finds that lexical missed entirely are merged into the pool with a
///     zero lexical score, so the rerank can promote them. This is what lets a
///     Chinese query surface an English-only contact that shares no tokens.
///  2. **Rerank**: the [reranker] re-orders the (possibly widened) pool by a
///     blended lexical+semantic score.
///
/// With [semantic] left `null` (the default) the recall step is skipped and the
/// behavior is exactly rerank-only, so existing callers and tests are
/// unaffected. Either way the result is a plain [List<RetrievedContact>] —
/// callers never know which tier ran, except that semantic results carry a note
/// in [RetrievedContact.matchReason].
class HybridContactRetriever implements ContactRetriever {
  const HybridContactRetriever({
    this.lexical = const WeightedContactRetriever(),
    this.reranker = const SemanticReranker(),
    this.gate = const ConfidenceGate(),
    this.semantic,
    this.candidatePool = 12,
    this.recallPool = 8,
    this.cache,
  });

  final WeightedContactRetriever lexical;
  final SemanticReranker reranker;
  final ConfidenceGate gate;

  /// Optional recall tier. When non-null, the gate-fired path widens the
  /// candidate pool with semantically-relevant contacts lexical missed. When
  /// null, the retriever is rerank-only (the original behavior).
  final SemanticContactRetriever? semantic;

  /// How many lexical candidates to consider for reranking before truncating to
  /// `k`. A pool wider than `k` gives the semantic tier room to promote a
  /// contact that lexical ranked just outside the top-`k`.
  final int candidatePool;

  /// How many contacts the recall tier may add to the pool when it fires.
  final int recallPool;

  /// Optional cross-query embedding cache. `null` (the default, so the const
  /// constructor stays usable) means embeddings are computed per call.
  final EmbeddingCache? cache;

  @override
  List<RetrievedContact> retrieve(
    String userNeed,
    List<Contact> contacts, {
    int k = 8,
  }) {
    final poolSize = k > candidatePool ? k : candidatePool;
    final lexicalPool = lexical.retrieve(userNeed, contacts, k: poolSize);

    final decision = gate.evaluate(lexicalPool);
    // Confident lexical result: return as-is, zero extra cost.
    if (lexicalPool.length >= 2 && !decision.shouldRerank) {
      return lexicalPool.take(k).toList(growable: false);
    }

    // Unsure: pay for the semantic tier. Recall first (if available), then
    // rerank the widened pool.
    final pool = semantic == null
        ? lexicalPool
        : _mergeRecall(
            lexicalPool,
            semantic!.retrieve(userNeed, contacts, k: recallPool),
          );
    if (pool.length < 2) {
      return pool.take(k).toList(growable: false);
    }

    final reranked = reranker.rerank(userNeed, pool, cache: cache);
    return reranked.take(k).toList(growable: false);
  }

  /// Unions the lexical pool with semantically-recalled contacts. Lexical
  /// entries win on identity (they carry a real lexical score for blending);
  /// recall-only contacts enter with a zero lexical score so the rerank scores
  /// them on semantic evidence alone.
  List<RetrievedContact> _mergeRecall(
    List<RetrievedContact> lexicalPool,
    List<RetrievedContact> semanticPool,
  ) {
    final seen = {for (final item in lexicalPool) item.contact.id};
    final merged = List<RetrievedContact>.from(lexicalPool);
    for (final item in semanticPool) {
      if (seen.add(item.contact.id)) {
        merged.add(
          RetrievedContact(
            contact: item.contact,
            score: 0,
            matchedFields: const <String>['semantic'],
            matchReason:
                '${item.contact.displayName}: recalled by the semantic tier.',
          ),
        );
      }
    }
    return merged;
  }
}
