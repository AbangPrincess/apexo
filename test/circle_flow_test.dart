import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

void main() {
  for (final name in ['small phone', 'desktop']) {
    final size = sizes[name]!;

    testWidgets('$name: shared rides on Home, create a circle, leave it', (tester) async {
      await pumpApp(tester, size);
      await signInDemo(tester);

      // Circle members' rides show on Home with their name, read-only.
      expect(find.textContaining('Shane ·', skipOffstage: false), findsOneWidget);
      await tapVisible(tester, find.text('Coffee Run', skipOffstage: false));
      expect(find.textContaining('by Shane'), findsOneWidget);
      expect(find.byTooltip('Delete activity'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await goTo(tester, 'circle');
      await tapVisible(tester, find.byTooltip('Switch circle'));
      await tapVisible(tester, find.text('Create a circle'));
      await tapVisible(tester, find.text('Next'));
      expect(find.text('Enter a name for your circle'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Night Riders');
      await tapVisible(tester, find.text('Next'));

      expect(find.text('Share your location with Night Riders?'), findsOneWidget);
      await tapVisible(tester, find.text('Create with sharing paused'));
      expect(find.text('Night Riders is ready'), findsOneWidget);
      final code = tester.widget<Text>(find.byKey(const ValueKey('invite-code'))).data!;
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{6}$')));
      await tapVisible(tester, find.text('Done'));

      expect(find.text('Night Riders'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);
      expect(find.text(code), findsOneWidget);

      await tapVisible(tester, find.byTooltip('Members and sharing'));
      await tapVisible(tester, find.text('Leave circle'));
      expect(find.textContaining('last member'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(TextButton, 'Leave'));
      expect(find.text('You left Night Riders'), findsOneWidget);
      expect(find.text('Trail Buddies'), findsOneWidget);
    });
  }

  for (final name in ['iPhone', 'tablet']) {
    final size = sizes[name]!;

    testWidgets('$name: a new account joins TRAIL7 after the consent screen', (tester) async {
      await pumpApp(tester, size);
      await signUpAna(tester);
      await goTo(tester, 'circle');
      await tapVisible(tester, find.text('Join with a code'));

      final field = find.byType(TextFormField);
      await tester.enterText(field, 'zz');
      await tapVisible(tester, find.text('Find circle'));
      expect(find.text('Codes have 6 letters and numbers'), findsOneWidget);
      await tester.enterText(field, 'abc234');
      await tapVisible(tester, find.text('Find circle'));
      expect(find.textContaining('No circle uses that code'), findsOneWidget);
      await tester.enterText(field, 'trail 7');
      await tapVisible(tester, find.text('Find circle'));

      expect(find.text('Share your location with Trail Buddies?'), findsOneWidget);
      expect(find.text('3 members · Owner: You'), findsOneWidget);
      await tapVisible(tester, find.text('Join with sharing paused'));
      expect(find.text('You joined Trail Buddies.'), findsOneWidget);
      expect(find.text('Jero'), findsOneWidget);
      expect(find.text('4 members'), findsOneWidget);

      await goTo(tester, 'home');
      expect(find.text('No activities yet'), findsNothing);
      expect(find.textContaining('Shane ·', skipOffstage: false), findsOneWidget);
    });
  }

  testWidgets('sharing shows a persistent bar on every tab until paused', (tester) async {
    await pumpApp(tester, sizes['iPhone']!);
    await signInDemo(tester);
    await goTo(tester, 'circle');
    expect(find.text('Sharing live with 1 circle'), findsNothing);

    await tapVisible(tester, find.byKey(const ValueKey('share-switch')));
    expect(find.text('Sharing live with 1 circle'), findsOneWidget);
    await goTo(tester, 'record');
    expect(find.text('Sharing live with 1 circle'), findsOneWidget);

    await tapVisible(tester, find.text('Manage'));
    await tapVisible(tester, find.byKey(const ValueKey('share-switch')));
    expect(find.text('Sharing live with 1 circle'), findsNothing);
  });
}
