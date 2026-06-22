import 'package:contact_lens/llm/heuristic_llm_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = HeuristicLlmAdapter();
  final now = DateTime.utc(2026, 6, 21); // a Sunday

  test('isRemote is false (this is the local default)', () {
    expect(adapter.isRemote, isFalse);
  });

  group('summarizeNote', () {
    test('extracts curated tags and a one-line summary', () async {
      final insight = await adapter.summarizeNote(
        'Met a machine learning engineer working on computer vision at an '
        'early startup. Discussed fundraising.',
      );
      expect(insight.summary, startsWith('Met a machine learning engineer'));
      expect(insight.summary, isNot(contains('Discussed')));
      expect(
        insight.tags,
        containsAll(<String>[
          'machine learning',
          'computer vision',
          'engineer',
          'startup',
          'fundraising',
        ]),
      );
    });

    test('"ML" abbreviation collapses to the machine learning tag', () async {
      final insight = await adapter.summarizeNote('Sharp ML researcher.');
      expect(insight.tags, contains('machine learning'));
      expect(insight.tags, contains('research'));
    });

    test('extracts Chinese vocabulary', () async {
      final insight = await adapter.summarizeNote('在新創公司做機器學習的工程師。');
      expect(insight.tags, containsAll(<String>['machine learning', 'engineer']));
    });

    test('falls back to salient words so tags are never empty', () async {
      final insight = await adapter.summarizeNote(
        'Discussed sustainable packaging logistics extensively.',
      );
      expect(insight.tags, isNotEmpty);
      expect(insight.tags, contains('packaging'));
    });

    test('empty note yields empty insight', () async {
      final insight = await adapter.summarizeNote('   ');
      expect(insight.summary, isEmpty);
      expect(insight.tags, isEmpty);
    });

    test('tags are capped and deduplicated', () async {
      final insight = await adapter.summarizeNote(
        'AI AI machine learning machine learning founder founder engineer.',
      );
      expect(insight.tags.length, lessThanOrEqualTo(6));
      expect(insight.tags.toSet().length, insight.tags.length);
    });
  });

  group('parseQuery — time + place', () {
    test('English "last month" + "San Francisco"', () async {
      final parsed = await adapter.parseQuery(
        "What's the name of the ML engineer I met last month in San Francisco?",
        now: now,
      );
      expect(parsed.startUtc, DateTime.utc(2026, 5, 1));
      expect(parsed.endUtc, DateTime.utc(2026, 5, 31, 23, 59, 59, 999));
      expect(parsed.locationText, 'San Francisco');
      expect(parsed.semanticText.toLowerCase(), contains('engineer'));
      expect(parsed.semanticText.toLowerCase(), isNot(contains('last month')));
      expect(
        parsed.semanticText.toLowerCase(),
        isNot(contains('san francisco')),
      );
    });

    test('Chinese 「上個月」 + 「舊金山」', () async {
      final parsed = await adapter.parseQuery(
        '上個月在舊金山見面、做機器學習的工程師',
        now: now,
      );
      expect(parsed.startUtc, DateTime.utc(2026, 5, 1));
      expect(parsed.endUtc, DateTime.utc(2026, 5, 31, 23, 59, 59, 999));
      expect(parsed.locationText, 'San Francisco');
      expect(parsed.semanticText, contains('機器學習'));
      expect(parsed.semanticText, isNot(contains('上個月')));
      expect(parsed.semanticText, isNot(contains('舊金山')));
    });

    test('"last month" rolls back across a year boundary', () async {
      final parsed = await adapter.parseQuery(
        'who did I meet last month',
        now: DateTime.utc(2026, 1, 10),
      );
      expect(parsed.startUtc, DateTime.utc(2025, 12, 1));
      expect(parsed.endUtc, DateTime.utc(2025, 12, 31, 23, 59, 59, 999));
    });

    test('"last week" resolves to the prior Monday–Sunday window', () async {
      final parsed = await adapter.parseQuery('met last week', now: now);
      // now = Sun 2026-06-21; this week's Monday is 2026-06-15, so last week
      // is 2026-06-08 .. 2026-06-14.
      expect(parsed.startUtc, DateTime.utc(2026, 6, 8));
      expect(parsed.endUtc, DateTime.utc(2026, 6, 14, 23, 59, 59, 999));
    });

    test('explicit ISO date wins and bounds a single day', () async {
      final parsed = await adapter.parseQuery('met on 2026-05-18', now: now);
      expect(parsed.startUtc, DateTime.utc(2026, 5, 18));
      expect(parsed.endUtc, DateTime.utc(2026, 5, 18, 23, 59, 59, 999));
    });

    test('no constraints leaves bounds null and location empty', () async {
      final parsed = await adapter.parseQuery('AI fundraising person', now: now);
      expect(parsed.startUtc, isNull);
      expect(parsed.endUtc, isNull);
      expect(parsed.locationText, isEmpty);
      expect(parsed.semanticText, 'AI fundraising person');
    });
  });
}
