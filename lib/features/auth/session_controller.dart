import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/user.dart';
import '../../data/repository.dart';

enum SessionAction { demo, signIn, createAccount, resend, reload, reset }

/// Signed-in state plus busy, error, lockout and cooldown state for the
/// auth screens. The backend enforces the limits; this mirrors them in the UI.
class SessionController extends ChangeNotifier {
  SessionController(this._repo) {
    _sub = _repo.authStateChanges().listen((user) {
      _user = user;
      _ready = true;
      notifyListeners();
    });
  }

  static const emailCooldown = Duration(seconds: 60);

  final AuthRepository _repo;
  late final StreamSubscription<AppUser?> _sub;
  Timer? _ticker;

  AppUser? _user;
  bool _ready = false;
  SessionAction? _pending;
  String? _error;
  String? _lockedEmail;
  DateTime? _lockedUntil;
  DateTime? _cooldownUntil;

  AppUser? get user => _user;
  bool get ready => _ready;
  bool get isDemo => _repo.isDemo;
  bool get needsVerification => _user != null && !_user!.emailVerified;
  SessionAction? get pending => _pending;
  bool get busy => _pending != null;
  String? get error => _error;

  /// Time left on a sign-in lock for [email], or null.
  Duration? lockLeftFor(String email) => _lockedEmail == _key(email) ? _left(_lockedUntil) : null;

  /// Time left before another email can be sent, or null.
  Duration? get cooldownLeft => _left(_cooldownUntil);

  Future<bool> signInDemo() => _run(SessionAction.demo, _repo.signInDemo);

  Future<bool> signIn(String email, String password) => _run(
    SessionAction.signIn,
    () => _repo.signIn(email: email, password: password),
    lockKey: _key(email),
  );

  Future<bool> createAccount(String name, String email, String password) async {
    final ok = await _run(
      SessionAction.createAccount,
      () => _repo.createAccount(displayName: name, email: email, password: password),
    );
    // The first verification email went out with the new account.
    if (ok) _startCooldown(emailCooldown);
    return ok;
  }

  Future<bool> resendVerification() async {
    final ok = await _run(SessionAction.resend, _repo.sendEmailVerification);
    if (ok) _startCooldown(emailCooldown);
    return ok;
  }

  /// True when the email is now verified.
  Future<bool> checkVerified() async {
    await _run(SessionAction.reload, _repo.reloadUser);
    if (!needsVerification) return true;
    _error = 'Not verified yet. Open the link in the email, then try again.';
    notifyListeners();
    return false;
  }

  Future<bool> sendPasswordReset(String email) async {
    final ok = await _run(SessionAction.reset, () => _repo.sendPasswordReset(email));
    if (ok) _startCooldown(emailCooldown);
    return ok;
  }

  Future<void> signOut() => _repo.signOut();

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(SessionAction action, Future<void> Function() task, {String? lockKey}) async {
    if (_pending != null) return false;
    _pending = action;
    _error = null;
    notifyListeners();
    try {
      await task();
      if (lockKey != null && lockKey == _lockedEmail) _lockedUntil = null;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      final wait = e.retryAfter;
      if (wait != null && lockKey != null) {
        _lockedEmail = lockKey;
        _lockedUntil = clock.now().add(wait);
        _tick();
      } else if (wait != null) {
        _startCooldown(wait);
      }
      return false;
    } catch (_) {
      _error = 'Something went wrong. Check your connection and try again.';
      return false;
    } finally {
      _pending = null;
      notifyListeners();
    }
  }

  void _startCooldown(Duration d) {
    _cooldownUntil = clock.now().add(d);
    _tick();
  }

  /// Rebuilds once a second while a countdown is showing.
  void _tick() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left(_lockedUntil) == null && _left(_cooldownUntil) == null) {
        _ticker?.cancel();
        _ticker = null;
      }
      notifyListeners();
    });
  }

  static String _key(String email) => email.trim().toLowerCase();

  static Duration? _left(DateTime? until) {
    if (until == null) return null;
    final left = until.difference(clock.now());
    return left > Duration.zero ? left : null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub.cancel();
    super.dispose();
  }
}
