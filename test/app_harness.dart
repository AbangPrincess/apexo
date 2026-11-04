import 'package:apexo/app.dart';
import 'package:apexo/data/fake/fake_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather_fixtures.dart';

// Phone (small Android), iPhone, tablet and desktop web widths. Any layout
// overflow fails the test.
const sizes = {
  'small phone': Size(360, 690),
  'iPhone': Size(390, 844),
  'tablet': Size(820, 1180),
  'desktop': Size(1366, 800),
};

Future<FakeRepository> pumpApp(WidgetTester tester, Size size, {FakeWeatherSource? weather}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = FakeRepository(simulate: false, latency: Duration.zero);
  addTearDown(repo.dispose);
  await tester.pumpWidget(
    ApexoApp(repository: repo, prefs: prefs, weatherSource: weather ?? FakeWeatherSource()),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> goTo(WidgetTester tester, String tab) async {
  await tester.tap(find.byKey(ValueKey('nav-$tab')));
  await tester.pumpAndSettle();
}

Future<void> signInDemo(WidgetTester tester) async {
  await tapVisible(tester, find.text('Continue with demo account'));
}

/// Signs up as Ana and verifies the email through the demo inbox.
Future<void> signUpAna(WidgetTester tester) async {
  await tapVisible(tester, find.text('Create account'));
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Ana');
  await tester.enterText(fields.at(1), 'ana@example.com');
  await tester.enterText(fields.at(2), 'secret-123');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));
  await tapVisible(tester, find.text('Open demo inbox'));
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Verify email'));
}
