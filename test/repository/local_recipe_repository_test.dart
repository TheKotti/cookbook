import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/models/recipe.dart' as model;
import 'package:cookbook/src/repository/local_recipe_repository.dart';
import 'package:cookbook/src/repository/recipe_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

model.Recipe makeRecipe({
  String sourceUrl = 'https://www.chefkoch.de/rezepte/1/test.html',
  String title = 'Käsespätzle',
  List<String> tags = const ['hauptspeise', 'pasta'],
  List<model.Ingredient> ingredients = const [
    model.Ingredient(amount: 500, unit: 'g', name: 'Spätzle', raw: '500 g Spätzle'),
    model.Ingredient(amount: 200, unit: 'g', name: 'Bergkäse', raw: '200 g Bergkäse'),
  ],
}) =>
    model.Recipe(
      sourceUrl: sourceUrl,
      title: title,
      author: 'tester',
      baseServings: 2,
      ingredients: ingredients,
      steps: const ['Kochen.', 'Essen.'],
      tags: tags,
      importedAt: DateTime.utc(2026, 7, 7),
    );

void main() {
  late AppDatabase db;
  late LocalRecipeRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalRecipeRepository(db);
  });

  tearDown(() => db.close());

  test('saveRecipe inserts and getRecipe round-trips all fields', () async {
    final id = await repo.saveRecipe(makeRecipe());
    final loaded = await repo.getRecipe(id);
    expect(loaded, isNotNull);
    expect(loaded!.title, 'Käsespätzle');
    expect(loaded.ingredients, hasLength(2));
    expect(loaded.ingredients.first.name, 'Spätzle');
    expect(loaded.steps, ['Kochen.', 'Essen.']);
    expect(loaded.tags, ['hauptspeise', 'pasta']);
    expect(loaded.baseServings, 2);
    expect(loaded.importedAt, DateTime.utc(2026, 7, 7));
  });

  test('saveRecipe with same sourceUrl overwrites and keeps existing tags by default',
      () async {
    final id1 = await repo.saveRecipe(makeRecipe());
    await repo.setTags(id1, ['meins']);
    final id2 = await repo.saveRecipe(makeRecipe(title: 'Käsespätzle v2', tags: ['neu']));
    expect(id2, id1);
    final loaded = await repo.getRecipe(id1);
    expect(loaded!.title, 'Käsespätzle v2');
    expect(loaded.tags, ['meins']); // user tags survive re-import (§2)
    expect(await repo.getAllRecipes(), hasLength(1));
  });

  test('saveRecipe with TagMode.replace overwrites tags (backup semantics §8)', () async {
    final id = await repo.saveRecipe(makeRecipe());
    await repo.saveRecipe(makeRecipe(tags: ['aus-backup']), tagMode: TagMode.replace);
    final loaded = await repo.getRecipe(id);
    expect(loaded!.tags, ['aus-backup']);
  });

  test('deleteRecipe removes recipe, tags, and search hits', () async {
    final id = await repo.saveRecipe(makeRecipe());
    await repo.deleteRecipe(id);
    expect(await repo.getRecipe(id), isNull);
    expect(await repo.watchRecipes(query: 'spätzle').first, isEmpty);
    expect(await repo.watchAllTags().first, isEmpty);
  });

  group('search (FTS5)', () {
    setUp(() async {
      await repo.saveRecipe(makeRecipe());
      await repo.saveRecipe(makeRecipe(
        sourceUrl: 'https://www.chefkoch.de/rezepte/2/lasagne.html',
        title: 'Lasagne',
        tags: ['nudeln'],
        ingredients: const [
          model.Ingredient(amount: 500, unit: 'g', name: 'Hackfleisch', raw: '500 g Hackfleisch'),
        ],
      ));
    });

    test('matches title with prefix', () async {
      final hits = await repo.watchRecipes(query: 'lasag').first;
      expect(hits.map((r) => r.title), ['Lasagne']);
    });

    test('is umlaut-tolerant (kase matches Käsespätzle)', () async {
      final hits = await repo.watchRecipes(query: 'kase').first;
      expect(hits.map((r) => r.title), ['Käsespätzle']);
    });

    test('matches ingredient names', () async {
      final hits = await repo.watchRecipes(query: 'hackfleisch').first;
      expect(hits.map((r) => r.title), ['Lasagne']);
    });

    test('matches tags and empty query returns everything', () async {
      expect((await repo.watchRecipes(query: 'nudeln').first).map((r) => r.title), ['Lasagne']);
      expect(await repo.watchRecipes().first, hasLength(2));
    });

    test('FTS reflects overwrite', () async {
      await repo.saveRecipe(makeRecipe(title: 'Umbenannt'));
      expect(await repo.watchRecipes(query: 'käsespätzle').first, isEmpty);
      expect(await repo.watchRecipes(query: 'umbenannt').first, hasLength(1));
    });

    test('search input with FTS metacharacters does not throw', () async {
      // Tokens are ANDed by FTS5, so this finds nothing — the assertion is
      // only that hostile input produces a valid (empty) result, not an error.
      expect(await repo.watchRecipes(query: '"AND" (x OR *) NEAR').first, isA<List<model.Recipe>>());
    });
  });

  group('tag filter', () {
    setUp(() async {
      await repo.saveRecipe(makeRecipe()); // tags: hauptspeise, pasta
      await repo.saveRecipe(makeRecipe(
        sourceUrl: 'https://www.chefkoch.de/rezepte/2/salat.html',
        title: 'Salat',
        tags: ['vegetarisch'],
      ));
      await repo.saveRecipe(makeRecipe(
        sourceUrl: 'https://www.chefkoch.de/rezepte/3/auflauf.html',
        title: 'Auflauf',
        tags: ['hauptspeise', 'vegetarisch'],
      ));
    });

    test('single tag filters', () async {
      final hits = await repo.watchRecipes(tags: {'vegetarisch'}).first;
      expect(hits.map((r) => r.title).toSet(), {'Salat', 'Auflauf'});
    });

    test('multiple tags are AND (§8)', () async {
      final hits = await repo.watchRecipes(tags: {'vegetarisch', 'hauptspeise'}).first;
      expect(hits.map((r) => r.title), ['Auflauf']);
    });

    test('tag filter combines with search term', () async {
      final hits = await repo.watchRecipes(query: 'auflauf', tags: {'hauptspeise'}).first;
      expect(hits.map((r) => r.title), ['Auflauf']);
    });

    test('watchAllTags returns sorted distinct tags', () async {
      expect(await repo.watchAllTags().first, ['hauptspeise', 'pasta', 'vegetarisch']);
    });
  });

  test('setTags normalizes to lowercase trimmed dedupe and updates search', () async {
    final id = await repo.saveRecipe(makeRecipe());
    await repo.setTags(id, [' Sommer ', 'sommer', 'GRILL']);
    final loaded = await repo.getRecipe(id);
    expect(loaded!.tags, ['grill', 'sommer']);
    expect(await repo.watchRecipes(query: 'grill').first, hasLength(1));
  });

  test('watchRecipe emits updates after setTags', () async {
    final id = await repo.saveRecipe(makeRecipe());
    expect((await repo.watchRecipe(id).first)!.tags, ['hauptspeise', 'pasta']);
    await repo.setTags(id, ['neu']);
    expect((await repo.watchRecipe(id).first)!.tags, ['neu']);
  });

  test('setRating sets, updates watchers, and clears', () async {
    final id = await repo.saveRecipe(makeRecipe());
    await repo.setRating(id, 4);
    expect((await repo.getRecipe(id))!.rating, 4.0);
    expect((await repo.watchRecipe(id).first)!.rating, 4.0);
    await repo.setRating(id, null);
    expect((await repo.getRecipe(id))!.rating, isNull);
  });

  test('localImagePath round-trips through saveRecipe/getRecipe', () async {
    final id = await repo.saveRecipe(model.Recipe(
      sourceUrl: 'manual:42',
      title: 'Mit Bild',
      author: 'me',
      localImagePath: 'images/1234.jpg',
      ingredients: const [],
      steps: const [],
      tags: const [],
      importedAt: DateTime.utc(2026, 7, 10),
    ));
    expect((await repo.getRecipe(id))!.localImagePath, 'images/1234.jpg');
  });
}
