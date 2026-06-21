import 'package:contact_lens/domain/domain.dart';
import 'package:contact_lens/rag/rag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final contacts = <Contact>[
    Contact(
      id: '1',
      createdAt: DateTime.utc(2026),
      name: 'Daniel Rivera',
      company: 'Loomwork AI',
      jobTitle: 'Machine Learning Engineer',
      encounters: <Encounter>[
        Encounter(
          id: 'enc-1',
          occurredAt: DateTime.utc(2026, 5, 18),
          placeLabel: 'San Francisco, CA',
          summary: 'ML conference in SF; works on recommendation systems.',
          tags: const <String>['machine learning', 'recommendation systems'],
        ),
      ],
    ),
    Contact(
      id: '2',
      createdAt: DateTime.utc(2026),
      name: 'Mia Lin',
      company: 'Blue Peak Capital',
      jobTitle: 'Investment Manager',
      encounters: <Encounter>[
        Encounter(
          id: 'enc-2',
          occurredAt: DateTime.utc(2026, 2, 2),
          placeLabel: 'Taipei, Taiwan',
          tags: const <String>['fundraising'],
        ),
      ],
    ),
  ];

  test('contactToRagDocument exposes encounter place, tags, and notes', () {
    final document = contactToRagDocument(contacts.first);

    expect(document.fields['place'], contains('san francisco'));
    expect(document.fields['tags'], contains('machine learning'));
    expect(document.fields['encounterNotes'], contains('recommendation'));
  });

  test('lexical retrieval finds a contact by encounter placeLabel', () {
    final results = const WeightedContactRetriever().retrieve(
      'San Francisco',
      contacts,
    );

    expect(results, isNotEmpty);
    expect(results.first.contact.id, '1');
    expect(results.first.matchedFields, contains('place'));
  });

  test('lexical retrieval finds a contact by encounter tags', () {
    final results = const WeightedContactRetriever().retrieve(
      'recommendation systems',
      contacts,
    );

    expect(results, isNotEmpty);
    expect(results.first.contact.id, '1');
    expect(results.first.matchedFields, contains('tags'));
  });
}
