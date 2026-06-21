import 'package:contact_lens/data/sample_data.dart';
import 'package:contact_lens/rag/rag.dart';

import 'metrics.dart';

/// A single labeled evaluation query.
///
/// [relevance] maps `contactId -> graded gain` (e.g. 3, 2, 1; 0 or absent means
/// irrelevant). An empty map encodes a deliberate no-match case — the ideal
/// result is to surface nothing relevant.
class EvalCase {
  const EvalCase({
    required this.query,
    this.relevance = const <String, double>{},
    this.note = '',
  });

  final String query;
  final Map<String, double> relevance;

  /// Optional human-readable label for the scorecard (language, intent, etc.).
  final String note;
}

/// Per-query metric row, retained so the scorecard can print each query
/// alongside the aggregate.
class EvalCaseResult {
  const EvalCaseResult({
    required this.evalCase,
    required this.rankedIds,
    required this.precisionAtK,
    required this.ndcgAtK,
  });

  final EvalCase evalCase;

  /// Contact ids the retriever returned, best first (truncated to the largest
  /// evaluated k).
  final List<String> rankedIds;

  /// k -> precision@k for this query.
  final Map<int, double> precisionAtK;

  /// k -> nDCG@k for this query.
  final Map<int, double> ndcgAtK;
}

/// Aggregate evaluation report over a set of [EvalCase]s.
class EvalReport {
  const EvalReport({
    required this.ks,
    required this.cases,
    required this.meanPrecisionAtK,
    required this.meanNdcgAtK,
  });

  /// The cutoffs that were evaluated, ascending.
  final List<int> ks;

  /// Per-query rows, in input order.
  final List<EvalCaseResult> cases;

  /// k -> mean precision@k across all cases.
  final Map<int, double> meanPrecisionAtK;

  /// k -> mean nDCG@k across all cases.
  final Map<int, double> meanNdcgAtK;
}

/// Runs [retriever] over every [EvalCase] and aggregates precision@k / nDCG@k.
///
/// The corpus is the shared [sampleContacts] set that the labeled dataset is
/// defined over, so the frozen `runEval` signature (SDD §3) stays stable across
/// the lexical, hybrid, and any future retriever. Each query is ranked once at
/// the largest requested k; per-k metrics are sliced from that single ranking.
EvalReport runEval(
  ContactRetriever retriever,
  List<EvalCase> cases, {
  List<int> ks = const [1, 3, 5],
}) {
  final sortedKs = (ks.toList()..sort()).where((k) => k > 0).toList();
  final maxK = sortedKs.isEmpty ? 0 : sortedKs.last;

  final caseResults = <EvalCaseResult>[];
  final precisionSums = <int, double>{for (final k in sortedKs) k: 0.0};
  final ndcgSums = <int, double>{for (final k in sortedKs) k: 0.0};

  for (final evalCase in cases) {
    final ranked = retriever.retrieve(
      evalCase.query,
      sampleContacts,
      k: maxK,
    );
    final rankedIds = ranked
        .map((result) => result.contact.id)
        .toList(growable: false);

    final precision = <int, double>{};
    final ndcg = <int, double>{};
    for (final k in sortedKs) {
      final p = precisionAtK(rankedIds, evalCase.relevance, k);
      final n = ndcgAtK(rankedIds, evalCase.relevance, k);
      precision[k] = p;
      ndcg[k] = n;
      precisionSums[k] = precisionSums[k]! + p;
      ndcgSums[k] = ndcgSums[k]! + n;
    }

    caseResults.add(
      EvalCaseResult(
        evalCase: evalCase,
        rankedIds: rankedIds,
        precisionAtK: precision,
        ndcgAtK: ndcg,
      ),
    );
  }

  final divisor = cases.isEmpty ? 1 : cases.length;
  return EvalReport(
    ks: sortedKs,
    cases: caseResults,
    meanPrecisionAtK: {
      for (final k in sortedKs) k: precisionSums[k]! / divisor,
    },
    meanNdcgAtK: {
      for (final k in sortedKs) k: ndcgSums[k]! / divisor,
    },
  );
}
