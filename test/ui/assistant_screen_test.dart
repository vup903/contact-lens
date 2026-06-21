import 'package:contact_lens/capture/capture.dart';
import 'package:contact_lens/ui/app_state.dart';
import 'package:contact_lens/ui/screens/assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('contextual query renders 時間/地點/語意 chips and a contact', (tester) async {
    final state = ContactLensState(
      geoService: const FakeGeoLocationService(),
      voiceService: FakeVoiceCaptureService(),
    );
    await state.load();
    addTearDown(state.dispose);

    // Lexical base keeps the widget test hermetic (no embedding-service HTTP);
    // the parsed-filter chips and the metadata filter are unaffected.
    state.setHybridEnabled(false);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AssistantScreen(appState: state))),
    );

    await tester.enterText(
      find.byType(TextField),
      'machine learning engineer I met last month in San Francisco',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    // The headline new UI: the parser's time/place/meaning constraints render as
    // chips above the explainable results.
    expect(find.textContaining('地點'), findsWidgets);
    expect(find.textContaining('San Francisco'), findsWidgets);
    expect(find.textContaining('語意'), findsWidgets);

    // The contextual answer surfaces the ML engineer.
    expect(find.text('Daniel Rivera'), findsOneWidget);
  });
}
