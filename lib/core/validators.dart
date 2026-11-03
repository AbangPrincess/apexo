const int minPasswordLength = 8;

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Returns an error message, or null when valid (Form validator shape).
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email';
  if (!_email.hasMatch(v)) return 'Enter a valid email, like name@example.com';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter your password';
  if (v.length < minPasswordLength) {
    return 'Use at least $minPasswordLength characters';
  }
  return null;
}

String? validateDisplayName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your name';
  if (v.length > 40) return 'Keep it under 40 characters';
  return null;
}
