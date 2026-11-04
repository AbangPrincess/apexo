import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/login_throttle.dart';
import '../models/user.dart';
import '../repository.dart';

AuthException authError(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' ||
  'invalid-login-credentials' ||
  'wrong-password' ||
  'user-not-found' => const AuthException('Email or password is incorrect.'),
  'invalid-email' => const AuthException('Enter a valid email address.'),
  'email-already-in-use' => const AuthException(
    'That email already has an account. Sign in instead.',
  ),
  'weak-password' => const AuthException('Choose a stronger password.'),
  'too-many-requests' => const AuthException(
    'Too many attempts. Wait a minute and try again, or reset your password.',
    retryAfter: Duration(minutes: 1),
  ),
  'network-request-failed' => const AuthException(
    'No connection. Check your internet and try again.',
  ),
  'user-disabled' => const AuthException('This account has been turned off.'),
  _ => const AuthException('Something went wrong. Please try again.'),
};

/// Firebase Auth plus the users/{uid} profile. Until the email is verified
/// the profile comes from Auth alone, because the rules only let verified
/// accounts read or write Firestore. The first verified sign-in creates it.
mixin FbAuth on AppRepository {
  FirebaseAuth get auth;
  FirebaseFirestore get db;

  final _throttle = LoginThrottle();
  final _users = StreamController<AppUser?>.broadcast();
  final _resolved = Completer<void>();
  AppUser? _current;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  String? _profileUid;

  void startAuth() => _authSub = auth.userChanges().listen(_onAuthUser);

  @override
  bool get isDemo => false;

  @override
  AppUser? get currentUser => _current;

  /// Waits for Auth to restore the session, so the app never flashes the
  /// sign-in screen for someone who is signed in.
  @override
  Stream<AppUser?> authStateChanges() async* {
    await _resolved.future;
    yield _current;
    yield* _users.stream;
  }

  void _emit(AppUser? u) {
    _current = u;
    if (!_resolved.isCompleted) _resolved.complete();
    _users.add(u);
  }

  void _onAuthUser(User? u) {
    if (u == null || !u.emailVerified) {
      _stopProfile();
      return _emit(u == null ? null : _fromAuth(u, verified: false));
    }
    if (_profileUid == u.uid) return;
    _stopProfile();
    _profileUid = u.uid;
    final ref = db.collection('users').doc(u.uid);
    _profileSub = ref.snapshots().listen((snap) {
      final data = snap.data();
      if (data != null) return _emit(AppUser.fromMap(u.uid, data));
      _emit(_fromAuth(u, verified: true));
      // Missing on the server (not just absent from the offline cache).
      if (!snap.metadata.isFromCache) {
        ref.set(_fromAuth(u, verified: true).toMap(), SetOptions(merge: true));
      }
    }, onError: (Object _) => _emit(_fromAuth(u, verified: true)));
  }

  void _stopProfile() {
    _profileSub?.cancel();
    _profileSub = null;
    _profileUid = null;
  }

  AppUser _fromAuth(User u, {required bool verified}) {
    final name = u.displayName?.trim() ?? '';
    return AppUser(
      uid: u.uid,
      displayName: name.isNotEmpty ? name : (u.email ?? 'Rider').split('@').first,
      email: u.email ?? '',
      createdAt: u.metadata.creationTime ?? DateTime.now(),
      emailVerified: verified,
    );
  }

  @override
  Future<void> signInDemo() async =>
      throw const AuthException('The demo account is only in the demo build.');

  @override
  Future<void> signIn({required String email, required String password}) async {
    final key = email.trim().toLowerCase();
    final lock = _throttle.lockRemaining(key);
    if (lock != null) throw _locked(lock);
    try {
      await auth.signInWithEmailAndPassword(email: key, password: password);
      _throttle.recordSuccess(key);
    } on FirebaseAuthException catch (e) {
      final error = authError(e);
      if (error.message != 'Email or password is incorrect.') throw error;
      final locked = _throttle.recordFailure(key);
      if (locked != null) throw _locked(locked);
      final left = _throttle.attemptsLeft(key);
      throw AuthException(
        left <= 2
            ? 'Email or password is incorrect. $left ${left == 1 ? 'try' : 'tries'} left before a short lock.'
            : error.message,
      );
    }
  }

  AuthException _locked(Duration d) => AuthException(
    'Too many attempts. Try again in ${formatWait(d)}, or reset your password.',
    retryAfter: d,
  );

  @override
  Future<void> createAccount({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(displayName.trim());
      await user.sendEmailVerification();
      await user.reload();
      _onAuthUser(auth.currentUser);
    } on FirebaseAuthException catch (e) {
      throw authError(e);
    }
  }

  @override
  Future<void> signOut() => auth.signOut();

  @override
  Future<void> sendEmailVerification() async {
    final u = auth.currentUser;
    if (u == null || u.emailVerified) return;
    try {
      await u.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw authError(e);
    }
  }

  @override
  Future<void> reloadUser() async {
    final u = auth.currentUser;
    if (u == null) return;
    try {
      await u.reload();
      final fresh = auth.currentUser;
      // The rules read email_verified from the token, so refresh it.
      if (fresh != null && fresh.emailVerified) await fresh.getIdToken(true);
      _onAuthUser(fresh);
    } on FirebaseAuthException catch (e) {
      throw authError(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Never reveal whether an email has an account.
      if (e.code == 'user-not-found') return;
      throw authError(e);
    }
  }

  void disposeAuth() {
    _authSub?.cancel();
    _stopProfile();
    _users.close();
  }
}
