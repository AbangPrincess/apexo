import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/features/auth/auth_widgets.dart';
import 'package:apexo/features/feed/weekly_header.dart';
import 'package:apexo/widgets/profile_image.dart';

import 'app_harness.dart';

void main() {
  badgeTests();
  dividerTests();
  signInSpacingTests();
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

void badgeTests() {
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: the photo camera badge sits on the photo edge', (tester) async {
      await pumpApp(tester, size);
      await signInDemo(tester);
      await goTo(tester, 'me');
      final photo = tester.getRect(find.byType(UserAvatar).first);
      final badge = tester.getCenter(find.byTooltip('Change profile photo'));
      final ring = photo.width / 2;
      final fromCenter = badge - photo.center;
      expect(fromCenter.distance, closeTo(ring, 2), reason: 'centered on the edge');
      expect(fromCenter.dx, closeTo(fromCenter.dy, 2), reason: 'lower right, at 45°');
    });
  }
}

void dividerTests() {
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: "or sign in with email" is centered', (tester) async {
      await pumpApp(tester, size);
      final row = tester.getRect(find.byType(OrDivider));
      final label = tester.getRect(find.text('or sign in with email'));
      expect(label.center.dx, closeTo(row.center.dx, 1));
    });
  }
}

void signInSpacingTests() {
  testWidgets('"New to Apexo? Create account" has a normal word gap', (tester) async {
    // The test font is far wider than Inter; smaller text keeps one line.
    tester.platformDispatcher.textScaleFactorTestValue = 0.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, sizes['iPhone']!);
    final question = tester.getRect(find.text('New to Apexo?'));
    final link = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('open-create-account')),
        matching: find.text('Create account'),
      ),
    );
    expect(link.left - question.right, inInclusiveRange(2, 6));
    expect(link.center.dy, closeTo(question.center.dy, 2), reason: 'same line');
  });
}
