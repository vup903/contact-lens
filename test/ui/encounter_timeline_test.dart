import 'package:contact_lens/domain/domain.dart';
import 'package:contact_lens/ui/widgets/encounter_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('empty timeline shows the empty-state message', (tester) async {
    await tester.pumpWidget(_host(const EncounterTimeline(encounters: <Encounter>[])));
    expect(find.text('No encounters captured yet.'), findsOneWidget);
  });

  testWidgets('renders encounters newest first with place and tags', (tester) async {
    final older = Encounter(
      id: 'e1',
      occurredAt: DateTime.utc(2026, 3, 10),
      placeLabel: 'Taipei, Taiwan',
      summary: 'Central-bank forum.',
      tags: const <String>['public finance'],
    );
    final newer = Encounter(
      id: 'e2',
      occurredAt: DateTime.utc(2026, 5, 18),
      placeLabel: 'San Francisco, CA',
      summary: 'ML conference.',
      tags: const <String>['machine learning'],
    );

    // Pass oldest-first to prove the widget re-sorts to newest-first.
    await tester.pumpWidget(
      _host(EncounterTimeline(encounters: <Encounter>[older, newer])),
    );

    expect(find.text('2026-05-18'), findsOneWidget);
    expect(find.text('2026-03-10'), findsOneWidget);
    expect(find.text('San Francisco, CA'), findsOneWidget);
    expect(find.text('machine learning'), findsOneWidget);
    expect(find.text('public finance'), findsOneWidget);

    // Newest (2026-05-18) tile sits above the older (2026-03-10) one.
    final newerY = tester.getTopLeft(find.text('2026-05-18')).dy;
    final olderY = tester.getTopLeft(find.text('2026-03-10')).dy;
    expect(newerY, lessThan(olderY));
  });
}
