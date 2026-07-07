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
  DateTime? now,
}) {
  return Recipe(
    id: existing?.id,
    sourceUrl: existing?.sourceUrl ?? newManualSourceUrl(now: now),
    title: title.trim(),
    author: author.trim(),
    imageUrl: existing?.imageUrl,
    baseServings: servings,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    totalMinutes: prepMinutes == null && cookMinutes == null
        ? null
        : (prepMinutes ?? 0) + (cookMinutes ?? 0),
    rating: existing?.rating,
    ingredients: [
      for (final line in _nonEmptyLines(ingredientsText)) parseIngredient(line)
    ],
    steps: _nonEmptyLines(stepsText),
    tags: existing?.tags ?? const [],
    importedAt: existing?.importedAt ?? (now ?? DateTime.now()),
  );
}
