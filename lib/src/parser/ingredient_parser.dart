import '../models/recipe.dart';

const Set<String> _units = {
  'g', 'kg', 'mg', 'ml', 'cl', 'l', 'Liter',
  'EL', 'TL', 'Msp.', 'Prise', 'Prisen', 'Bund',
  'Dose', 'Dosen', 'Stück', 'Pck.', 'Päckchen', 'Packung',
  'Becher', 'Tasse', 'Tassen', 'Glas', 'Zehe', 'Zehen',
  'Scheibe', 'Scheiben', 'Blatt', 'Blätter', 'Zweig', 'Zweige',
  'Stange', 'Stangen', 'Würfel', 'Tropfen', 'Schuss', 'Handvoll',
};

const Map<String, double> _fractions = {
  '½': 0.5, '⅓': 1 / 3, '⅔': 2 / 3, '¼': 0.25, '¾': 0.75,
  '⅕': 0.2, '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
};

final RegExp _leadingQualifier =
    RegExp(r'^(etwas|ca\.|evtl\.|ggf\.)\s+', caseSensitive: false);
final RegExp _range =
    RegExp(r'^(\d+(?:[.,]\d+)?)\s*[-–—]\s*(\d+(?:[.,]\d+)?)(?=\s|$)');
final RegExp _mixedFraction = RegExp(r'^(\d+)\s*([½⅓⅔¼¾⅕⅛⅜⅝⅞])(?=\s|$)');
final RegExp _loneFraction = RegExp(r'^([½⅓⅔¼¾⅕⅛⅜⅝⅞])(?=\s|$)');
final RegExp _asciiFraction = RegExp(r'^(\d+)\s*/\s*(\d+)(?=\s|$)');
final RegExp _decimal = RegExp(r'^(\d+(?:[.,]\d+)?)(?=\s|$)');

double _toDouble(String s) => double.parse(s.replaceAll(',', '.'));

/// Parses one Chefkoch `recipeIngredient` string. Never throws and never
/// drops the ingredient: on any uncertainty the structured fields are null
/// and `raw` carries the original text (§6).
Ingredient parseIngredient(String input) {
  final raw = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  try {
    var rest = raw.replaceFirst(_leadingQualifier, '');

    double? amount;
    double? amountMax;
    RegExpMatch? m;
    if ((m = _range.firstMatch(rest)) != null) {
      amount = _toDouble(m![1]!);
      amountMax = _toDouble(m[2]!);
    } else if ((m = _mixedFraction.firstMatch(rest)) != null) {
      amount = int.parse(m![1]!) + _fractions[m[2]!]!;
    } else if ((m = _loneFraction.firstMatch(rest)) != null) {
      amount = _fractions[m![1]!]!;
    } else if ((m = _asciiFraction.firstMatch(rest)) != null) {
      amount = int.parse(m![1]!) / int.parse(m[2]!);
    } else if ((m = _decimal.firstMatch(rest)) != null) {
      amount = _toDouble(m![1]!);
    }
    if (m != null) rest = rest.substring(m.end).trim();

    String? unit;
    if (amount != null) {
      final unitMatch = RegExp(r'^(\S+)\s+(\S.*)$').firstMatch(rest);
      if (unitMatch != null && _units.contains(unitMatch[1])) {
        unit = unitMatch[1];
        rest = unitMatch[2]!;
      }
    }

    var name = rest;
    final parenIndex = name.indexOf(' (');
    if (parenIndex > 0) name = name.substring(0, parenIndex);
    final commaIndex = name.indexOf(',');
    if (commaIndex > 0) name = name.substring(0, commaIndex);
    name = name.trim();
    if (name.isEmpty && raw.isNotEmpty) {
      return Ingredient(name: raw, raw: raw);
    }
    return Ingredient(amount: amount, amountMax: amountMax, unit: unit, name: name, raw: raw);
  } catch (_) {
    return Ingredient(name: raw, raw: raw);
  }
}
