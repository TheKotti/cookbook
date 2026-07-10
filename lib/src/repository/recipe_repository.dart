import '../models/recipe.dart';

/// How [RecipeRepository.saveRecipe] treats tags when the recipe already
/// exists (matched by sourceUrl).
enum TagMode {
  /// URL re-import: keep the user's existing tags; recipe.tags only seed a
  /// brand-new recipe (§2 — tags are the user's only editable field).
  seedIfNew,

  /// Backup import: tags in the payload replace local tags (§8).
  replace,
}

/// The single seam between UI/services and storage (§4). A future
/// SyncedRecipeRepository plugs in here (§12).
abstract class RecipeRepository {
  Stream<List<Recipe>> watchRecipes({String query = '', Set<String> tags = const {}});
  Stream<Recipe?> watchRecipe(int id);
  Future<Recipe?> getRecipe(int id);
  Future<List<Recipe>> getAllRecipes();

  /// Upserts by [Recipe.sourceUrl] (§2 re-import = overwrite). Returns the row id.
  Future<int> saveRecipe(Recipe recipe, {TagMode tagMode = TagMode.seedIfNew});

  Future<void> deleteRecipe(int id);
  Future<void> setTags(int recipeId, List<String> tags);

  /// v1.1: the user's own 1-5 star rating; null clears it. Ratings are no
  /// longer imported (spec §2).
  Future<void> setRating(int recipeId, double? rating);
  Stream<List<String>> watchAllTags();
}

List<String> normalizeTags(Iterable<String> tags) {
  final seen = <String>{};
  final result = [
    for (final tag in tags)
      if (tag.trim().isNotEmpty && seen.add(tag.trim().toLowerCase()))
        tag.trim().toLowerCase()
  ];
  result.sort();
  return result;
}
