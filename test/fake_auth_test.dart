import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/login_throttle.dart';
import 'package:apexo/data/fake/fake_auth.dart';
import 'package:apexo/data/fake/fake_repository.dart';
import 'package:apexo/data/repository.dart';

void main() {
  late DateTime clock;
  late FakeRepository repo;

  setUp(() {
    clock = DateTime(2026, 11, 4, 9);
    repo = FakeRepository(
      simulate: false,
      latency: Duration.zero,
      auth: FakeAuth(
        clock: () => clock,
        throttle: LoginThrottle(clock: () => clock),
      ),
    );
  });
  tearDown(() => repo.dispose());

  Future<void> signUp() =>
      repo.createAccount(displayName: 'Ana', email: 'ana@example.com', password: 'secret-123');

  test('new accounts stay unverified until the emailed link is opened', () async {
    await signUp();
    expect(repo.currentUser!.emailVerified, isFalse);

    final mail = repo.inbox('ANA@example.com');
    expect(mail, hasLength(1));
    expect(mail.single.kind, DemoEmailKind.verify);

    await repo.openVerifyLink(mail.single);
    expect(repo.currentUser!.emailVerified, isTrue);

    // Links work once.
    await expectLater(repo.openVerifyLink(mail.single), throwsA(isA<AuthException>()));

    // Signing in again keeps the verified state.
    await repo.signOut();
    await repo.signIn(email: 'ana@example.com', password: 'secret-123');
    expect(repo.currentUser!.emailVerified, isTrue);
  });

  test('resending has a cooldown and expires the older link', () async {
    await signUp();
    await expectLater(repo.sendEmailVerification(), throwsA(isA<AuthException>()));
    clock = clock.add(const Duration(seconds: 61));
    await repo.sendEmailVerification();
    final mail = repo.inbox('ana@example.com');
    expect(mail, hasLength(2));
    expect(mail.first.usable, isTrue); // newest first
    expect(mail.last.usable, isFalse);
    await expectLater(repo.openVerifyLink(mail.last), throwsA(isA<AuthException>()));
  });

  test('five wrong passwords lock the account, even for unknown emails', () async {
    await signUp();
    await repo.signOut();
    for (var i = 0; i < 4; i++) {
      await expectLater(
        repo.signIn(email: 'ana@example.com', password: 'guess-$i'),
        throwsA(isA<AuthException>()),
      );
    }
    final locked = await repo
        .signIn(email: 'ana@example.com', password: 'guess-5')
        .then<AuthException?>((_) => null, onError: (Object e) => e as AuthException);
    expect(locked!.retryAfter, const Duration(seconds: 30));

    // Even the right password is refused while locked.
    await expectLater(
      repo.signIn(email: 'ana@example.com', password: 'secret-123'),
      throwsA(isA<AuthException>()),
    );
    clock = clock.add(const Duration(seconds: 31));
    await repo.signIn(email: 'ana@example.com', password: 'secret-123');
    expect(repo.currentUser, isNotNull);

    for (var i = 0; i < 5; i++) {
      await repo.signIn(email: 'ghost@example.com', password: 'x$i').catchError((Object _) {});
    }
    expect(repo.accounts.throttle.lockRemaining('ghost@example.com'), isNotNull);
  });

  test('password reset email sets a new password and lifts the lock', () async {
    await signUp();
    await repo.signOut();
    for (var i = 0; i < 5; i++) {
      await repo.signIn(email: 'ana@example.com', password: 'nope-$i').catchError((Object _) {});
    }
    await repo.sendPasswordReset('ana@example.com');
    await repo.sendPasswordReset('nobody@example.com'); // silent
    expect(repo.inbox('nobody@example.com'), isEmpty);

    final reset = repo.inbox('ana@example.com').firstWhere((e) => e.kind == DemoEmailKind.reset);
    await expectLater(repo.resetPassword(reset, 'short'), throwsA(isA<AuthException>()));
    await repo.resetPassword(reset, 'brand-new-9');
    await repo.signIn(email: 'ana@example.com', password: 'brand-new-9');
    expect(repo.currentUser!.displayName, 'Ana');
  });

  test('profile fields update and can be cleared', () async {
    await repo.signInDemo();
    final uid = repo.currentUser!.uid;
    await repo.updateProfile(
      uid,
      bio: 'Weekend climber',
      hometown: 'Koronadal',
      photoUrl: 'data:image/png;base64,AA==',
    );
    expect(repo.currentUser!.bio, 'Weekend climber');
    expect(repo.currentUser!.photoUrl, isNotEmpty);
    await repo.updateProfile(uid, photoUrl: '');
    expect(repo.currentUser!.photoUrl, isEmpty);
    expect(repo.currentUser!.hometown, 'Koronadal');
  });
}
