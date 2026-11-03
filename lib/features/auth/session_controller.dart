import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/user.dart';
import '../../data/repository.dart';

enum SessionAction { demo, signIn, createAccount }

/// Signed-in state plus the busy/error state of the auth forms.
class SessionController extends ChangeNotifier {
  SessionController(this._repo) {
    _sub = _repo.authStateChanges().listen((user) {
      _user = user;
      _ready = true;
      notifyListeners();
    });
  }

  final AuthRepository _repo;
  late final StreamSubscription<AppUser?> _sub;

  AppUser? _user;
  bool _ready = false;
  SessionAction? _pending;
  String? _error;

  AppUser? get user => _user;
  bool get ready => _ready;
  bool get isDemo => _repo.isDemo;
  SessionAction? get pending => _pending;
  bool get busy => _pending != null;
  String? get error => _error;

  Future<bool> signInDemo() => _run(SessionAction.demo, _repo.signInDemo);

  Future<bool> signIn(String email, String password) => _run(
      SessionAction.signIn, () => _repo.signIn(email: email, password: password));

  Future<bool> createAccount(String name, String email, String password) => _run(
        SessionAction.createAccount,
        () => _repo.createAccount(displayName: name, email: email, password: password),
      );

  Future<void> signOut() => _repo.signOut();

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(SessionAction action, Future<void> Function() task) async {
    if (_pending != null) return false;
    _pending = action;
    _error = null;
    notifyListeners();
    try {
      await task();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Check your connection and try again.';
      return false;
    } finally {
      _pending = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
