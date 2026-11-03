import 'dart:math';

import '../../core/login_throttle.dart';
import '../../core/validators.dart';
import '../repository.dart';

enum DemoEmailKind { verify, reset }

/// An email the demo backend "sent". Real emails need Firebase (see README).
class DemoEmail {
  DemoEmail({
    required this.kind,
    required this.to,
    required this.subject,
    required this.body,
    required this.actionLabel,
    required this.sentAt,
    required this.token,
  });

  final DemoEmailKind kind;
  final String to;
  final String subject;
  final String body;
  final String actionLabel;
  final DateTime sentAt;
  final String token;
  bool used = false;
  bool expired = false;

  bool get usable => !used && !expired;
}

/// Lets the UI show demo emails. Only the demo backend implements it.
abstract interface class DemoMailbox {
  List<DemoEmail> inbox(String email);
  Future<void> openVerifyLink(DemoEmail email);
  Future<void> resetPassword(DemoEmail email, String newPassword);
}

class FakeAccount {
  FakeAccount(this.uid, this.email, this._password);
  final String uid;
  final String email;
  String _password;
  bool verified = false;

  bool matches(String password) => password == _password;
}

/// Accounts, lockout, cooldowns and the outbox for the demo backend. It plays
/// the role of the auth server, so its rules cannot be skipped by the UI.
class FakeAuth {
  FakeAuth({
    LoginThrottle? throttle,
    DateTime Function()? clock,
    this.cooldown = const Duration(seconds: 60),
  }) : throttle = throttle ?? LoginThrottle(clock: clock),
       _now = clock ?? DateTime.now;

  final LoginThrottle throttle;
  final Duration cooldown;
  final DateTime Function() _now;
  final _accounts = <String, FakeAccount>{};
  final _outbox = <DemoEmail>[];
  final _lastSent = <String, DateTime>{};
  final _random = Random.secure();

  static String keyOf(String email) => email.trim().toLowerCase();

  FakeAccount? byUid(String uid) {
    for (final a in _accounts.values) {
      if (a.uid == uid) return a;
    }
    return null;
  }

  List<DemoEmail> inbox(String email) =>
      _outbox.where((e) => keyOf(e.to) == keyOf(email)).toList().reversed.toList();

  FakeAccount create(String uid, String email, String password) {
    final key = keyOf(email);
    if (_accounts.containsKey(key)) {
      throw const AuthException('That email already has an account. Sign in instead.');
    }
    return _accounts[key] = FakeAccount(uid, email.trim(), password);
  }

  /// Returns the account for valid credentials. Unknown emails and wrong
  /// passwords fail the same way and both count toward the lock.
  FakeAccount checkPassword(String email, String password) {
    final key = keyOf(email);
    final lock = throttle.lockRemaining(key);
    if (lock != null) throw _locked(lock);
    final account = _accounts[key];
    if (account == null || !account.matches(password)) {
      final locked = throttle.recordFailure(key);
      if (locked != null) throw _locked(locked);
      final left = throttle.attemptsLeft(key);
      throw AuthException(
        left <= 2
            ? 'Email or password is incorrect. $left ${left == 1 ? 'try' : 'tries'} left before a short lock.'
            : 'Email or password is incorrect.',
      );
    }
    throttle.recordSuccess(key);
    return account;
  }

  AuthException _locked(Duration d) => AuthException(
    'Too many attempts. Try again in ${formatWait(d)}, or reset your password.',
    retryAfter: d,
  );

  void sendVerification(FakeAccount account) => _send(
    DemoEmailKind.verify,
    account.email,
    'Verify your Apexo email',
    'Confirm this is your email to finish creating your account. The link works once.',
    'Verify email',
  );

  /// Quietly does nothing for unknown emails (no account enumeration).
  void sendReset(String email) {
    if (!_accounts.containsKey(keyOf(email))) {
      _cooldownCheck(DemoEmailKind.reset, email);
      return;
    }
    _send(
      DemoEmailKind.reset,
      email.trim(),
      'Reset your Apexo password',
      'Someone asked to reset the password for this account. If it was not you, ignore this email.',
      'Reset password',
    );
  }

  FakeAccount verify(DemoEmail email) {
    final account = _use(email, DemoEmailKind.verify);
    account.verified = true;
    return account;
  }

  void reset(DemoEmail email, String newPassword) {
    final problem = validatePassword(newPassword);
    if (problem != null) throw AuthException(problem);
    final account = _use(email, DemoEmailKind.reset);
    account._password = newPassword;
    // Opening a reset link proves ownership, so it also lifts any lock.
    throttle.recordSuccess(keyOf(account.email));
  }

  FakeAccount _use(DemoEmail email, DemoEmailKind kind) {
    final account = _accounts[keyOf(email.to)];
    if (email.kind != kind || !email.usable || account == null) {
      throw const AuthException('This link has expired. Ask for a new email.');
    }
    email.used = true;
    return account;
  }

  void _send(DemoEmailKind kind, String to, String subject, String body, String action) {
    _cooldownCheck(kind, to);
    // A new link replaces older ones of the same kind.
    for (final e in _outbox) {
      if (e.kind == kind && keyOf(e.to) == keyOf(to)) e.expired = true;
    }
    _outbox.add(
      DemoEmail(
        kind: kind,
        to: to,
        subject: subject,
        body: body,
        actionLabel: action,
        sentAt: _now(),
        token: List.generate(
          16,
          (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
      ),
    );
  }

  void _cooldownCheck(DemoEmailKind kind, String to) {
    final key = '${kind.name}:${keyOf(to)}';
    final last = _lastSent[key];
    final now = _now();
    if (last != null) {
      final wait = cooldown - now.difference(last);
      if (wait > Duration.zero) {
        throw AuthException(
          'Please wait ${formatWait(wait)} before sending another email.',
          retryAfter: wait,
        );
      }
    }
    _lastSent[key] = now;
  }
}
