import 'fake/fake_repository.dart';
import 'repository.dart';

/// Picks the backend. P6 adds FirebaseRepository, chosen when
/// `DefaultFirebaseOptions.isConfigured` is true; until then the in-memory
/// demo backend runs with zero setup.
AppRepository createRepository() => FakeRepository();
