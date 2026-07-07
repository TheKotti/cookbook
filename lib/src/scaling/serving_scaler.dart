import '../models/recipe.dart';

/// Display-only serving scaling (§7). Never mutates stored data.
class ServingScaler {
  /// Bare counts and pieces get half-step rounding (§7: "2,66 → 2 ½,
  /// never 2,66 Ei(er)").
  static bool isCountable(Ingredient ing) => ing.unit == null || ing.unit == 'Stück';

  static String formatNumber(double value, {required bool countable}) {
    if (countable) {
      final halves = (value * 2).round();
      if (halves == 0) return value > 0 ? '½' : '0';
      final whole = halves ~/ 2;
      if (halves.isEven) return '$whole';
      return whole == 0 ? '½' : '$whole ½';
    }
    if (value >= 10) return value.round().toString();
    final decimals = value >= 1 ? 1 : 2;
    var text = value.toStringAsFixed(decimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text.replaceAll('.', ',');
  }

  /// One display line per ingredient. Original `raw` text is shown when there
  /// is nothing to scale (null amount) or nothing scaled (factor 1).
  static String scaledLine(Ingredient ing, double factor) {
    final amount = ing.amount;
    if (amount == null || factor == 1.0) return ing.raw;
    final countable = isCountable(ing);
    final low = formatNumber(amount * factor, countable: countable);
    final high = ing.amountMax == null
        ? ''
        : '–${formatNumber(ing.amountMax! * factor, countable: countable)}';
    final unit = ing.unit == null ? '' : ' ${ing.unit}';
    return '$low$high$unit ${ing.name}';
  }
}
