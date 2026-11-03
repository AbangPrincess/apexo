const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "6:05 AM"
String formatClock(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "6 AM", "12 PM"
String formatHour(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h12 ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today at 6:05 AM", "Yesterday at ...", "Tue at ..." (this week) or "Oct 27, 2026".
String formatRelativeDate(DateTime t, DateTime now) {
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'Today at ${formatClock(t)}';
  if (days == 1) return 'Yesterday at ${formatClock(t)}';
  if (days > 1 && days < 7) return '${_weekdays[t.weekday - 1]} at ${formatClock(t)}';
  final sameYear = t.year == now.year;
  return '${_months[t.month - 1]} ${t.day}${sameYear ? '' : ', ${t.year}'}';
}

/// "just now", "45 s ago", "5 min ago", "3 h ago", "2 d ago".
String formatAgo(DateTime t, DateTime now) {
  final s = now.difference(t).inSeconds;
  if (s < 10) return 'just now';
  if (s < 60) return '$s s ago';
  if (s < 3600) return '${s ~/ 60} min ago';
  if (s < 86400) return '${s ~/ 3600} h ago';
  return '${s ~/ 86400} d ago';
}

/// "Good morning" / "Good afternoon" / "Good evening".
String greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// "Tuesday, November 3"
String formatLongDate(DateTime t) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${days[t.weekday - 1]}, ${months[t.month - 1]} ${t.day}';
}
