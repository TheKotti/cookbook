import 'dart:io';

import 'package:cookbook/src/models/recipe.dart';
import 'package:cookbook/src/parser/recipe_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('real Chefkoch page: Ofenkartoffeln', () {
    late Recipe recipe;
    setUpAll(() {
      recipe = RecipeParser.parse(fixture('ofenkartoffeln.html'),
          sourceUrl:
              'https://www.chefkoch.de/rezepte/1064631211795001/Knusprige-Ofenkartoffeln.html');
    });

    test('maps scalar fields from the verified JSON-LD', () {
      expect(recipe.title, 'Knusprige Ofenkartoffeln von mareikaeferchen');
      expect(recipe.author, 'mareikaeferchen');
      expect(recipe.baseServings, 3);
      expect(recipe.prepMinutes, 20);
      expect(recipe.cookMinutes, 40);
      expect(recipe.totalMinutes, 60);
      expect(recipe.rating, 4.8);
      expect(recipe.imageUrl, startsWith('https://img.chefkoch-cdn.de/'));
      expect(recipe.sourceUrl, contains('1064631211795001'));
      expect(recipe.schemaVersion, kCurrentSchemaVersion);
    });

    test('parses all 12 ingredients, never dropping any', () {
      expect(recipe.ingredients, hasLength(12));
      final oil = recipe.ingredients[1];
      expect(oil.amount, 3);
      expect(oil.unit, 'EL');
      expect(oil.name, 'Olivenöl');
      final chili = recipe.ingredients.firstWhere((i) => i.raw.contains('Chilipulver'));
      expect(chili.amount, isNull);
    });

    test('flattens the real HowToSection instructions shape', () {
      expect(recipe.steps, isNotEmpty);
      expect(recipe.steps.first, startsWith('Die geschälten, geviertelten Kartoffeln'));
    });

    test('seeds lowercase tags from comma-separated keywords, ignoring recipeCategory', () {
      expect(recipe.tags, contains('backen'));
      expect(recipe.tags, contains('kartoffel'));
      expect(recipe.tags, contains('raffiniert oder preiswert'));
      expect(recipe.tags, isNot(contains('Vegetarisch')));
      expect(recipe.tags, isNot(contains('vegetarisch')));
    });
  });

  group('real Chefkoch page: Lasagne', () {
    late Recipe recipe;
    setUpAll(() {
      recipe = RecipeParser.parse(fixture('lasagne.html'),
          sourceUrl: 'https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html');
    });

    test('maps fields', () {
      expect(recipe.title, 'Lasagne - wie beim Italiener');
      expect(recipe.baseServings, 4);
      expect(recipe.prepMinutes, 30);
      expect(recipe.cookMinutes, 70);
      expect(recipe.totalMinutes, 100);
      expect(recipe.rating, 4.7);
      expect(recipe.ingredients, hasLength(19));
      expect(recipe.steps.length, greaterThan(1));
    });

    test('handles dot-decimal ingredient from real data', () {
      final milk = recipe.ingredients.firstWhere((i) => i.raw == '0.5 Liter Milch');
      expect(milk.amount, 0.5);
      expect(milk.unit, 'Liter');
      expect(milk.name, 'Milch');
    });
  });

  group('synthetic variants', () {
    late Recipe recipe;
    setUpAll(() {
      recipe = RecipeParser.parse(fixture('synthetic_variants.html'),
          sourceUrl: 'https://www.chefkoch.de/rezepte/1/synthetic.html');
    });

    test('finds Recipe inside @graph with list @type, skipping non-recipe and malformed blocks',
        () {
      expect(recipe.title, 'Synthetisches Testrezept');
    });

    test('stores deleted author as-is', () {
      expect(recipe.author, 'Gelöschter Benutzer');
    });

    test('unparseable yield gives null baseServings (scaler hidden)', () {
      expect(recipe.baseServings, isNull);
    });

    test('parses PT-style durations and missing cookTime', () {
      expect(recipe.prepMinutes, 15);
      expect(recipe.cookMinutes, isNull);
      expect(recipe.totalMinutes, 45);
    });

    test('image from ImageObject and rating from string', () {
      expect(recipe.imageUrl, 'https://img.chefkoch-cdn.de/synthetic.jpg');
      expect(recipe.rating, 3.5);
    });

    test('keywords list is lowercased and deduped', () {
      expect(recipe.tags, ['einfach', 'pasta']);
    });

    test('string instructions split on newlines', () {
      expect(recipe.steps, ['Butter schmelzen.', 'Salzen.', 'Servieren.']);
    });
  });

  test('page without recipe JSON-LD throws NO_RECIPE_FOUND', () {
    expect(
      () => RecipeParser.parse(fixture('block_page.html'),
          sourceUrl: 'https://www.chefkoch.de/x'),
      throwsA(isA<RecipeParseException>().having((e) => e.code, 'code', 'NO_RECIPE_FOUND')),
    );
  });
}
