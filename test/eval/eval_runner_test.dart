import 'package:contact_lens/data/sample_data.dart';
import 'package:contact_lens/domain/domain.dart';
import 'package:contact_lens/eval/eval.dart';
import 'package:contact_lens/rag/rag.dart';
import 'package:flutter_test/flutter_test.dart';

/// Retriever that returns a fixed id order regardless of the query, so the
/// runner's aggregation can be checked against hand-computed metrics.
class _FixedOrderRetriever implements ContactRetriever {
  const _FixedOrderRetriever(this.order);

  final List<String> order;

  @override
  List<RetrievedContact> retrieve(
    String userNeed,
    List<Contact> contacts, {
    int k = 8,
  }) {
    final byId = {for (final c in contacts) c.id: c};
    return order
        .where(byId.containsKey)
        .take(k)
        .map((id) => RetrievedContact(
              contact: byId[id]!,
              score: 1,
              matchedFields: const <String>[],
              matchReason: '',
            ))
        .toList(growable: false);
  }
}

void main() {
  test('runEval aggregates per-k means across cases', () {
    final retriever = _FixedOrderRetriever(
      sampleContacts.map((c) => c.id).toList(),
    );
    final firstId = sampleContacts.first.id;
    final secondId = sampleContacts[1].id;

    final cases = <EvalCase>[
      EvalCase(query: 'hit at rank 1', relevance: {firstId: 3}),
      EvalCase(query: 'hit at rank 2', relevance: {secondId: 3}),
    ];

    final report = runEval(retriever, cases);

    expect(report.ks, [1, 3, 5]);
    expect(report.cases, hasLength(2));

    // Case 1: relevant item is first → precision@1 = 1, nDCG@1 = 1.
    expect(report.cases[0].precisionAtK[1], 1.0);
    expect(report.cases[0].ndcgAtK[1], 1.0);
    // Case 2: relevant item is second → precision@1 = 0, nDCG@1 = 0.
    expect(report.cases[1].precisionAtK[1], 0.0);
    expect(report.cases[1].ndcgAtK[1], 0.0);

    // Mean precision@1 over the two cases = (1 + 0) / 2.
    expect(report.meanPrecisionAtK[1], closeTo(0.5, 1e-9));
    // Both relevant items sit within k=3, so precision@3 = 1/3 each.
    expect(report.meanPrecisionAtK[3], closeTo(1 / 3, 1e-9));
    expect(report.meanNdcgAtK[5], greaterThan(0));
  });

  test('the labeled dataset is well-formed', () {
    final validIds = sampleContacts.map((c) => c.id).toSet();
    expect(evalCases.length, greaterThanOrEqualTo(8));
    expect(
      evalCases.where((c) => c.relevance.isEmpty),
      isNotEmpty,
      reason: 'expected a deliberate no-match case',
    );
    for (final evalCase in evalCases) {
      for (final id in evalCase.relevance.keys) {
        expect(validIds, contains(id), reason: 'unknown contact id $id');
      }
    }
  });
}
