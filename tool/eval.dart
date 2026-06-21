// Retrieval evaluation scorecard for Contact Lens.
//
// Runs the labeled eval set against the lexical WeightedContactRetriever and
// prints a per-query + aggregate scorecard (precision@1/@3 and nDCG@5). Exits
// non-zero when mean nDCG@5 falls below the documented floor, so CI can gate on
// retrieval quality.
//
//   flutter pub get
//   dart run tool/eval.dart
//
// Pure-Dart entry point: imports only domain, rag, sample data, and the eval
// harness — no Flutter device or mobile-only plugins required.

import 'dart:io';

import 'package:contact_lens/rag/rag.dart';
import 'package:contact_lens/eval/eval.dart';

/// CI gate: the lexical baseline must hold mean nDCG@5 at or above this floor.
/// Tune empirically via this tool; documented here so the gate is auditable.
const _ndcgFloorAtK5 = 0.45;

void main(List<String> args) {
  const retriever = WeightedContactRetriever();
  final report = runEval(retriever, evalCases);

  _printScorecard(report, retrieverLabel: 'WeightedContactRetriever (lexical)');

  final ndcg5 = report.meanNdcgAtK[5];
  if (ndcg5 != null && ndcg5 < _ndcgFloorAtK5) {
    stderr.writeln(
      'FAIL: mean nDCG@5 ${_fmt(ndcg5)} is below floor ${_fmt(_ndcgFloorAtK5)}.',
    );
    exit(1);
  }
  stdout.writeln('PASS: mean nDCG@5 meets the ${_fmt(_ndcgFloorAtK5)} floor.');
}

void _printScorecard(EvalReport report, {required String retrieverLabel}) {
  stdout.writeln('Contact Lens — retrieval eval scorecard');
  stdout.writeln('Retriever: $retrieverLabel');
  stdout.writeln(
    'Cases: ${report.cases.length}   '
    'Cutoffs: ${report.ks.map((k) => 'k=$k').join(', ')}',
  );
  stdout.writeln('');

  // Per-query rows.
  stdout.writeln('Per query (P = precision, N = nDCG):');
  for (final row in report.cases) {
    final metrics = report.ks
        .map((k) => 'P@$k ${_fmt(row.precisionAtK[k])}  '
            'N@$k ${_fmt(row.ndcgAtK[k])}')
        .join('   ');
    final note = row.evalCase.note.isEmpty ? '' : ' [${row.evalCase.note}]';
    stdout.writeln('  • ${_truncate(row.evalCase.query, 52)}$note');
    stdout.writeln('      $metrics');
    stdout.writeln('      top: ${_topIds(row.rankedIds)}');
  }
  stdout.writeln('');

  // Aggregate.
  stdout.writeln('Aggregate (mean over ${report.cases.length} queries):');
  for (final k in report.ks) {
    stdout.writeln(
      '  k=$k   precision@$k ${_fmt(report.meanPrecisionAtK[k])}   '
      'nDCG@$k ${_fmt(report.meanNdcgAtK[k])}',
    );
  }
  stdout.writeln('');

  // Headline figures called out in the SDD acceptance criteria.
  stdout.writeln(
    'Headline: precision@1 ${_fmt(report.meanPrecisionAtK[1])}   '
    'precision@3 ${_fmt(report.meanPrecisionAtK[3])}   '
    'nDCG@5 ${_fmt(report.meanNdcgAtK[5])}',
  );
}

String _topIds(List<String> rankedIds, {int n = 3}) {
  if (rankedIds.isEmpty) {
    return '(no results)';
  }
  return rankedIds.take(n).join(', ');
}

String _truncate(String value, int max) {
  if (value.length <= max) {
    return value;
  }
  return '${value.substring(0, max - 1)}…';
}

String _fmt(double? value) => (value ?? 0).toStringAsFixed(3);
