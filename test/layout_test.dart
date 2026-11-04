import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/features/feed/weekly_header.dart';

import 'app_harness.dart';

void main() {
  testWidgets('web: the Apexo mark folds the side menu to icons and back', (tester) async {
    await pumpApp(tester, sizes['desktop']!);
    await signInDemo(tester);
    expect(find.text('Record'), findsOneWidget, reason: 'open: the Record button has its label');

    await tapVisible(tester, find.byKey(const ValueKey('nav-toggle')));
    expect(find.text('Record'), findsNothing, reason: 'folded: icons only');
    await goTo(tester, 'me');
    expect(find.text('Achievements'), findsOneWidget, reason: 'the icons still navigate');

    await tapVisible(tester, find.byKey(const ValueKey('nav-toggle')));
    expect(find.text('Record'), findsOneWidget);
  });

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: this week keeps the same padding on both sides', (tester) async {
      await pumpApp(tester, size);
      await signInDemo(tester);
      final card = tester.getRect(
        find.descendant(of: find.byType(WeeklyHeader), matching: find.byType(Card)),
      );
      Rect rectOf(Finder f) =>
          tester.getRect(find.descendant(of: find.byType(WeeklyHeader), matching: f));
      final title = rectOf(find.text('This week'));
      final dates = rectOf(find.textContaining(' – '));
      final count = rectOf(find.text('Activities'));
      final left = title.left - card.left;
      expect(card.right - dates.right, closeTo(left, 1), reason: 'dates flush right');
      expect(card.right - count.right, closeTo(left, 1), reason: 'last stat flush right');
      final moving = rectOf(find.text('Moving time'));
      expect(moving.center.dx, closeTo(card.center.dx, 1), reason: 'middle stat centered');
    });
  }
}
