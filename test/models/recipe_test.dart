import 'package:cookbook/src/models/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ingredient = Ingredient(
      amount: 2, amountMax: 3, unit: 'Zehe', name: 'Knoblauch', raw: '2-3 Zehen Knoblauch');

  test('Ingredient JSON round-trip preserves all fields', () {
    final restored = Ingredient.fromJson(ingredient.toJson());
    expect(restored, ingredient);
    expect(restored.toJson(), {
      'amount': 2.0,
      'amount_max': 3.0,
      'unit': 'Zehe',
      'name': 'Knoblauch',
      'raw': '2-3 Zehen Knoblauch',
    });
  });

  test('Ingredient fromJson tolerates nulls', () {
    final salt = Ingredient.fromJson(
        {'amount': null, 'amount_max': null, 'unit': null, 'name': 'Salz', 'raw': ' Salz'});
    expect(salt.amount, isNull);
    expect(salt.unit, isNull);
    expect(salt.name, 'Salz');
  });

  test('Recipe encodes and decodes ingredients and steps as JSON strings', () {
    final recipe = Recipe(
      sourceUrl: 'https://www.chefkoch.de/rezepte/1/x.html',
      title: 'Test',
      author: 'someone',
      ingredients: const [ingredient],
      steps: const ['Step one.', 'Step two.'],
      tags: const ['pasta'],
      importedAt: DateTime.utc(2026, 7, 7),
    );
    expect(Recipe.decodeIngredients(recipe.ingredientsJson), [ingredient]);
    expect(Recipe.decodeSteps(recipe.stepsJson), ['Step one.', 'Step two.']);
    expect(recipe.schemaVersion, kCurrentSchemaVersion);
    expect(recipe.copyWith(id: 5).id, 5);
    expect(recipe.copyWith(id: 5).title, 'Test');
  });
}
