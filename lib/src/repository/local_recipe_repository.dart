import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/recipe.dart' as model;
import 'recipe_repository.dart';

class LocalRecipeRepository implements RecipeRepository {
  final AppDatabase db;
  LocalRecipeRepository(this.db);

  @override
  Future<int> saveRecipe(model.Recipe recipe, {TagMode tagMode = TagMode.seedIfNew}) {
    return db.transaction(() async {
      final existing = await (db.select(db.recipes)
            ..where((r) => r.sourceUrl.equals(recipe.sourceUrl)))
          .getSingleOrNull();
      final companion = RecipesCompanion(
        sourceUrl: Value(recipe.sourceUrl),
        title: Value(recipe.title),
        author: Value(recipe.author),
        imageUrl: Value(recipe.imageUrl),
        localImagePath: Value(recipe.localImagePath),
        baseServings: Value(recipe.baseServings),
        prepMinutes: Value(recipe.prepMinutes),
        cookMinutes: Value(recipe.cookMinutes),
        totalMinutes: Value(recipe.totalMinutes),
        rating: Value(recipe.rating),
        ingredientsJson: Value(recipe.ingredientsJson),
        stepsJson: Value(recipe.stepsJson),
        importedAt: Value(recipe.importedAt.toIso8601String()),
        schemaVersion: Value(recipe.schemaVersion),
      );

      final int id;
      final List<String> tags;
      if (existing == null) {
        id = await db.into(db.recipes).insert(companion);
        tags = normalizeTags(recipe.tags);
      } else {
        id = existing.id;
        await (db.update(db.recipes)..where((r) => r.id.equals(id))).write(companion);
        tags = tagMode == TagMode.replace ? normalizeTags(recipe.tags) : await _tagsFor(id);
      }
      await _writeTags(id, tags);
      await _writeFtsRow(id, recipe.title, tags, recipe.ingredients);
      return id;
    });
  }

  @override
  Future<void> deleteRecipe(int id) {
    return db.transaction(() async {
      await (db.delete(db.recipes)..where((r) => r.id.equals(id))).go();
      await db.customStatement('DELETE FROM recipe_fts WHERE rowid = ?', [id]);
    });
  }

  @override
  Future<void> setTags(int recipeId, List<String> tags) {
    return db.transaction(() async {
      final row = await (db.select(db.recipes)..where((r) => r.id.equals(recipeId)))
          .getSingleOrNull();
      if (row == null) return;
      final normalized = normalizeTags(tags);
      await _writeTags(recipeId, normalized);
      await _writeFtsRow(recipeId, row.title, normalized,
          model.Recipe.decodeIngredients(row.ingredientsJson));
      // Touch the recipe row so table watchers re-emit.
      await (db.update(db.recipes)..where((r) => r.id.equals(recipeId)))
          .write(RecipesCompanion(title: Value(row.title)));
    });
  }

  @override
  Future<model.Recipe?> getRecipe(int id) async {
    final row =
        await (db.select(db.recipes)..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _toModel(row, await _tagsFor(id));
  }

  @override
  Stream<model.Recipe?> watchRecipe(int id) {
    final stream = (db.select(db.recipes)..where((r) => r.id.equals(id))).watchSingleOrNull();
    return stream.asyncMap((row) async => row == null ? null : _toModel(row, await _tagsFor(id)));
  }

  @override
  Future<List<model.Recipe>> getAllRecipes() async {
    final rows = await (db.select(db.recipes)
          ..orderBy([(r) => OrderingTerm.desc(r.importedAt)]))
        .get();
    return _withTags(rows);
  }

  @override
  Stream<List<model.Recipe>> watchRecipes({String query = '', Set<String> tags = const {}}) {
    final match = _ftsMatchQuery(query);
    final variables = <Variable>[];
    var sql = 'SELECT r.* FROM recipes r';
    if (match != null) {
      sql += ' JOIN (SELECT rowid AS rid, rank FROM recipe_fts WHERE recipe_fts MATCH ?) f'
          ' ON f.rid = r.id';
      variables.add(Variable.withString(match));
    }
    if (tags.isNotEmpty) {
      final placeholders = List.filled(tags.length, '?').join(', ');
      sql += ' WHERE r.id IN (SELECT recipe_id FROM recipe_tags WHERE tag IN ($placeholders)'
          ' GROUP BY recipe_id HAVING COUNT(DISTINCT tag) = ${tags.length})';
      variables.addAll(tags.map(Variable.withString));
    }
    sql += match != null ? ' ORDER BY f.rank' : ' ORDER BY r.imported_at DESC';

    return db
        .customSelect(sql, variables: variables, readsFrom: {db.recipes, db.recipeTags})
        .watch()
        .asyncMap((rows) =>
            _withTags([for (final row in rows) db.recipes.map(row.data)]));
  }

  @override
  Stream<List<String>> watchAllTags() {
    return db
        .customSelect('SELECT DISTINCT tag FROM recipe_tags ORDER BY tag',
            readsFrom: {db.recipeTags})
        .watch()
        .map((rows) => rows.map((r) => r.read<String>('tag')).toList());
  }

  Future<List<String>> _tagsFor(int recipeId) async {
    final rows = await (db.select(db.recipeTags)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.asc(t.tag)]))
        .get();
    return rows.map((r) => r.tag).toList();
  }

  Future<void> _writeTags(int recipeId, List<String> tags) async {
    await (db.delete(db.recipeTags)..where((t) => t.recipeId.equals(recipeId))).go();
    for (final tag in tags) {
      await db
          .into(db.recipeTags)
          .insert(RecipeTagsCompanion.insert(recipeId: recipeId, tag: tag));
    }
  }

  Future<void> _writeFtsRow(
      int id, String title, List<String> tags, List<model.Ingredient> ingredients) async {
    await db.customStatement('DELETE FROM recipe_fts WHERE rowid = ?', [id]);
    await db.customStatement(
      'INSERT INTO recipe_fts(rowid, title, tags, ingredients) VALUES (?, ?, ?, ?)',
      [id, title, tags.join(' '), ingredients.map((i) => i.name).join(' ')],
    );
  }

  Future<List<model.Recipe>> _withTags(List<Recipe> rows) async {
    if (rows.isEmpty) return [];
    final tagRows = await db.select(db.recipeTags).get();
    final byRecipe = <int, List<String>>{};
    for (final row in tagRows) {
      byRecipe.putIfAbsent(row.recipeId, () => []).add(row.tag);
    }
    return [
      for (final row in rows) _toModel(row, (byRecipe[row.id] ?? [])..sort()),
    ];
  }

  model.Recipe _toModel(Recipe row, List<String> tags) => model.Recipe(
        id: row.id,
        sourceUrl: row.sourceUrl,
        title: row.title,
        author: row.author,
        imageUrl: row.imageUrl,
        localImagePath: row.localImagePath,
        baseServings: row.baseServings,
        prepMinutes: row.prepMinutes,
        cookMinutes: row.cookMinutes,
        totalMinutes: row.totalMinutes,
        rating: row.rating,
        ingredients: model.Recipe.decodeIngredients(row.ingredientsJson),
        steps: model.Recipe.decodeSteps(row.stepsJson),
        tags: tags,
        importedAt: DateTime.parse(row.importedAt),
        schemaVersion: row.schemaVersion,
      );

  /// Turns free text into an FTS5 MATCH expression with per-token prefix
  /// matching; strips metacharacters by tokenizing on non-letter/digit.
  String? _ftsMatchQuery(String input) {
    final tokens = input
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    return tokens.map((t) => '"$t"*').join(' ');
  }
}
