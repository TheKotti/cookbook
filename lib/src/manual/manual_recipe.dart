import '../models/recipe.dart';
import '../parser/ingredient_parser.dart';

String newManualSourceUrl({DateTime? now}) =>
    'manual:${(now ?? DateTime.now()).microsecondsSinceEpoch}';

List<String> _nonEmptyLines(String text) =>
    text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

/// Builds the [Recipe] to save from the manual form's raw inputs. With
/// [existing] set (edit mode), the fields the form doesn't own — id,
/// sourceUrl, imageUrl, rating, tags, importedAt — are preserved; otherwise
/// a fresh manual recipe is created.
Recipe buildManualRecipe({
  Recipe? existing,
  required String title,
  required String author,
  int? servings,
  int? prepMinutes,
  int? cookMinutes,
  required String ingredientsText,
  required String stepsText,

  /// The form owns this field (v1.1 photos): pass the current form state,
  /// which starts as `existing?.localImagePath` in edit mode.
  required String? localImagePath,
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  // Recomputing total from prep + cook would corrupt imported recipes whose
  // total includes resting time — preserve it while prep/cook are untouched.
  final timesUnchanged =
      existing != null &&
      prepMinutes == existing.prepMinutes &&
      cookMinutes == existing.cookMinutes;
  final totalMinutes = timesUnchanged
      ? existing.totalMinutes
      : prepMinutes == null && cookMinutes == null
      ? null
      : (prepMinutes ?? 0) + (cookMinutes ?? 0);
  return Recipe(
    id: existing?.id,
    sourceUrl: existing?.sourceUrl ?? newManualSourceUrl(now: effectiveNow),
    title: title.trim(),
    author: author.trim(),
    imageUrl: existing?.imageUrl,
    localImagePath: localImagePath,
    baseServings: servings,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    totalMinutes: totalMinutes,
    rating: existing?.rating,
    ingredients: [
      for (final line in _nonEmptyLines(ingredientsText)) parseIngredient(line),
    ],
    steps: _nonEmptyLines(stepsText),
    tags: existing?.tags ?? const [],
    importedAt: existing?.importedAt ?? effectiveNow,
  );
}
