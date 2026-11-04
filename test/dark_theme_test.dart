import 'package:apexo/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

void main() {
  tearDown(() => AppColors.use(Brightness.light));

  for (final name in ['small phone', 'desktop']) {
    testWidgets('$name: dark theme on every tab', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, sizes[name]!);
      await signInDemo(tester);

      expect(AppColors.brightness, Brightness.dark);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        scaffold.backgroundColor ??
            Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor,
        Palette.asphaltBlack,
      );
      for (final tab in ['circle', 'record', 'alerts', 'me', 'home']) {
        await goTo(tester, tab);
      }
      expect(find.text('This week'), findsOneWidget);
    });
  }

  testWidgets('switching the system theme at runtime keeps the current tab', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester, sizes['iPhone']!);
    await signInDemo(tester);
    await goTo(tester, 'me');
    expect(AppColors.surface, const Color(0xFFFFFFFF));

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(AppColors.brightness, Brightness.dark);
    expect(AppColors.surface, Palette.asphaltBlack);
    expect(find.text('Achievements'), findsOneWidget, reason: 'still on Me');
  });
}
