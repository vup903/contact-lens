// Hybrid-vs-lexical retrieval scorecard for Contact Lens.
//
// Runs Workstream A's labeled eval set (`evalCases`) through BOTH the lexical
// baseline and the HybridContactRetriever, prints each scorecard, and gates on
// the SDD §4-C / §8 acceptance property: mean nDCG@5(hybrid) >= nDCG@5(lexical).
// Exits non-zero if the hybrid tier regresses, so CI can catch a bad gate or
// embedding change.
//
//   flutter pub get
//   dart run tool/eval_hybrid.dart
//
// Soft dependency on Workstream A: imports `package:contact_lens/eval/eval.dart`
// (runEval + evalCases). Per the A -> C merge order this resolves on `main`
// once A has landed; it is the last piece of Workstream C.
//
// Pure-Dart entry point: domain, rag, hybrid retriever, and the eval harness
// only — no Flutter device or mobile-only plugins required.

import 'dart:io';

import 'package:contact_lens/eval/eval.dart';
import 'package:contact_lens/rag/hybrid_retriever.dart';
import 'package:contact_lens/rag/rag.dart';
import 'package:contact_lens/rag/semantic_contact_retriever.dart';
import 'package:contact_lens/rag/semantic/precomputed_embedding_model.dart';
import 'package:contact_lens/rag/semantic/semantic_reranker.dart';

void main(List<String> args) {
  // All semantic components share one precomputed (real multilingual MiniLM,
  // ONNX) embedding model, so the comparison is apples-to-apples.
  const model = PrecomputedEmbeddingModel();
  const lexical = WeightedContactRetriever();
  const semantic = SemanticContactRetriever(model: model);
  const hybrid = HybridContactRetriever(
    reranker: SemanticReranker(model: model),
    semantic: semantic,
  );

  final lexicalReport = runEval(lexical, evalCases);
  final semanticReport = runEval(semantic, evalCases);
  final hybridReport = runEval(hybrid, evalCases);

  _printScorecard(lexicalReport, retrieverLabel: 'WeightedContactRetriever (lexical baseline)');
  stdout.writeln('');
  _printScorecard(semanticReport, retrieverLabel: 'SemanticContactRetriever (precomputed MiniLM, recall only)');
  stdout.writeln('');
  _printScorecard(hybridReport, retrieverLabel: 'HybridContactRetriever (lexical + gated semantic recall & rerank)');
  stdout.writeln('');

  final lexicalNdcg5 = lexicalReport.meanNdcgAtK[5] ?? 0;
  final semanticNdcg5 = semanticReport.meanNdcgAtK[5] ?? 0;
  final hybridNdcg5 = hybridReport.meanNdcgAtK[5] ?? 0;
  final delta = hybridNdcg5 - lexicalNdcg5;

  stdout.writeln(
    'Comparison: nDCG@5  lexical ${_fmt(lexicalNdcg5)}   '
    'semantic ${_fmt(semanticNdcg5)}   hybrid ${_fmt(hybridNdcg5)}   '
    '(hybrid Δ vs lexical ${delta >= 0 ? '+' : ''}${_fmt(delta)})',
  );

  // Tiny tolerance so floating-point noise on a tie does not fail the gate.
  if (hybridNdcg5 + 1e-9 < lexicalNdcg5) {
    stderr.writeln(
      'FAIL: hybrid nDCG@5 ${_fmt(hybridNdcg5)} regressed below lexical ${_fmt(lexicalNdcg5)}.',
    );
    exit(1);
  }
  stdout.writeln('PASS: hybrid nDCG@5 >= lexical nDCG@5 on the labeled set.');
}

void _printScorecard(EvalReport report, {required String retrieverLabel}) {
  stdout.writeln('Contact Lens — retrieval eval scorecard');
  stdout.writeln('Retriever: $retrieverLabel');
  stdout.writeln(
    'Cases: ${report.cases.length}   '
    'Cutoffs: ${report.ks.map((k) => 'k=$k').join(', ')}',
  );
  stdout.writeln('');

  stdout.writeln('Per query (P = precision, N = nDCG):');
  for (final row in report.cases) {
    final metrics = report.ks
        .map((k) => 'P@$k ${_fmt(row.precisionAtK[k])}  N@$k ${_fmt(row.ndcgAtK[k])}')
        .join('   ');
    final note = row.evalCase.note.isEmpty ? '' : ' [${row.evalCase.note}]';
    stdout.writeln('  • ${_truncate(row.evalCase.query, 52)}$note');
    stdout.writeln('      $metrics');
    stdout.writeln('      top: ${_topIds(row.rankedIds)}');
  }
  stdout.writeln('');

  stdout.writeln('Aggregate (mean over ${report.cases.length} queries):');
  for (final k in report.ks) {
    stdout.writeln(
      '  k=$k   precision@$k ${_fmt(report.meanPrecisionAtK[k])}   '
      'nDCG@$k ${_fmt(report.meanNdcgAtK[k])}',
    );
  }
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
