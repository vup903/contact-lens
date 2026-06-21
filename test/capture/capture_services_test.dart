import 'package:contact_lens/capture/capture.dart';
import 'package:contact_lens/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeGeoLocationService', () {
    test('denies permission and returns no fix by default (C2 path)', () async {
      const service = FakeGeoLocationService();
      expect(await service.ensurePermission(), isFalse);
      expect(await service.currentLocation(), isNull);
    });

    test('returns the injected reading when permitted', () async {
      const reading = GeoReading(
        point: GeoPoint(latitude: 37.7749, longitude: -122.4194),
        placeLabel: 'San Francisco, CA',
      );
      const service = FakeGeoLocationService(permitted: true, reading: reading);

      expect(await service.ensurePermission(), isTrue);
      final fix = await service.currentLocation();
      expect(fix, isNotNull);
      expect(fix!.placeLabel, 'San Francisco, CA');
      expect(fix.point.latitude, closeTo(37.7749, 1e-9));
    });

    test('permitted but no fix returns null (granted yet failed sample)',
        () async {
      const service = FakeGeoLocationService(permitted: true);
      expect(await service.ensurePermission(), isTrue);
      expect(await service.currentLocation(), isNull);
    });
  });

  group('FakeVoiceCaptureService', () {
    test('denies permission and never records by default', () async {
      final service = FakeVoiceCaptureService();
      expect(await service.ensurePermission(), isFalse);
      await service.start();
      expect(service.isRecording, isFalse);
      final result = await service.stop();
      expect(result.transcript, isEmpty);
      expect(result.audioPath, isNull);
    });

    test('records and returns the canned transcript when permitted', () async {
      final service = FakeVoiceCaptureService(
        permitted: true,
        cannedTranscript: 'met an ML engineer in San Francisco',
        audioPath: '/tmp/note.m4a',
      );

      expect(await service.ensurePermission(), isTrue);
      await service.start();
      expect(service.isRecording, isTrue);

      final result = await service.stop();
      expect(service.isRecording, isFalse);
      expect(result.transcript, 'met an ML engineer in San Francisco');
      expect(result.audioPath, '/tmp/note.m4a');
    });
  });

  group('platform factories', () {
    test('default platform services degrade gracefully off-device', () async {
      // On the Dart VM test host there are no mobile plugins, so the factories
      // must resolve to the denying fallback rather than crash (C2).
      final geo = createGeoLocationService();
      expect(await geo.ensurePermission(), isFalse);
      expect(await geo.currentLocation(), isNull);

      final voice = createVoiceCaptureService();
      expect(await voice.ensurePermission(), isFalse);
      expect(voice.isRecording, isFalse);
    });
  });
}
