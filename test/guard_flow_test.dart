import 'package:apexo/data/fake/fake_repository.dart';
import 'package:apexo/features/alerts/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// Drives the demo simulator until John's bike leaves its boundary.
Future<void> johnLeaves(WidgetTester tester, FakeRepository repo) async {
  for (var i = 0; i < 60 && !repo.simulator.alerted; i++) {
    repo.simulator.step();
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final name in ['small phone', 'desktop']) {
    final size = sizes[name]!;

    testWidgets('$name: arm guard, test the alarm, mark recovered', (tester) async {
      await pumpApp(tester, size);
      await signInDemo(tester);
      await goTo(tester, 'circle');
      await tapVisible(tester, find.byTooltip('Guard mode'));

      expect(find.text('Trail bike'), findsOneWidget);
      await tapVisible(tester, find.text('Movement detection'));
      expect(find.text('Medium'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('arm-guard')));

      expect(find.text('Guard mode on'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // The bar on every tab leads back to guard mode.
      await tapVisible(tester, find.textContaining('Guard mode on · Trail bike'));
      await tapVisible(tester, find.text('Test the alarm (demo)'));
      expect(find.text('Trail bike left its boundary'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Trail bike left its boundary'), findsOneWidget, reason: 'the bar');
      await goTo(tester, 'alerts');
      expect(find.text('Your Trail bike is on the move'), findsOneWidget);
      expect(find.text('Moved 95 m from its boundary (limit 50 m)'), findsOneWidget);
      await tapVisible(tester, find.text('Mark recovered'));
      expect(find.text('Trail bike marked recovered'), findsOneWidget);
      expect(find.textContaining('Recovered'), findsOneWidget);
      expect(find.textContaining('Guard mode on'), findsNothing);
    });
  }

  testWidgets("another member's theft: dialog, It's me, filters", (tester) async {
    final repo = await pumpApp(tester, sizes['iPhone']!);
    await signInDemo(tester);
    await johnLeaves(tester, repo);

    expect(find.text("John's Blue MTB is on the move"), findsOneWidget);
    expect(find.textContaining('(limit 50 m)'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    await tapVisible(tester, find.text("It's me"));

    await goTo(tester, 'alerts');
    expect(find.textContaining('Seen'), findsWidgets);
    expect(find.text("It's me"), findsNothing, reason: 'already acknowledged');
    await tapVisible(tester, find.text('Mine'));
    expect(find.text('No alerts match these filters.'), findsOneWidget);
    await tapVisible(tester, find.text('Clear'));
    await tapVisible(tester, find.text('Any type'));
    await tapVisible(tester, find.text('Low battery').last);
    expect(find.text("Sarah's phone battery is at 15%"), findsOneWidget);
    expect(find.text("John's Blue MTB is on the move"), findsNothing);
  });

  testWidgets('View on map opens Circle at the missing vehicle', (tester) async {
    final repo = await pumpApp(tester, sizes['tablet']!);
    await signInDemo(tester);
    await johnLeaves(tester, repo);
    await tapVisible(tester, find.text('View on map'));
    expect(find.text('Trail Buddies'), findsOneWidget);
    expect(find.byType(AlertPin), findsOneWidget);
  });
}
