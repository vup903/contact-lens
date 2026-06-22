import 'package:contact_lens/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Encounter JSON', () {
    test('round-trips all fields', () {
      final encounter = Encounter(
        id: 'enc-1',
        occurredAt: DateTime.utc(2026, 5, 18, 19, 30),
        geo: const GeoPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracyMeters: 12.5,
        ),
        placeLabel: 'San Francisco, CA',
        note: 'Met at an ML conference.',
        transcript: 'met at an ml conference',
        audioPath: '/tmp/audio.m4a',
        summary: 'ML conference in SF.',
        tags: const <String>['machine learning', 'conference'],
        source: EncounterSource.scan,
      );

      final decoded = Encounter.fromJson(encounter.toJson());

      expect(decoded.id, encounter.id);
      expect(decoded.occurredAt, encounter.occurredAt);
      expect(decoded.geo, encounter.geo);
      expect(decoded.placeLabel, encounter.placeLabel);
      expect(decoded.note, encounter.note);
      expect(decoded.transcript, encounter.transcript);
      expect(decoded.audioPath, encounter.audioPath);
      expect(decoded.summary, encounter.summary);
      expect(decoded.tags, encounter.tags);
      expect(decoded.source, EncounterSource.scan);
    });

    test('decodes with missing optional fields', () {
      final decoded = Encounter.fromJson(<String, Object?>{
        'id': 'enc-2',
        'occurredAt': '2026-05-18T19:00:00.000Z',
      });

      expect(decoded.geo, isNull);
      expect(decoded.placeLabel, '');
      expect(decoded.note, '');
      expect(decoded.tags, isEmpty);
      expect(decoded.audioPath, isNull);
      expect(decoded.source, EncounterSource.manual);
    });

    test('unknown source falls back to manual', () {
      final decoded = Encounter.fromJson(<String, Object?>{
        'id': 'enc-3',
        'occurredAt': '2026-05-18T19:00:00.000Z',
        'source': 'bogus',
      });

      expect(decoded.source, EncounterSource.manual);
    });

    test('displayNote prefers summary, then note, then transcript', () {
      final at = DateTime.utc(1970);
      expect(
        Encounter(id: 'a', occurredAt: at, summary: 'S', note: 'N', transcript: 'T')
            .displayNote,
        'S',
      );
      expect(
        Encounter(id: 'a', occurredAt: at, note: 'N', transcript: 'T').displayNote,
        'N',
      );
      expect(
        Encounter(id: 'a', occurredAt: at, transcript: 'T').displayNote,
        'T',
      );
    });
  });

  group('Contact with encounters', () {
    test('round-trips encounters through JSON', () {
      final contact = Contact(
        id: 'c-1',
        createdAt: DateTime.utc(2026, 5, 18),
        name: 'Daniel Rivera',
        encounters: <Encounter>[
          Encounter(
            id: 'enc-1',
            occurredAt: DateTime.utc(2026, 5, 18, 19),
            placeLabel: 'San Francisco, CA',
            tags: const <String>['machine learning'],
          ),
        ],
      );

      final decoded = Contact.fromJson(contact.toJson());

      expect(decoded.encounters, hasLength(1));
      expect(decoded.encounters.first.placeLabel, 'San Francisco, CA');
      expect(decoded.encounters.first.tags, contains('machine learning'));
    });

    test('decodes legacy contact without encounters key (C4)', () {
      final legacy = <String, Object?>{
        'id': 'c-legacy',
        'createdAt': '2026-01-05T00:00:00.000Z',
        'name': 'Alex Chen',
      };

      final decoded = Contact.fromJson(legacy);

      expect(decoded.encounters, isEmpty);
    });
  });

  group('content hash reacts to encounters (C5)', () {
    final base = Contact(
      id: 'c-1',
      createdAt: DateTime.utc(2026, 5, 18),
      name: 'Daniel Rivera',
    );

    test('needsRebuild fires when an encounter is added', () {
      final manifest = RagManifest.build(<Contact>[base]);

      final withEncounter = base.copyWith(
        encounters: <Encounter>[
          Encounter(
            id: 'enc-1',
            occurredAt: DateTime.utc(2026, 5, 18, 19),
            placeLabel: 'San Francisco, CA',
          ),
        ],
      );

      expect(manifest.needsRebuild(<Contact>[base]), isFalse);
      expect(manifest.needsRebuild(<Contact>[withEncounter]), isTrue);
    });

    test('needsRebuild fires when a searchable encounter field changes', () {
      final withEncounter = base.copyWith(
        encounters: <Encounter>[
          Encounter(
            id: 'enc-1',
            occurredAt: DateTime.utc(2026, 5, 18, 19),
            placeLabel: 'San Francisco, CA',
            tags: const <String>['machine learning'],
          ),
        ],
      );
      final manifest = RagManifest.build(<Contact>[withEncounter]);

      final changed = withEncounter.copyWith(
        encounters: <Encounter>[
          withEncounter.encounters.first.copyWith(
            tags: const <String>['machine learning', 'rag'],
          ),
        ],
      );

      expect(manifest.needsRebuild(<Contact>[changed]), isTrue);
    });

    test('toIndexJson is stable regardless of encounter order', () {
      final e1 = Encounter(id: 'enc-a', occurredAt: DateTime.utc(2026, 5, 1));
      final e2 = Encounter(id: 'enc-b', occurredAt: DateTime.utc(2026, 5, 2));

      final ab = base.copyWith(encounters: <Encounter>[e1, e2]);
      final ba = base.copyWith(encounters: <Encounter>[e2, e1]);

      expect(contactContentHash(ab), contactContentHash(ba));
    });
  });
}
