import 'package:cookbook/src/manual/manual_recipe.dart';
import 'package:cookbook/src/models/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildManualRecipe (create)', () {
    Recipe create() => buildManualRecipe(
      title: '  Pancakes ',
      author: ' Oma ',
      servings: 4,
      prepMinutes: 10,
      cookMinutes: 20,
      ingredientsText: '200 g Mehl\n\n  2 Eier  \n',
      stepsText: 'Mix everything.\n\nBake.\n',
      localImagePath: null,
      now: DateTime.utc(2026, 7, 7),
    );

    test('trims title/author and splits non-empty lines', () {
      final r = create();
      expect(r.title, 'Pancakes');
      expect(r.author, 'Oma');
      expect(r.steps, ['Mix everything.', 'Bake.']);
      expect(r.ingredients, hasLength(2));
    });

    test('runs ingredient lines through parseIngredient', () {
      final r = create();
      expect(r.ingredients[0].amount, 200);
      expect(r.ingredients[0].unit, 'g');
      expect(r.ingredients[0].name, 'Mehl');
      expect(r.ingredients[0].raw, '200 g Mehl');
      expect(r.ingredients[1].amount, 2);
      expect(r.ingredients[1].name, 'Eier');
    });

    test('sets synthetic manual sourceUrl and importedAt from now', () {
      final r = create();
      expect(
        r.sourceUrl,
        'manual:${DateTime.utc(2026, 7, 7).microsecondsSinceEpoch}',
      );
      expect(r.isManual, isTrue);
      expect(r.importedAt, DateTime.utc(2026, 7, 7));
      expect(r.id, isNull);
      expect(r.tags, isEmpty);
      expect(r.imageUrl, isNull);
      expect(r.rating, isNull);
    });

    test('totalMinutes is prep + cook, or the present one, or null', () {
      expect(create().totalMinutes, 30);
      final onlyPrep = buildManualRecipe(
        title: 't',
        author: '',
        prepMinutes: 15,
        ingredientsText: 'x',
        stepsText: 'y',
        localImagePath: null,
      );
      expect(onlyPrep.totalMinutes, 15);
      final neither = buildManualRecipe(
        title: 't',
        author: '',
        ingredientsText: 'x',
        stepsText: 'y',
        localImagePath: null,
      );
      expect(neither.totalMinutes, isNull);
    });
  });

  group('buildManualRecipe (# sections)', () {
    Recipe build(String ingredientsText) => buildManualRecipe(
      title: 'T',
      author: '',
      ingredientsText: ingredientsText,
      stepsText: 'Cook.',
      localImagePath: null,
      now: DateTime.utc(2026, 7, 11),
    );

    test('# lines become section headers, other lines stay ingredients', () {
      final r = build('# Klopse\n500 g Hackfleisch\n2 Eier\n# Sauce\n40 g Butter');
      expect(
        [for (final i in r.ingredients) (i.name, i.isSection)],
        [
          ('Klopse', true),
          ('Hackfleisch', false),
          ('Eier', false),
          ('Sauce', true),
          ('Butter', false),
        ],
      );
      // Header round-trips back to a `# ` line for the edit form.
      expect(r.ingredients.first.raw, '# Klopse');
    });

    test('extra # and missing space are normalized', () {
      final r = build('##  Sauce \n1 EL Öl');
      expect(r.ingredients.first.isSection, isTrue);
      expect(r.ingredients.first.name, 'Sauce');
      expect(r.ingredients.first.raw, '# Sauce');
    });

    test('a bare # with no heading text is dropped', () {
      final r = build('#\n1 EL Öl');
      expect(r.ingredients, hasLength(1));
      expect(r.ingredients.single.isSection, isFalse);
    });

    test('ingredients before the first # stay as an unlabeled group', () {
      final r = build('1 Ei\n# Sauce\n40 g Butter');
      expect(r.ingredients.first.isSection, isFalse);
      expect(r.ingredients.first.name, 'Ei');
      expect(r.ingredients[1].isSection, isTrue);
    });
  });

  group('buildManualRecipe (edit)', () {
    final existing = Recipe(
      id: 7,
      sourceUrl: 'https://www.chefkoch.de/rezepte/1/a.html',
      title: 'Old',
      author: 'Old author',
      imageUrl: 'https://img.example/x.jpg',
      rating: 4.5,
      ingredients: const [Ingredient(name: 'Salz', raw: 'Salz')],
      steps: const ['Old step'],
      tags: const ['pasta'],
      importedAt: DateTime.utc(2026, 1, 1),
    );

    test('preserves id, sourceUrl, imageUrl, rating, tags, importedAt', () {
      final r = buildManualRecipe(
        existing: existing,
        title: 'New title',
        author: 'New author',
        ingredientsText: '1 EL Zucker',
        stepsText: 'New step',
        localImagePath: null,
      );
      expect(r.id, 7);
      expect(r.sourceUrl, existing.sourceUrl);
      expect(r.isManual, isFalse);
      expect(r.imageUrl, existing.imageUrl);
      expect(r.rating, 4.5);
      expect(r.tags, ['pasta']);
      expect(r.importedAt, DateTime.utc(2026, 1, 1));
      expect(r.title, 'New title');
      expect(r.steps, ['New step']);
      expect(r.ingredients.single.unit, 'EL');
    });

    test('preserves totalMinutes when prep/cook are unchanged', () {
      final imported = Recipe(
        id: 8,
        sourceUrl: 'https://www.chefkoch.de/rezepte/2/b.html',
        title: 'Braised',
        author: 'a',
        prepMinutes: 20,
        cookMinutes: 60,
        totalMinutes: 140, // includes 60 min resting time
        ingredients: const [Ingredient(name: 'Fleisch', raw: 'Fleisch')],
        steps: const ['Cook'],
        tags: const [],
        importedAt: DateTime.utc(2026, 1, 1),
      );
      final r = buildManualRecipe(
        existing: imported,
        title: 'Braised (edited)',
        author: 'a',
        prepMinutes: 20,
        cookMinutes: 60,
        ingredientsText: 'Fleisch',
        stepsText: 'Cook',
        localImagePath: null,
      );
      expect(r.totalMinutes, 140);
    });

    test('recomputes totalMinutes when prep or cook changed', () {
      final imported = Recipe(
        id: 9,
        sourceUrl: 'https://www.chefkoch.de/rezepte/3/c.html',
        title: 'Braised',
        author: 'a',
        prepMinutes: 20,
        cookMinutes: 60,
        totalMinutes: 140,
        ingredients: const [Ingredient(name: 'Fleisch', raw: 'Fleisch')],
        steps: const ['Cook'],
        tags: const [],
        importedAt: DateTime.utc(2026, 1, 1),
      );
      final r = buildManualRecipe(
        existing: imported,
        title: 'Braised',
        author: 'a',
        prepMinutes: 30,
        cookMinutes: 60,
        ingredientsText: 'Fleisch',
        stepsText: 'Cook',
        localImagePath: null,
      );
      expect(r.totalMinutes, 90);
    });
  });

  test('localImagePath flows through and can be cleared', () {
    final withImage = buildManualRecipe(
      title: 'T',
      author: '',
      ingredientsText: 'Salz',
      stepsText: 'Mix.',
      localImagePath: 'images/1.jpg',
    );
    expect(withImage.localImagePath, 'images/1.jpg');

    final cleared = buildManualRecipe(
      existing: withImage,
      title: 'T',
      author: '',
      ingredientsText: 'Salz',
      stepsText: 'Mix.',
      localImagePath: null,
    );
    expect(cleared.localImagePath, isNull);
    expect(cleared.sourceUrl, withImage.sourceUrl);
  });

  test('isManual is false for chefkoch URLs', () {
    final r = Recipe(
      sourceUrl: 'https://www.chefkoch.de/rezepte/1/a.html',
      title: 't',
      author: '',
      ingredients: const [],
      steps: const [],
      tags: const [],
      importedAt: DateTime.utc(2026, 7, 7),
    );
    expect(r.isManual, isFalse);
  });
}
