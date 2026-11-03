import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedaltrack/app.dart';
import 'package:pedaltrack/data/fake/fake_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Phone (small Android), iPhone, tablet and desktop web widths. Any layout
// overflow fails the test.
const sizes = {
  'small phone': Size(360, 690),
  'iPhone': Size(390, 844),
  'tablet': Size(820, 1180),
  'desktop': Size(1366, 800),
};

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = FakeRepository(simulate: false, latency: Duration.zero);
  addTearDown(repo.dispose);
  await tester.pumpWidget(PedalTrackApp(repository: repo, prefs: prefs));
  await tester.pumpAndSettle();
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

void main() {
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: demo account, every tab, units setting', (tester) async {
      await pumpApp(tester, size);
      await tester.tap(find.text('Continue with demo account'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Ride'), findsOneWidget);
      expect(find.text('Recent activities'), findsOneWidget);

      await goTo(tester, 'circle');
      expect(find.text('Trail Buddies'), findsWidgets);
      expect(find.text('Jero'), findsOneWidget);
      expect(find.text('TRAIL7'), findsOneWidget);

      await goTo(tester, 'record');
      expect(find.text('START'), findsOneWidget);
      // START stays in the lower part of the screen, within thumb reach.
      expect(tester.getCenter(find.text('START')).dy, greaterThan(size.height * 0.55));

      await goTo(tester, 'alerts');
      expect(find.text("Shane's phone battery is at 15%"), findsOneWidget);

      await goTo(tester, 'me');
      await tapVisible(tester, find.text('Miles'));

      await goTo(tester, 'home');
      expect(find.text('mph'), findsNothing); // units live in rich text spans
      expect(find.textContaining('mph', findRichText: true), findsWidgets);
    });

    testWidgets('$name: new account sees friendly empty states', (tester) async {
      await pumpApp(tester, size);
      await tapVisible(tester, find.text('Create account'));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ana');
      await tester.enterText(fields.at(1), 'ana@example.com');
      await tester.enterText(fields.at(2), 'secret-123');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));

      expect(find.text('No activities yet'), findsOneWidget);
      await goTo(tester, 'circle');
      expect(find.text('Ride with your people'), findsOneWidget);
      await goTo(tester, 'alerts');
      expect(find.text('All quiet'), findsOneWidget);
    });
  }

  testWidgets('wrong password shows a safe error', (tester) async {
    await pumpApp(tester, sizes['iPhone']!);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'someone@example.com');
    await tester.enterText(fields.at(1), 'not-the-password');
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Sign in'));
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });
}
