import 'dart:math' as math;

/// Pure ranking-quality metrics for the contact retrieval eval harness.
///
/// Every function takes a ranked list of contact ids (best first) and a
/// `relevance` map of `contactId -> graded gain` (e.g. 3, 2, 1; 0 or absent =
/// irrelevant). They are deterministic, dependency-free, and match the
/// authoritative definitions in `docs/SDD_retrieval_v2.md` §3 so the printed
/// scorecard and the documentation agree.

/// Graded gain of a contact id: its relevance value, or 0 when unjudged.
double _gain(Map<String, double> relevance, String id) => relevance[id] ?? 0.0;

/// `precision@k = |{ i < k : relevance[rankedIds[i]] > 0 }| / k`.
///
/// The denominator is always `k`, even when the retriever returns fewer than
/// `k` results (the missing positions count as misses). Returns 0 when
/// `k <= 0`.
double precisionAtK(
  List<String> rankedIds,
  Map<String, double> relevance,
  int k,
) {
  if (k <= 0) {
    return 0;
  }
  final cutoff = math.min(k, rankedIds.length);
  var hits = 0;
  for (var i = 0; i < cutoff; i += 1) {
    if (_gain(relevance, rankedIds[i]) > 0) {
      hits += 1;
    }
  }
  return hits / k;
}

/// `DCG@k = Σ_{i=0}^{k-1} gain_i / log2(i + 2)`, with `gain_i = 0` for
/// positions past the end of `rankedIds`.
double dcgAtK(List<String> rankedIds, Map<String, double> relevance, int k) {
  if (k <= 0) {
    return 0;
  }
  final cutoff = math.min(k, rankedIds.length);
  var dcg = 0.0;
  for (var i = 0; i < cutoff; i += 1) {
    final gain = _gain(relevance, rankedIds[i]);
    if (gain == 0) {
      continue;
    }
    dcg += gain / _log2(i + 2);
  }
  return dcg;
}

/// `nDCG@k = DCG@k / IDCG@k`, where `IDCG@k` is the DCG of the ideal ordering
/// (all judged gains sorted descending). Returns 0 when `IDCG@k == 0`.
double ndcgAtK(List<String> rankedIds, Map<String, double> relevance, int k) {
  if (k <= 0) {
    return 0;
  }
  final idealGains = relevance.values.where((gain) => gain > 0).toList()
    ..sort((a, b) => b.compareTo(a));
  final cutoff = math.min(k, idealGains.length);
  var idcg = 0.0;
  for (var i = 0; i < cutoff; i += 1) {
    idcg += idealGains[i] / _log2(i + 2);
  }
  if (idcg == 0) {
    return 0;
  }
  return dcgAtK(rankedIds, relevance, k) / idcg;
}

/// `recall@k = |{ relevant ids in top k }| / |{ all relevant ids }|`.
///
/// Returns 0 when there are no judged-relevant ids (e.g. a no-match case).
double recallAtK(List<String> rankedIds, Map<String, double> relevance, int k) {
  final totalRelevant = relevance.values.where((gain) => gain > 0).length;
  if (totalRelevant == 0 || k <= 0) {
    return 0;
  }
  final cutoff = math.min(k, rankedIds.length);
  var hits = 0;
  for (var i = 0; i < cutoff; i += 1) {
    if (_gain(relevance, rankedIds[i]) > 0) {
      hits += 1;
    }
  }
  return hits / totalRelevant;
}

double _log2(num x) => math.log(x) / math.ln2;
