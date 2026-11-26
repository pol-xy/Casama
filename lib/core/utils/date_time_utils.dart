/// Centralized Supabase `timestamptz` (UTC) and `date` (calendar-only)
/// serialization/deserialization helpers.
library;

final RegExp _tzDesignatorPattern = RegExp(
  r'(Z|[+-]\d{2}(:?\d{2})?)$',
  caseSensitive: false,
);

/// Converts any [DateTime] (local or UTC) to a strict UTC ISO-8601 string
/// ending in `'Z'` for PostgreSQL `timestamptz` columns and query filters.
String toSupabaseUtcIso(DateTime dt) => dt.toUtc().toIso8601String();

/// Nullable variant of [toSupabaseUtcIso].
String? toSupabaseUtcIsoOrNull(DateTime? dt) => dt?.toUtc().toIso8601String();

/// Returns the current instant as a strict UTC ISO-8601 string ending in `'Z'`.
String nowSupabaseUtcIso() => DateTime.now().toUtc().toIso8601String();

/// Parses a Supabase `timestamptz` value into a **local** [DateTime].
///
/// If the incoming string omits a timezone designator (no `'Z'` or `'±HH:MM'`),
/// it is treated as UTC before converting with `.toLocal()` so local timezone
/// offsets never shift the instant.
DateTime? parseSupabaseTimestampOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  final str = value.toString().trim();
  if (str.isEmpty) return null;

  final parsed = DateTime.tryParse(str);
  if (parsed == null) return null;

  if (!parsed.isUtc && !_tzDesignatorPattern.hasMatch(str)) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }
  return parsed.toLocal();
}

/// Non-nullable variant of [parseSupabaseTimestampOrNull], falling back to
/// [fallback] (or `DateTime.now()`) in local time.
DateTime parseSupabaseTimestamp(dynamic value, {DateTime? fallback}) {
  return parseSupabaseTimestampOrNull(value) ??
      (fallback ?? DateTime.now()).toLocal();
}

/// Parses a date-only `'YYYY-MM-DD'` column (such as `profiles.birthday`)
/// into a local calendar [DateTime(year, month, day)] without UTC conversion.
DateTime? parseSupabaseDateOnly(dynamic raw) {
  if (raw == null) return null;
  final str = raw.toString().trim();
  if (str.isEmpty) return null;
  final datePart = str.split(RegExp(r'[T ]')).first;
  final parts = datePart.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final dt = DateTime(year, month, day);
  if (dt.year != year || dt.month != month || dt.day != day) return null;
  return dt;
}

/// Formats a local calendar [DateTime] as `'YYYY-MM-DD'` without UTC shift.
String? formatSupabaseDateOnly(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
