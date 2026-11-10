import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/theme.dart';
import 'package:apexo/features/auth/auth_widgets.dart';
import 'package:apexo/features/feed/weekly_header.dart';
import 'package:apexo/widgets/profile_image.dart';
import 'package:apexo/widgets/visuals.dart';

import 'app_harness.dart';

void main() {
  badgeTests();
  dividerTests();
  signInSpacingTests();
  alertCardTests();
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

void alertCardTests() {
  /// Lets John's bike leave its boundary, closes the pop-up without
  /// answering and opens Alerts; returns the finder for that card.
  Future<Finder> openTheftCard(WidgetTester tester, Size size) async {
    final repo = await pumpApp(tester, size);
    await signInDemo(tester);
    for (var i = 0; i < 60 && !repo.simulator.alerted; i++) {
      repo.simulator.step();
    }
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await goTo(tester, 'alerts');
    return find.ancestor(
      of: find.text("John's Blue MTB is on the move"),
      matching: find.byType(Card),
    );
  }

  Rect rectIn(WidgetTester tester, Finder scope, Finder f) =>
      tester.getRect(find.descendant(of: scope, matching: f));

  /// Where the words are drawn (not the space at a line break), and on how
  /// many lines.
  (Rect, int) inkOf(WidgetTester tester, Finder scope, Finder f) {
    final p = tester.renderObject<RenderParagraph>(find.descendant(of: scope, matching: f));
    final words = RegExp(r'\S+').allMatches(p.text.toPlainText());
    final boxes = [
      for (final w in words)
        ...p.getBoxesForSelection(TextSelection(baseOffset: w.start, extentOffset: w.end)),
    ];
    final ink = boxes.map((b) => b.toRect()).reduce((a, b) => a.expandToInclude(b));
    final lines = boxes.map((b) => b.top.round()).toSet().length;
    return (ink.shift(p.localToGlobal(Offset.zero)), lines);
  }

  /// The detail fits inside the title's width on one line. View on map and
  /// Navigate span the card or pop-up with the same padding on both sides,
  /// and a gray "It's me" of the same size, with no outline, sits centered
  /// under them, as far from the bottom edge as [top] is from the top edge.
  void expectBalanced(WidgetTester tester, Finder scope, Rect box, Rect top) {
    final (title, _) = inkOf(tester, scope, find.text("John's Blue MTB is on the move"));
    final (detail, lines) = inkOf(tester, scope, find.byKey(const ValueKey('alert-detail')));
    expect(lines, 1, reason: 'the detail stays on one line');
    expect(detail.left, greaterThanOrEqualTo(title.left - 1), reason: 'detail inside the title');
    expect(detail.right, lessThanOrEqualTo(title.right + 1), reason: 'detail inside the title');

    final map = rectIn(tester, scope, find.byKey(const ValueKey('alert-view-map')));
    final nav = rectIn(tester, scope, find.byKey(const ValueKey('alert-navigate')));
    final me = rectIn(tester, scope, find.byKey(const ValueKey('alert-third')));
    expect(map.top, closeTo(nav.top, 0.5), reason: 'one row');
    expect(map.width, closeTo(nav.width, 0.5), reason: 'same width');
    final side = map.left - box.left;
    expect(box.right - nav.right, closeTo(side, 1), reason: 'same padding both sides');
    expect(me.size, map.size, reason: "It's me is the same size");
    expect(
      tester.widget(find.byKey(const ValueKey('alert-third'))),
      isA<TextButton>(),
      reason: 'no outline',
    );
    expect(me.top - nav.bottom, closeTo(nav.left - map.right, 0.5), reason: 'same gaps');
    expect(me.center.dx, closeTo(box.center.dx, 1), reason: 'centered');
    expect(box.bottom - me.bottom, closeTo(top.top - box.top, 1), reason: 'balanced padding');
    expect(box.bottom - me.bottom, closeTo(side, 1), reason: 'bottom matches the sides');

    TextStyle styleOf(Finder f) =>
        tester.renderObject<RenderParagraph>(find.descendant(of: scope, matching: f)).text.style!;
    final quiet = styleOf(find.text("It's me"));
    expect(quiet.color, AppColors.textMuted, reason: 'gray');
    expect(quiet.fontSize, lessThan(styleOf(find.text('Navigate')).fontSize!), reason: 'smaller');
  }

  // The test font is far wider than Inter; smaller text fits it like Inter.
  void smallText(WidgetTester tester) {
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets("theft alert card: full-width pair, same-size It's me, even padding", (tester) async {
    smallText(tester);
    final card = await openTheftCard(tester, sizes['iPhone']!);
    final tile = rectIn(tester, card, find.byType(IconTile));
    expectBalanced(tester, card, tester.getRect(card), tile);
  });

  testWidgets("theft pop-up: full-width pair, same-size It's me, even padding", (tester) async {
    smallText(tester);
    final repo = await pumpApp(tester, sizes['iPhone']!);
    await signInDemo(tester);
    for (var i = 0; i < 60 && !repo.simulator.alerted; i++) {
      repo.simulator.step();
    }
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    final sheet = tester.getRect(
      find.descendant(of: dialog, matching: find.byType(Material)).first,
    );
    final icon = tester.getRect(find.descendant(of: dialog, matching: find.byType(Icon)).first);
    expectBalanced(tester, dialog, sheet, icon);
    expect(find.text('Moved 0.07 km away (limit 0.05 km)'), findsOneWidget, reason: 'km');
  });

  testWidgets('theft alert: a narrow phone stacks the buttons at one width', (tester) async {
    final card = await openTheftCard(tester, sizes['small phone']!);
    final map = rectIn(tester, card, find.byKey(const ValueKey('alert-view-map')));
    final nav = rectIn(tester, card, find.byKey(const ValueKey('alert-navigate')));
    final me = rectIn(tester, card, find.byKey(const ValueKey('alert-third')));
    expect(nav.top, greaterThan(map.bottom), reason: 'stacked');
    expect(me.top, greaterThan(nav.bottom), reason: 'stacked');
    expect({map.left, nav.left, me.left}.length, 1, reason: 'one column');
    expect({map.size, nav.size, me.size}.length, 1, reason: 'one size');
  });
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
