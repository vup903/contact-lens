import 'package:contact_lens/domain/domain.dart';
import 'package:contact_lens/rag/retrieve_contacts.dart';
import 'package:contact_lens/rag/semantic/embedding_cache.dart';
import 'package:contact_lens/rag/semantic/semantic_reranker.dart';
import 'package:flutter_test/flutter_test.dart';

Contact _contact(String id, {String other = ''}) => Contact(
      id: id,
      createdAt: DateTime.utc(2026, 1, 1),
      name: id,
      other: other,
    );

RetrievedContact _candidate(Contact contact, double score) => RetrievedContact(
      contact: contact,
      score: score,
      matchedFields: const <String>['other'],
      matchReason: '${contact.displayName} matched.',
    );

void main() {
  final fundraiser = _contact('fundraiser',
      other: 'seed stage fundraising and venture capital for startups');
  final designer = _contact('designer',
      other: 'mobile onboarding visual design and app store screenshots');

  test('semanticWeight 0 reproduces the lexical order', () {
    const reranker = SemanticReranker(semanticWeight: 0);
    // Lexical says designer (10) > fundraiser (8).
    final result = reranker.rerank('raising venture capital', <RetrievedContact>[
      _candidate(designer, 10),
      _candidate(fundraiser, 8),
    ]);
    expect(result.map((r) => r.contact.id), <String>['designer', 'fundraiser']);
  });

  test('semantic signal can overturn a weak lexical lead', () {
    const reranker = SemanticReranker(semanticWeight: 0.9);
    // Lexical barely favors designer, but the query is about fundraising.
    final result = reranker.rerank('venture capital fundraising', <RetrievedContact>[
      _candidate(designer, 10),
      _candidate(fundraiser, 9),
    ]);
    expect(result.first.contact.id, 'fundraiser');
  });

  test('annotates the match reason with the cosine contribution', () {
    const reranker = SemanticReranker();
    final result = reranker.rerank('fundraising', <RetrievedContact>[
      _candidate(fundraiser, 8),
      _candidate(designer, 6),
    ]);
    expect(result.first.matchReason, contains('semantic rerank: cosine'));
  });

  test('a single candidate is returned untouched (nothing to reorder)', () {
    const reranker = SemanticReranker();
    final only = _candidate(fundraiser, 8);
    final result = reranker.rerank('anything', <RetrievedContact>[only]);
    expect(result, hasLength(1));
    expect(identical(result.first, only), isTrue);
  });

  test('a shared cache is populated once per contact', () {
    const reranker = SemanticReranker();
    final cache = EmbeddingCache();
    reranker.rerank('fundraising', <RetrievedContact>[
      _candidate(fundraiser, 8),
      _candidate(designer, 6),
    ], cache: cache);
    expect(cache.length, 2);
  });
}
