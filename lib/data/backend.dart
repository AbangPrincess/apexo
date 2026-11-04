import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'fake/fake_repository.dart';
import 'firebase/firebase_repository.dart';
import 'repository.dart';

/// Set by the GitHub Pages build (`--dart-define=APEXO_DEMO=true`), so the
/// public demo never touches a real project.
const forceDemo = bool.fromEnvironment('APEXO_DEMO');

/// Firebase when `flutterfire configure` has run for this platform, else the
/// in-memory demo backend (zero setup).
Future<AppRepository> createRepository() async {
  if (forceDemo) return FakeRepository();
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    // The placeholder, or a platform left out of `flutterfire configure`.
    return FakeRepository();
  }
  await Firebase.initializeApp(options: options);
  // On the web nothing stays on disk: no Firestore cache (it would hold
  // members' locations), and the sign-in ends when the tab closes.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: !kIsWeb);
  if (kIsWeb) await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  return FirebaseRepository();
}
