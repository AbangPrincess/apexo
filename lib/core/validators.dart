const int minPasswordLength = 8;
const int maxBioLength = 160;
const int maxHometownLength = 40;

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _letter = RegExp(r'[A-Za-z]');
final _digit = RegExp(r'\d');

/// Returns an error message, or null when valid (Form validator shape).
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email';
  if (!_email.hasMatch(v)) return 'Enter a valid email, like name@example.com';
  return null;
}

/// Rules for a new password, each with whether [value] meets it.
List<(String, bool)> passwordChecks(String value) => [
  ('At least $minPasswordLength characters', value.length >= minPasswordLength),
  ('A letter', _letter.hasMatch(value)),
  ('A number', _digit.hasMatch(value)),
];

/// For new passwords. Signing in only checks that a password was entered.
String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter a password';
  if (v.length < minPasswordLength) return 'Use at least $minPasswordLength characters';
  if (!_letter.hasMatch(v) || !_digit.hasMatch(v)) return 'Use letters and numbers';
  return null;
}

String? validateDisplayName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your name';
  if (v.length > 40) return 'Keep it under 40 characters';
  return null;
}

String? validateBio(String? value) =>
    (value ?? '').trim().length > maxBioLength ? 'Keep it under $maxBioLength characters' : null;

String? validateHometown(String? value) => (value ?? '').trim().length > maxHometownLength
    ? 'Keep it under $maxHometownLength characters'
    : null;
