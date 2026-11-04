import 'dart:io';

import 'package:apexo/core/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

const tabs = ['home', 'circle', 'record', 'alerts', 'me'];

Future<void> checkGuidelines(WidgetTester tester, String where) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: '$where tap size');
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: '$where labels');
  await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$where contrast');
  handle.dispose();
}

void main() {
  // The contrast check takes real screenshots, which lets the map's tile
  // cache ask for a folder; give it a temporary one.
  setUp(() {
    final dir = Directory.systemTemp.createTempSync('apexo_tiles').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir,
    );
  });
  tearDown(() => AppColors.use(Brightness.light));

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('$theme: tap targets, labels and contrast on every tab', (tester) async {
      if (dark) tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, sizes['iPhone']!);
      await checkGuidelines(tester, 'sign-in');
      await signInDemo(tester);
      for (final tab in tabs) {
        await goTo(tester, tab);
        await checkGuidelines(tester, tab);
      }
    });
  }

  for (final name in ['small phone', 'iPhone']) {
    testWidgets('$name: every tab at 2x text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, sizes[name]!);
      await signInDemo(tester);
      for (final tab in tabs) {
        await goTo(tester, tab);
      }
    });
  }
}
