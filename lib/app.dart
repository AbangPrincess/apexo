import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/repository.dart';
import 'features/auth/session_controller.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/circle/circle_controller.dart';
import 'features/feed/activities_controller.dart';
import 'features/me/settings_controller.dart';
import 'shell/app_shell.dart';
import 'widgets/brand_mark.dart';

class PedalTrackApp extends StatelessWidget {
  const PedalTrackApp({super.key, required this.repository, required this.prefs});

  final AppRepository repository;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppRepository>.value(value: repository),
        ChangeNotifierProvider(create: (_) => SessionController(repository), lazy: false),
        ChangeNotifierProvider(
            create: (_) => SettingsController(prefs, repository), lazy: false),
        ChangeNotifierProvider(create: (_) => ActivitiesController(repository)),
        ChangeNotifierProvider(create: (_) => CircleController(repository)),
      ],
      child: MaterialApp(
        title: 'PedalTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Shows sign-in or the app depending on the session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final ready = context.select<SessionController, bool>((s) => s.ready);
    final signedIn = context.select<SessionController, bool>((s) => s.user != null);
    final Widget child = !ready
        ? const Scaffold(body: Center(child: BrandMark(size: 40)))
        : signedIn
            ? const AppShell(key: ValueKey('shell'))
            : const SignInScreen(key: ValueKey('sign-in'));
    return AnimatedSwitcher(duration: kMotion, child: child);
  }
}
