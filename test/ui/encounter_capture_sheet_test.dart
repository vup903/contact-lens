import 'package:contact_lens/capture/capture.dart';
import 'package:contact_lens/domain/domain.dart';
import 'package:contact_lens/ui/widgets/encounter_capture_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final now = DateTime.utc(2026, 6, 21, 13, 30);

  testWidgets('hides the mic when voice capture is unavailable (C2)', (tester) async {
    await tester.pumpWidget(_host(EncounterCaptureSheet(
      voiceService: FakeVoiceCaptureService(),
      now: now,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Capture context'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Voice note'), findsNothing);
  });

  testWidgets('shows the mic when voice capture is available', (tester) async {
    await tester.pumpWidget(_host(EncounterCaptureSheet(
      voiceService: FakeVoiceCaptureService(permitted: true, cannedTranscript: 'hi'),
      now: now,
    )));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Voice note'), findsOneWidget);
  });

  testWidgets('prefills the place from the GPS reading', (tester) async {
    await tester.pumpWidget(_host(EncounterCaptureSheet(
      voiceService: FakeVoiceCaptureService(),
      now: now,
      reading: const GeoReading(
        point: GeoPoint(latitude: 37.7749, longitude: -122.4194),
        placeLabel: 'San Francisco, CA',
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('San Francisco, CA'), findsOneWidget);
  });

  testWidgets('Save context returns a draft carrying the captured fields', (tester) async {
    EncounterDraft? captured;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await showEncounterCaptureSheet(
                context,
                voiceService: FakeVoiceCaptureService(),
                reading: const GeoReading(
                  point: GeoPoint(latitude: 37.7749, longitude: -122.4194),
                  placeLabel: 'San Francisco, CA',
                ),
                now: now,
                source: EncounterSource.scan,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Note'),
      'met an ML founder',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save context'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.placeLabel, 'San Francisco, CA');
    expect(captured!.note, 'met an ML founder');
    expect(captured!.occurredAt, now);
    expect(captured!.geo?.latitude, 37.7749);
    expect(captured!.source, EncounterSource.scan);
  });
}
