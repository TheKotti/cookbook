import 'dart:convert';

import 'package:cookbook/src/backup/backup_service.dart';
import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/models/recipe.dart' as model;
import 'package:cookbook/src/repository/local_recipe_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

model.Recipe makeRecipe(String url, String title, {List<String> tags = const ['pasta']}) =>
    model.Recipe(
      sourceUrl: url,
      title: title,
      author: 'tester',
      imageUrl: 'https://img.chefkoch-cdn.de/x.jpg',
      localImagePath: 'images/backup.jpg',
      baseServings: 2,
      prepMinutes: 15,
      rating: 4.5,
      ingredients: const [
        model.Ingredient(amount: 500, unit: 'g', name: 'Spaghetti', raw: '500 g Spaghetti'),
      ],
      steps: const ['Kochen.'],
      tags: tags,
      importedAt: DateTime.utc(2026, 7, 7, 9),
    );

void main() {
  late AppDatabase db;
  late LocalRecipeRepository repo;
  late BackupService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalRecipeRepository(db);
    service = BackupService(repo);
  });

  tearDown(() => db.close());

  test('export produces the §8 format without local ids', () async {
    await repo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/1/a.html', 'A'));
    final json = jsonDecode(await service.exportJson(now: () => DateTime.utc(2026, 7, 7, 10)))
        as Map<String, dynamic>;
    expect(json['app'], 'cookbook');
    expect(json['format_version'], 1);
    expect(json['exported_at'], '2026-07-07T10:00:00.000Z');
    final recipes = json['recipes'] as List;
    expect(recipes, hasLength(1));
    final r = recipes.first as Map<String, dynamic>;
    expect(r['source_url'], 'https://www.chefkoch.de/rezepte/1/a.html');
    expect(r['title'], 'A');
    expect(r['local_image_path'], 'images/backup.jpg');
    expect(r['base_servings'], 2);
    expect(r['prep_minutes'], 15);
    expect(r['cook_minutes'], isNull);
    expect(r['rating'], 4.5);
    expect(r['schema_version'], 1);
    expect(r['imported_at'], '2026-07-07T09:00:00.000Z');
    expect(r['tags'], ['pasta']);
    expect((r['ingredients'] as List).first, {
      'amount': 500.0,
      'amount_max': null,
      'unit': 'g',
      'name': 'Spaghetti',
      'raw': '500 g Spaghetti'
    });
    expect(r['steps'], ['Kochen.']);
    expect(r.containsKey('id'), isFalse);
  });

  test('import merges by source_url: adds new, overwrites existing incl. tags, keeps local-only',
      () async {
    await repo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/1/a.html', 'A lokal'));
    await repo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/2/b.html', 'B lokal'));

    final otherDb = AppDatabase(NativeDatabase.memory());
    final otherRepo = LocalRecipeRepository(otherDb);
    await otherRepo.saveRecipe(
        makeRecipe('https://www.chefkoch.de/rezepte/1/a.html', 'A aus Backup', tags: ['backup']));
    await otherRepo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/3/c.html', 'C neu'));
    final exported = await BackupService(otherRepo).exportJson();
    await otherDb.close();

    final result = await service.importJson(exported);
    expect(result.added, 1);
    expect(result.updated, 1);

    final all = await repo.getAllRecipes();
    expect(all.map((r) => r.title).toSet(), {'A aus Backup', 'B lokal', 'C neu'});
    final a = all.firstWhere((r) => r.sourceUrl.endsWith('/1/a.html'));
    expect(a.tags, ['backup']); // backup import replaces tags (§8)
  });

  test('round-trip export → import is lossless', () async {
    await repo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/1/a.html', 'A'));
    final exported = await service.exportJson();
    final db2 = AppDatabase(NativeDatabase.memory());
    final repo2 = LocalRecipeRepository(db2);
    await BackupService(repo2).importJson(exported);
    final restored = (await repo2.getAllRecipes()).single;
    final original = (await repo.getAllRecipes()).single;
    expect(restored.title, original.title);
    expect(restored.ingredients, original.ingredients);
    expect(restored.steps, original.steps);
    expect(restored.tags, original.tags);
    expect(restored.importedAt, original.importedAt);
    expect(restored.localImagePath, original.localImagePath);
    await db2.close();
  });

  test('v1 backup without local_image_path imports fine', () async {
    final v1 = jsonEncode({
      'app': 'cookbook',
      'format_version': 1,
      'exported_at': '2026-07-10T00:00:00.000Z',
      'recipes': [
        {
          'source_url': 'https://www.chefkoch.de/rezepte/9/v1.html',
          'title': 'Alt',
          'ingredients': [],
          'steps': [],
          'tags': [],
        }
      ]
    });
    final result = await service.importJson(v1);
    expect(result.added, 1);
    expect((await repo.getAllRecipes()).single.localImagePath, isNull);
  });

  test('unknown format_version is rejected without partial import (§8)', () async {
    final bad = jsonEncode({
      'app': 'cookbook',
      'format_version': 99,
      'recipes': [
        {'source_url': 'x', 'title': 'x'}
      ]
    });
    expect(() => service.importJson(bad), throwsA(isA<BackupException>()));
    expect(await repo.getAllRecipes(), isEmpty);
  });

  test('garbage input is rejected with BackupException', () async {
    expect(() => service.importJson('not json'), throwsA(isA<BackupException>()));
    expect(() => service.importJson('{"foo": 1}'), throwsA(isA<BackupException>()));
  });
}
