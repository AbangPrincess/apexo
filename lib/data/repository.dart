import '../core/activity_type.dart';
import '../core/units.dart';
import 'models/activity.dart';
import 'models/circle.dart';
import 'models/circle_alert.dart';
import 'models/user.dart';

/// User-facing auth failure with a message that is safe to show.
class AuthException implements Exception {
  const AuthException(this.message, {this.retryAfter});
  final String message;

  /// Set when the action is blocked for a while (lockout or resend cooldown).
  final Duration? retryAfter;

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  /// Emits the signed-in user's profile, or null when signed out.
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;

  /// True for the in-memory demo backend.
  bool get isDemo;

  Future<void> signInDemo();
  Future<void> signIn({required String email, required String password});
  Future<void> createAccount({
    required String displayName,
    required String email,
    required String password,
  });
  Future<void> signOut();

  /// Sends (or re-sends) the verification link to the signed-in user.
  Future<void> sendEmailVerification();

  /// Re-reads the signed-in user, e.g. after they opened the link.
  Future<void> reloadUser();

  /// Sends a reset link. Succeeds silently for unknown emails so the form
  /// never reveals which emails have accounts.
  Future<void> sendPasswordReset(String email);
}

abstract interface class ProfileRepository {
  /// Null leaves a field unchanged; an empty string clears it.
  Future<void> updateProfile(
    String uid, {
    String? displayName,
    Units? units,
    ActivityType? defaultActivity,
    String? bio,
    String? hometown,
    String? photoUrl,
    String? coverUrl,
  });
  Stream<List<Vehicle>> watchVehicles(String uid);
}

abstract interface class ActivityRepository {
  /// Newest first.
  Stream<List<Activity>> watchActivities(String uid);
  Future<void> saveActivity(String uid, Activity activity);
  Future<void> deleteActivity(String uid, String activityId);
}

abstract interface class CircleRepository {
  /// Circles where [uid] is in memberUids.
  Stream<List<Circle>> watchCircles(String uid);
  Stream<List<Member>> watchMembers(String circleId);

  /// Newest first.
  Stream<List<CircleAlert>> watchAlerts(String circleId);
}

/// Everything the app needs from a backend.
abstract class AppRepository
    implements AuthRepository, ProfileRepository, ActivityRepository, CircleRepository {
  void dispose();
}
