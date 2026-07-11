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

  test('Ingredient.section builds a header that JSON round-trips', () {
    final header = Ingredient.section('Sauce');
    expect(header.isSection, isTrue);
    expect(header.name, 'Sauce');
    expect(header.raw, '# Sauce');
    expect(Ingredient.fromJson(header.toJson()), header);
    expect(header.toJson()['is_section'], isTrue);
  });

  test('non-section ingredients omit is_section and default to false', () {
    expect(ingredient.isSection, isFalse);
    expect(ingredient.toJson().containsKey('is_section'), isFalse);
    // Pre-v1.3 payloads have no is_section key and decode as normal items.
    final legacy = Ingredient.fromJson({'name': 'Salz', 'raw': 'Salz'});
    expect(legacy.isSection, isFalse);
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
