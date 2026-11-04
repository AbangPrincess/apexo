import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/features/record/record_screen.dart';

import 'app_harness.dart';
import 'weather_fixtures.dart';

void main() {
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: demo account, every tab, units setting', (tester) async {
      await pumpApp(tester, size);
      await signInDemo(tester);
      expect(find.text('This week'), findsOneWidget);
      final homeWeather = find.byKey(const ValueKey('home-weather'));
      expect(find.descendant(of: homeWeather, matching: find.text('Great')), findsOneWidget);
      expect(find.text('Dry and calm - enjoy the ride'), findsOneWidget);
      expect(find.textContaining('Feels like 29°'), findsOneWidget);
      expect(find.textContaining('Best time to ride'), findsOneWidget);
      expect(find.descendant(of: homeWeather, matching: find.text('Now')), findsOneWidget);
      expect(find.textContaining('Koronadal City · Updated'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Morning Ride'), 300);
      expect(find.text('Morning Ride'), findsOneWidget);

      await tapVisible(tester, find.text('Morning Ride'));
      expect(find.text('Elapsed time'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await goTo(tester, 'circle');
      expect(find.text('Jero'), findsOneWidget);
      expect(find.text('TRAIL7'), findsOneWidget);

      await goTo(tester, 'record');
      expect(find.text('START'), findsOneWidget);
      // START stays in the lower part of the screen, within thumb reach, and
      // fully on screen from iPhone height up. (The test font is wider than
      // real fonts, so the shortest phone scrolls here.)
      expect(tester.getCenter(find.text('START')).dy, greaterThan(size.height * 0.55));
      if (size.height >= 800) {
        final page = find.descendant(
          of: find.byType(RecordScreen),
          matching: find.byType(SingleChildScrollView),
        );
        final button = tester.getRect(find.bySemanticsLabel('START').last);
        expect(button.bottom, lessThanOrEqualTo(tester.getRect(page).bottom));
      }
      final recordWeather = find.byKey(const ValueKey('record-weather'));
      expect(find.descendant(of: recordWeather, matching: find.text('Great')), findsOneWidget);
      final hourly = find.descendant(of: recordWeather, matching: find.text('Hourly'));
      // Short screens fold the hourly forecast behind a toggle.
      if (hourly.evaluate().isNotEmpty) await tapVisible(tester, hourly);
      expect(find.descendant(of: recordWeather, matching: find.text('Now')), findsOneWidget);

      await goTo(tester, 'alerts');
      expect(find.text("Shane's phone battery is at 15%"), findsOneWidget);

      await goTo(tester, 'me');
      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('Century Club'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Settings').first);
      await tapVisible(tester, find.text('Miles'));
      await tester.pageBack();
      await tester.pumpAndSettle();

      await goTo(tester, 'home');
      expect(find.textContaining('mph', findRichText: true), findsWidgets);
    });

    testWidgets('$name: sign-up waits for email verification', (tester) async {
      await pumpApp(tester, size);
      await tapVisible(tester, find.text('Create account'));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ana');
      await tester.enterText(fields.at(1), 'ana@example.com');
      await tester.enterText(fields.at(2), 'secret-123');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));

      expect(find.text('Check your email'), findsOneWidget);
      await tapVisible(tester, find.text("I've verified my email"));
      expect(find.textContaining('Not verified yet'), findsOneWidget);

      await tapVisible(tester, find.text('Open demo inbox'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Verify email'));

      expect(find.text('No activities yet'), findsOneWidget);
      await goTo(tester, 'circle');
      expect(find.text('Ride with your people'), findsOneWidget);
      await goTo(tester, 'alerts');
      expect(find.text('All quiet'), findsOneWidget);
      await goTo(tester, 'me');
      expect(find.text('0 of 13 earned'), findsOneWidget);
    });
  }

  testWidgets('five wrong passwords lock sign-in with a countdown', (tester) async {
    await pumpApp(tester, sizes['iPhone']!);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'someone@example.com');
    for (var i = 0; i < 5; i++) {
      await tester.enterText(fields.at(1), 'guess-$i');
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Sign in'));
    }
    expect(find.textContaining('Too many attempts'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.textContaining('Try again in'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('record with simulated GPS, pause, finish and save', (tester) async {
    await pumpApp(tester, sizes['iPhone']!);
    await signInDemo(tester);
    await goTo(tester, 'record');
    await tapVisible(tester, find.text('START'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Recording'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);

    await tapVisible(tester, find.bySemanticsLabel('PAUSE'));
    expect(find.text('Paused'), findsOneWidget);
    await tapVisible(tester, find.bySemanticsLabel('FINISH'));
    expect(find.text('Save activity'), findsWidgets);

    await tester.enterText(find.byType(TextField).last, 'Test loop');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save activity'));
    expect(find.text('Test loop'), findsOneWidget);
    // The weather at the start is saved with the activity.
    await tapVisible(tester, find.text('Test loop'));
    expect(find.text('Wind 9 km/h at the start'), findsOneWidget);
  });

  testWidgets('edit profile bio and hometown', (tester) async {
    await pumpApp(tester, sizes['iPhone']!);
    await signInDemo(tester);
    await goTo(tester, 'me');
    await tapVisible(tester, find.text('Edit profile'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Weekend climber from the south.');
    await tester.enterText(fields.at(2), 'Koronadal City');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save profile'));
    expect(find.text('Weekend climber from the south.'), findsOneWidget);
    expect(find.text('From Koronadal City'), findsOneWidget);
  });

  testWidgets('weather offline: friendly retry, then the last result stays', (tester) async {
    final weather = FakeWeatherSource()..offline = true;
    await pumpApp(tester, sizes['small phone']!, weather: weather);
    await signInDemo(tester);
    expect(find.text('Weather unavailable. Check your connection.'), findsOneWidget);

    weather.offline = false;
    await tapVisible(tester, find.text('Retry'));
    expect(find.text('Dry and calm - enjoy the ride'), findsOneWidget);

    weather.offline = true;
    await tester.pump(const Duration(minutes: 16));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline · Updated 16 min ago'), findsOneWidget);
    expect(find.text('Dry and calm - enjoy the ride'), findsOneWidget);
  });
}
