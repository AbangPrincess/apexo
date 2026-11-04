import 'dart:math';

/// Letters and digits without look-alikes (0/O, 1/I/L), so codes read aloud
/// or copied from a screenshot are hard to get wrong.
const inviteAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const inviteCodeLength = 6;

String generateInviteCode([Random? random]) {
  final r = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < inviteCodeLength; i++)
      inviteAlphabet.codeUnitAt(r.nextInt(inviteAlphabet.length)),
  ]);
}

/// Upper-cases and drops spaces and dashes, so "trail 7" finds TRAIL7.
String normalizeInviteCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

/// Shape only: the demo code TRAIL7 predates the look-alike rule.
bool isInviteCodeShape(String code) => RegExp(r'^[A-Z0-9]{6}$').hasMatch(code);
