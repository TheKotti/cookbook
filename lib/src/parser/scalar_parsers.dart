/// Parses an ISO-8601 duration (e.g. `PT15M` or Chefkoch's `P0DT0H15M`)
/// into total minutes. Returns null when absent, unparseable, or zero.
int? parseIso8601DurationToMinutes(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$')
      .firstMatch(value.trim());
  if (match == null) return null;
  if (match[1] == null && match[2] == null && match[3] == null && match[4] == null) {
    return null;
  }
  final minutes = int.parse(match[1] ?? '0') * 24 * 60 +
      int.parse(match[2] ?? '0') * 60 +
      int.parse(match[3] ?? '0');
  return minutes == 0 ? null : minutes;
}

/// Parses schema.org `recipeYield` into a serving count.
/// Real Chefkoch value is a string like `"2 Portionen"` — take the leading
/// integer. Returns null when it can't be determined (scaler is then hidden).
int? parseServings(Object? yieldValue) {
  if (yieldValue is num) {
    final n = yieldValue.toInt();
    return n >= 1 ? n : null;
  }
  if (yieldValue is String) {
    final match = RegExp(r'^\s*(\d+)').firstMatch(yieldValue);
    if (match == null) return null;
    final n = int.parse(match[1]!);
    return n >= 1 ? n : null;
  }
  if (yieldValue is List && yieldValue.isNotEmpty) {
    return parseServings(yieldValue.first);
  }
  return null;
}
