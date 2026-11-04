import 'package:firebase_core/firebase_core.dart';

/// Placeholder. `flutterfire configure` replaces this file with the real
/// options; while it throws, the app runs on the demo backend. Keep the
/// real file out of Git (see README "Needs you").
abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Firebase is not configured yet. Run flutterfire configure.');
}
