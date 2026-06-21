import 'package:contact_lens/data/sample_data.dart';
import 'package:contact_lens/domain/domain.dart';
import 'package:contact_lens/llm/llm.dart';
import 'package:contact_lens/rag/rag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed demo clock so "last month" resolves deterministically (C5).
  final now = DateTime.utc(2026, 6, 21);

  final daniel = Contact(
    id: 'daniel',
    createdAt: DateTime.utc(2026, 5, 18),
    name: 'Daniel Rivera',
    company: 'Loomwork AI',
    jobTitle: 'Machine Learning Engineer',
    other: 'Builds recommendation models and retrieval-augmented pipelines.',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-daniel',
        occurredAt: DateTime.utc(2026, 5, 18, 19),
        placeLabel: 'San Francisco, CA',
        geo: const GeoPoint(latitude: 37.7749, longitude: -122.4194),
        summary: 'ML conference in San Francisco; recommendation systems.',
        tags: const <String>['machine learning', 'recommendation systems'],
      ),
    ],
  );

  final mia = Contact(
    id: 'mia',
    createdAt: DateTime.utc(2026, 2, 1),
    name: 'Mia Lin',
    company: 'Blue Peak Capital',
    jobTitle: 'Investment Manager',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-mia',
        occurredAt: DateTime.utc(2026, 2, 2),
        placeLabel: 'Taipei, Taiwan',
        tags: const <String>['fundraising'],
      ),
    ],
  );

  // A San Francisco contact met much earlier, to prove the time filter bites.
  final omar = Contact(
    id: 'omar',
    createdAt: DateTime.utc(2026, 1, 10),
    name: 'Omar Reyes',
    company: 'Bayline Labs',
    jobTitle: 'Data Scientist',
    encounters: <Encounter>[
      Encounter(
        id: 'enc-omar',
        occurredAt: DateTime.utc(2026, 1, 10),
        placeLabel: 'San Francisco, CA',
        tags: const <String>['data science'],
      ),
    ],
  );

  final contacts = <Contact>[daniel, mia, omar];
  final retriever = ContextualRetriever(base: const WeightedContactRetriever());

  TimeRange lastMonth() => TimeRange(
        start: DateTime.utc(2026, 5, 1),
        end: DateTime.utc(2026, 6, 1).subtract(const Duration(milliseconds: 1)),
      );

  test('time-only filter keeps contacts met in the window, by recency', () {
    final q = ContextualQuery(semanticText: '', timeRange: lastMonth());
    final result = retriever.retrieve(q, contacts);

    expect(result.filterApplied, isTrue);
    expect(result.candidateCount, 1);
    expect(result.results.single.contact.id, 'daniel');
    expect(result.results.single.matchReason, contains('met 2026-05-18'));
  });

  test('place-only filter keeps every contact met there', () {
    const q = ContextualQuery(
      semanticText: '',
      geo: GeoFilter(placeText: 'san francisco'),
    );
    final result = retriever.retrieve(q, contacts);

    expect(result.filterApplied, isTrue);
    expect(result.candidateCount, 2); // Daniel + Omar, not Mia (Taipei)
    // Recency-ranked: Daniel (May) before Omar (Jan).
    expect(result.results.map((r) => r.contact.id), ['daniel', 'omar']);
  });

  test('combined time + place narrows to a single contact', () {
    final q = ContextualQuery(
      semanticText: '',
      timeRange: lastMonth(),
      geo: const GeoFilter(placeText: 'san francisco'),
    );
    final result = retriever.retrieve(q, contacts);

    expect(result.candidateCount, 1);
    expect(result.results.single.contact.id, 'daniel');
  });

  test('semantic ranking applies within the filtered survivors', () {
    const q = ContextualQuery(
      semanticText: 'machine learning',
      geo: GeoFilter(placeText: 'san francisco'),
    );
    final result = retriever.retrieve(q, contacts);

    expect(result.filterApplied, isTrue);
    expect(result.results.first.contact.id, 'daniel');
    // Reason mentions both the encounter and the base ranker's match.
    expect(result.results.first.matchReason, contains('San Francisco'));
  });

  test('empty filter falls back to the full corpus (C2)', () {
    // Nobody was met in Tokyo → fall back rather than return nothing.
    const q = ContextualQuery(
      semanticText: 'machine learning',
      geo: GeoFilter(placeText: 'tokyo'),
    );
    final result = retriever.retrieve(q, contacts);

    expect(result.filterApplied, isFalse);
    expect(result.candidateCount, contacts.length);
    expect(result.results, isNotEmpty);
    expect(result.results.first.contact.id, 'daniel'); // by meaning
    expect(result.explanation, contains('searched all'));
  });

  test('survivors with no lexical overlap still return by recency', () {
    // Place filter matches Daniel + Omar, but the meaning matches neither
    // lexically → fall back to recency over the survivors (not the full corpus).
    const q = ContextualQuery(
      semanticText: 'quantum cryptography',
      geo: GeoFilter(placeText: 'san francisco'),
    );
    final result = retriever.retrieve(q, contacts);

    expect(result.filterApplied, isTrue);
    expect(result.candidateCount, 2);
    expect(result.results.map((r) => r.contact.id), ['daniel', 'omar']);
  });

  test('unconstrained query is a plain base ranking over the full corpus', () {
    const q = ContextualQuery(semanticText: 'machine learning');
    final result = retriever.retrieve(q, contacts);

    expect(result.filterApplied, isFalse);
    expect(result.candidateCount, contacts.length);
    expect(result.results.first.contact.id, 'daniel');
  });

  test('empty corpus yields an empty result', () {
    final q = ContextualQuery(semanticText: 'anything', timeRange: lastMonth());
    final result = retriever.retrieve(q, const <Contact>[]);

    expect(result.results, isEmpty);
    expect(result.filterApplied, isFalse);
  });

  group('headline SF/ML query end-to-end via the heuristic parser', () {
    const llm = HeuristicLlmAdapter();

    test('English: ML engineer met last month in San Francisco', () async {
      final parsed = await llm.parseQuery(
        'the machine learning engineer I met last month in San Francisco',
        now: now,
      );
      final q = ContextualQuery.fromParsedQuery(parsed, rawQuery: 'demo');
      final result = retriever.retrieve(q, sampleContacts);

      expect(result.filterApplied, isTrue);
      expect(result.results.first.contact.id, 'sample-daniel-rivera');
      expect(result.results.first.matchReason, contains('San Francisco'));
    });

    test('Traditional Chinese headline query returns Daniel first', () async {
      final parsed = await llm.parseQuery(
        '上個月在舊金山見面、做機器學習那個工程師叫什麼？',
        now: now,
      );
      final q = ContextualQuery.fromParsedQuery(parsed);

      // Parser should have extracted the time + place constraints.
      expect(q.hasConstraints, isTrue);
      expect(q.timeRange, isNotNull);
      expect(q.geo, isNotNull);

      final result = retriever.retrieve(q, sampleContacts);
      expect(result.results.first.contact.id, 'sample-daniel-rivera');
    });
  });

  group('ContextualQuery.fromParsedQuery mapping', () {
    test('maps time bounds and place into constraints', () {
      final parsed = ParsedQuery(
        semanticText: 'machine learning engineer',
        startUtc: DateTime.utc(2026, 5, 1),
        endUtc: DateTime.utc(2026, 5, 31),
        locationText: 'San Francisco',
      );
      final q = ContextualQuery.fromParsedQuery(parsed);

      expect(q.hasConstraints, isTrue);
      expect(q.timeRange!.start, DateTime.utc(2026, 5, 1));
      expect(q.geo!.placeText, 'San Francisco');
      expect(q.semanticText, 'machine learning engineer');
    });

    test('no time/place → no constraints', () {
      final q = ContextualQuery.fromParsedQuery(
        const ParsedQuery(semanticText: 'designer'),
      );
      expect(q.hasConstraints, isFalse);
      expect(q.timeRange, isNull);
      expect(q.geo, isNull);
    });
  });

  group('GeoFilter proximity', () {
    test('matches an encounter within the radius', () {
      const filter = GeoFilter(
        center: GeoPoint(latitude: 37.7749, longitude: -122.4194),
        radiusKm: 50,
      );
      expect(filter.matchesEncounter(daniel.encounters.first), isTrue);
      expect(filter.matchesEncounter(mia.encounters.first), isFalse);
    });
  });

  group('TimeRange', () {
    test('inclusive bounds and open sides', () {
      final r = TimeRange(
        start: DateTime.utc(2026, 5, 1),
        end: DateTime.utc(2026, 5, 31),
      );
      expect(r.contains(DateTime.utc(2026, 5, 1)), isTrue);
      expect(r.contains(DateTime.utc(2026, 5, 31)), isTrue);
      expect(r.contains(DateTime.utc(2026, 4, 30)), isFalse);
      expect(const TimeRange().isOpen, isTrue);
    });
  });
}
