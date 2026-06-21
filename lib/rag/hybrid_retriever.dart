import '../domain/domain.dart';
import 'contact_retriever.dart';
import 'retrieve_contacts.dart';
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

/// Tier 1 (lexical) → confidence gate → Tier 2 (semantic rerank).
///
/// The lexical retriever produces a candidate pool. When the gate judges that
/// pool confident, it is returned as-is (zero extra cost). When it judges the
/// pool unsure, the semantic reranker re-orders it. Either way the result is a
/// plain [List<RetrievedContact>], so callers (UI, eval harness) never know or
/// care which tier ran — except that reranked results carry a "semantic rerank"
/// note in [RetrievedContact.matchReason].
class HybridContactRetriever implements ContactRetriever {
  const HybridContactRetriever({
    this.lexical = const WeightedContactRetriever(),
    this.reranker = const SemanticReranker(),
    this.gate = const ConfidenceGate(),
    this.candidatePool = 12,
    this.cache,
  });

  final WeightedContactRetriever lexical;
  final SemanticReranker reranker;
  final ConfidenceGate gate;

  /// How many lexical candidates to consider for reranking before truncating to
  /// `k`. A pool wider than `k` gives the semantic tier room to promote a
  /// contact that lexical ranked just outside the top-`k`.
  final int candidatePool;

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
    final candidates = lexical.retrieve(userNeed, contacts, k: poolSize);
    if (candidates.length < 2) {
      return candidates.take(k).toList(growable: false);
    }

    final decision = gate.evaluate(candidates);
    if (!decision.shouldRerank) {
      return candidates.take(k).toList(growable: false);
    }

    final reranked = reranker.rerank(userNeed, candidates, cache: cache);
    return reranked.take(k).toList(growable: false);
  }
}
