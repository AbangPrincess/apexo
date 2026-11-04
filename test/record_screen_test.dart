import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/geo.dart';
import 'package:apexo/features/record/activity_picker.dart';
import 'package:apexo/features/weather/weather_controller.dart';
import 'package:apexo/widgets/map_view.dart';
import 'package:apexo/widgets/weather_art.dart';

import 'app_harness.dart';
import 'weather_fixtures.dart';

Future<void> recordAndFinish(WidgetTester tester) async {
  await goTo(tester, 'record');
  await tapVisible(tester, find.text('START'));
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tapVisible(tester, find.bySemanticsLabel('PAUSE'));
  await tapVisible(tester, find.bySemanticsLabel('FINISH'));
}

void main() {
  testWidgets('activity picker: one line with icons, scrolls on a small phone', (tester) async {
    await pumpApp(tester, sizes['small phone']!);
    await signInDemo(tester);
    await goTo(tester, 'record');
    final picker = find.byType(ActivityPicker);
    final rows = {
      for (final label in ['Cycling', 'Running', 'Motorcycling', 'Driving'])
        tester.getCenter(find.descendant(of: picker, matching: find.text(label))).dy,
    };
    expect(rows, hasLength(1), reason: 'all four on one line');
    expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget, reason: 'running icon');

    await tester.drag(
      find.descendant(of: picker, matching: find.byType(SingleChildScrollView)),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Driving'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Records your driving route'), findsOneWidget);
  });

  testWidgets('offline: the live map fills the phone, the ride saves for later', (tester) async {
    final repo = await pumpApp(tester, sizes['iPhone']!);
    repo.offline = true;
    await signInDemo(tester);
    await goTo(tester, 'record');
    await tapVisible(tester, find.text('START'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final map = tester.getSize(find.byType(MapView)).height;
    expect(map, greaterThan(844 * 0.6), reason: 'the map takes most of the screen');

    await tapVisible(tester, find.bySemanticsLabel('PAUSE'));
    await tapVisible(tester, find.bySemanticsLabel('FINISH'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save activity'));
    expect(find.text("Saved on this phone. It uploads when you're back online."), findsOneWidget);
  });

  testWidgets('a failed save keeps the ride so it can be tried again', (tester) async {
    final repo = await pumpApp(tester, sizes['iPhone']!);
    await signInDemo(tester);
    await recordAndFinish(tester);
    repo.failSaves = Exception('network');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save activity'));
    expect(find.textContaining("Couldn't save it"), findsOneWidget);

    repo.failSaves = null;
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save activity'));
    expect(find.text('Activity saved'), findsOneWidget);
  });

  testWidgets('weather icons draw every sky as line art, light and dark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final code in [0, 2, 3, 45, 51, 61, 71, 95])
              for (final isDay in [true, false])
                for (final color in [Colors.black, Colors.white])
                  WeatherArt(code: code, isDay: isDay, size: 40, color: color),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(WeatherArt), findsNWidgets(32));
  });

  test('a forecast for the default place is fetched again once location is known', () async {
    GeoPoint? here;
    final weather = WeatherController(FakeWeatherSource(), devicePosition: () async => here);
    await weather.load();
    expect(weather.place.isDefault, isTrue);

    here = const GeoPoint(7.07, 125.61);
    await weather.load();
    expect(weather.place.isDefault, isTrue, reason: 'a fresh forecast is kept');
    await weather.refreshForDevice();
    expect(weather.place.label, 'Your location');
  });
}
