// Tolerant readers for documents coming from Firestore or the demo backend.

DateTime readDate(Object? v) {
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  // Firestore Timestamp exposes toDate(); read it without importing the SDK.
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

DateTime? readDateOrNull(Object? v) => v == null ? null : readDate(v);

double readDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

int readInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

String readString(Object? v, [String fallback = '']) => v is String ? v : fallback;

T readEnum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

Map<String, dynamic>? readMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

List<String> readStringList(Object? v) => v is List ? v.whereType<String>().toList() : const [];
