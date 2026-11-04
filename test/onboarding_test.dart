import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

void main() {
  for (final name in ['small phone', 'desktop']) {
    testWidgets('$name: three welcome slides once, then sign-in', (tester) async {
      await pumpApp(tester, sizes[name]!, onboarded: false);
      expect(find.text('Record every ride'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('onboarding-next')));
      expect(find.text('Ride with your people'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('onboarding-next')));
      expect(find.text('Guard what you ride'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      await tapVisible(tester, find.text('Get started'));
      expect(find.text('Continue with demo account'), findsOneWidget);
    });
  }

  testWidgets('Skip goes straight to sign-in', (tester) async {
    await pumpApp(tester, sizes['iPhone']!, onboarded: false);
    await tapVisible(tester, find.text('Skip'));
    expect(find.text('Welcome'), findsOneWidget);
  });
}
