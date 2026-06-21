import 'dart:math' as math;

import 'package:contact_lens/data/data.dart';
import 'package:contact_lens/domain/domain.dart';
import 'package:contact_lens/rag/contact_retriever.dart';
import 'package:contact_lens/rag/hybrid_retriever.dart';
import 'package:contact_lens/rag/retrieve_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-local nDCG@k so this suite can assert the headline acceptance property
/// (hybrid >= lexical) without importing Workstream A's `lib/eval/**`.
double _ndcgAtK(List<String> rankedIds, Map<String, double> relevance, int k) {
  double dcg(List<double> gains) {
    var sum = 0.0;
    for (var i = 0; i < gains.length && i < k; i += 1) {
      sum += gains[i] / (math.log(i + 2) / math.ln2);
    }
    return sum;
  }

  final gains = rankedIds.map((id) => relevance[id] ?? 0.0).toList();
  final ideal = relevance.values.where((g) => g > 0).toList()..sort((a, b) => b.compareTo(a));
  final idcg = dcg(ideal);
  if (idcg == 0) {
    return 0;
  }
  return dcg(gains) / idcg;
}

double _meanNdcgAtK(
  ContactRetriever retriever,
  List<({String query, Map<String, double> relevance})> cases,
  int k,
) {
  var total = 0.0;
  for (final c in cases) {
    final ranked = retriever
        .retrieve(c.query, sampleContacts, k: k)
        .map((r) => r.contact.id)
        .toList();
    total += _ndcgAtK(ranked, c.relevance, k);
  }
  return total / cases.length;
}

void main() {
  group('ConfidenceGate', () {
    const gate = ConfidenceGate(minTopScore: 14, minMargin: 5);

    RetrievedContact at(double score) => RetrievedContact(
          contact: Contact(id: 's$score', createdAt: DateTime.utc(2026), name: 'n'),
          score: score,
          matchedFields: const <String>[],
          matchReason: '',
        );

    test('fires when the top score is weak', () {
      expect(gate.evaluate(<RetrievedContact>[at(8), at(1)]).shouldRerank, isTrue);
    });

    test('fires when the margin over the runner-up is thin', () {
      expect(gate.evaluate(<RetrievedContact>[at(40), at(38)]).shouldRerank, isTrue);
    });

    test('skips rerank when lexical is confident and well-separated', () {
      final decision = gate.evaluate(<RetrievedContact>[at(40), at(5)]);
      expect(decision.shouldRerank, isFalse);
      expect(decision.reason, contains('confident'));
    });

    test('does not fire on an empty candidate list', () {
      expect(gate.evaluate(const <RetrievedContact>[]).shouldRerank, isFalse);
    });
  });

  group('HybridContactRetriever', () {
    const lexical = WeightedContactRetriever();
    const hybrid = HybridContactRetriever();

    test('implements the frozen ContactRetriever contract', () {
      expect(hybrid, isA<ContactRetriever>());
    });

    test('is const-constructible with no arguments (matches §3 contract)', () {
      const other = HybridContactRetriever();
      expect(identical(hybrid, other), isTrue);
    });

    test('returns lexical order untouched when the gate is confident', () {
      // A precise name query is high-confidence; hybrid must not perturb it.
      const query = 'Alex Chen';
      final lexicalIds =
          lexical.retrieve(query, sampleContacts, k: 5).map((r) => r.contact.id).toList();
      final hybridIds =
          hybrid.retrieve(query, sampleContacts, k: 5).map((r) => r.contact.id).toList();
      expect(hybridIds, lexicalIds);
    });

    test('annotates reranked results so the UI can show the tier fired', () {
      // A broad, synonym-heavy query trips the gate.
      final results = hybrid.retrieve('introductions to AI community organizers', sampleContacts, k: 5);
      expect(results.any((r) => r.matchReason.contains('semantic rerank')), isTrue);
    });

    test('no candidates in, no candidates out', () {
      expect(hybrid.retrieve('zzqzzqzz qkqkqkq', sampleContacts, k: 5), isEmpty);
    });

    // The headline acceptance property from §4-C / §8.
    test('hybrid nDCG@5 >= lexical nDCG@5 on a labeled set', () {
      final cases = <({String query, Map<String, double> relevance})>[
        (query: 'enterprise AI deployment and vector search', relevance: {'sample-alex-chen': 3}),
        (query: 'on-premise data privacy review', relevance: {'sample-alex-chen': 3}),
        (query: 'seed stage fundraising for B2B SaaS', relevance: {'sample-mia-lin': 3}),
        (query: 'raising venture capital money for a productivity startup',
            relevance: {'sample-mia-lin': 3}),
        (query: 'mobile onboarding and app store screenshots', relevance: {'sample-jordan-lee': 3}),
        (query: 'CRM workflow visual design partner', relevance: {'sample-jordan-lee': 3}),
        (query: '外匯局 襄理', relevance: {'sample-wu-kuei-hua': 3}),
        (query: 'central bank public sector finance contact', relevance: {'sample-wu-kuei-hua': 3}),
        (query: 'introduce me to AI meetup organizers and developer advocates',
            relevance: {'sample-priya-shah': 3}),
        (query: 'find a partnerships lead for an AI event', relevance: {'sample-priya-shah': 3}),
        // Deliberate no-match: neither tier should be credited.
        (query: 'underwater basket weaving championship', relevance: <String, double>{}),
      ];

      final lexicalNdcg = _meanNdcgAtK(lexical, cases, 5);
      final hybridNdcg = _meanNdcgAtK(hybrid, cases, 5);

      // ignore: avoid_print
      print('nDCG@5  lexical=${lexicalNdcg.toStringAsFixed(4)}  '
          'hybrid=${hybridNdcg.toStringAsFixed(4)}');
      expect(hybridNdcg, greaterThanOrEqualTo(lexicalNdcg - 1e-9));
    });
  });
}
