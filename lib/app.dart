import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/repository.dart';
import 'data/weather_source.dart';
import 'features/auth/session_controller.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/verify_email_screen.dart';
import 'features/circle/battery_level.dart';
import 'features/circle/circle_controller.dart';
import 'features/circle/sharing_controller.dart';
import 'features/feed/activities_controller.dart';
import 'features/feed/circle_feed_controller.dart';
import 'features/me/settings_controller.dart';
import 'features/record/location_source.dart';
import 'features/record/record_controller.dart';
import 'features/weather/weather_controller.dart';
import 'shell/app_shell.dart';
import 'widgets/brand_mark.dart';

class ApexoApp extends StatelessWidget {
  const ApexoApp({super.key, required this.repository, required this.prefs, this.weatherSource});

  final AppRepository repository;
  final SharedPreferences prefs;

  /// Open-Meteo unless a test passes a fake.
  final WeatherSource? weatherSource;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppRepository>.value(value: repository),
        ChangeNotifierProvider(create: (_) => SessionController(repository), lazy: false),
        ChangeNotifierProvider(create: (_) => SettingsController(prefs, repository), lazy: false),
        ChangeNotifierProvider(create: (_) => ActivitiesController(repository)),
        ChangeNotifierProvider(create: (_) => CircleController(repository)),
        ChangeNotifierProvider(
          create: (_) => WeatherController(
            weatherSource ?? OpenMeteoSource(),
            devicePosition: repository.isDemo ? null : DeviceLocationSource().positionIfAllowed,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => RecordController(
            repository,
            device: DeviceLocationSource(),
            simulator: SimulatedLocationSource(),
            weather: context.read<WeatherController>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => CircleFeedController(repository)),
        ChangeNotifierProvider(
          create: (context) => SharingController(
            repository,
            context.read<RecordController>(),
            readBattery: readBatteryLevel,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Apexo',
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
    final verify = context.select<SessionController, bool>((s) => s.needsVerification);
    final Widget child = !ready
        ? const Scaffold(body: Center(child: BrandMark(size: 40)))
        : !signedIn
        ? const SignInScreen(key: ValueKey('sign-in'))
        : verify
        ? const VerifyEmailScreen(key: ValueKey('verify'))
        : const AppShell(key: ValueKey('shell'));
    return AnimatedSwitcher(duration: kMotion, child: child);
  }
}
