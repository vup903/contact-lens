import 'package:contact_lens/domain/domain.dart';
import 'package:contact_lens/rag/rag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final contacts = <Contact>[
    Contact(
      id: '1',
      createdAt: DateTime.utc(2026),
      name: 'Alex Chen',
      company: 'Nexora AI',
      jobTitle: 'Solutions Architect',
      groups: const <String>['AI ecosystem'],
      other: 'Enterprise vector search and privacy review.',
    ),
    Contact(
      id: '2',
      createdAt: DateTime.utc(2026),
      name: 'Mia Lin',
      company: 'Blue Peak Capital',
      jobTitle: 'Investment Manager',
      groups: const <String>['Finance'],
      other: 'Seed fundraising and SaaS investments.',
    ),
  ];

  test('retrieve ranks direct field matches', () {
    final results = const WeightedContactRetriever().retrieve(
      'AI vector search architect',
      contacts,
    );

    expect(results, isNotEmpty);
    expect(results.first.contact.id, '1');
    expect(results.first.matchedFields, contains('jobTitle'));
    expect(results.first.matchedFields, contains('other'));
  });

  test('deterministic recommender does not invent when no match exists', () {
    final recommendation = const LocalContactRecommender().recommend(
      'quantum hardware procurement',
      contacts,
    );

    expect(recommendation.recommendations, isEmpty);
    expect(recommendation.suggestions, contains('Add more structured notes'));
  });
}

