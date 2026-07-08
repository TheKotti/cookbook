import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/models/recipe.dart' as model;
import 'package:cookbook/src/providers.dart';
import 'package:cookbook/src/ui/recipe_detail_screen.dart';
import 'package:cookbook/src/ui/recipe_form_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> flushTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<ProviderContainer> pumpForm(
    WidgetTester tester, {
    model.Recipe? existing,
  }) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: RecipeFormScreen(existing: existing)),
      ),
    );
    await settle(tester);
    return container;
  }

  Future<void> enterField(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  testWidgets('blocks save and shows errors when required fields are empty', (
    tester,
  ) async {
    final container = await pumpForm(tester);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Add at least one ingredient'), findsOneWidget);
    expect(find.text('Add at least one step'), findsOneWidget);
    final saved = await container
        .read(recipeRepositoryProvider)
        .getAllRecipes();
    expect(saved, isEmpty);
    await flushTeardown(tester);
  });

  testWidgets('rejects non-positive servings', (tester) async {
    await pumpForm(tester);
    await enterField(tester, 'Servings', '0');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Enter a whole number of 1 or more'), findsOneWidget);
    await flushTeardown(tester);
  });

  testWidgets('create saves a manual recipe and opens its detail screen', (
    tester,
  ) async {
    final container = await pumpForm(tester);
    await enterField(tester, 'Title', 'Pancakes');
    await enterField(tester, 'Servings', '4');
    await enterField(tester, 'Prep time (min)', '10');
    await enterField(tester, 'Cook time (min)', '20');
    await enterField(
      tester,
      'Ingredients (one per line)',
      '200 g Mehl\n2 Eier',
    );
    await enterField(tester, 'Steps (one per line)', 'Mix.\nBake.');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    final saved =
        (await container.read(recipeRepositoryProvider).getAllRecipes()).single;
    expect(saved.title, 'Pancakes');
    expect(saved.isManual, isTrue);
    expect(saved.baseServings, 4);
    expect(saved.totalMinutes, 30);
    expect(saved.ingredients.first.unit, 'g');
    expect(saved.steps, ['Mix.', 'Bake.']);
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    await flushTeardown(tester);
  });

  testWidgets('edit pre-fills fields and preserves identity and tags', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(recipeRepositoryProvider);
    final original = model.Recipe(
      sourceUrl: 'manual:123',
      title: 'Old title',
      author: 'Oma',
      baseServings: 2,
      ingredients: const [model.Ingredient(name: 'Salz', raw: 'Salz')],
      steps: const ['Old step'],
      tags: const ['pasta'],
      importedAt: DateTime.utc(2026, 1, 1),
    );
    final id = await repo.saveRecipe(original);
    final existing = (await repo.getRecipe(id))!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: RecipeFormScreen(existing: existing)),
      ),
    );
    await settle(tester);

    expect(find.text('Edit recipe'), findsOneWidget);
    expect(find.text('Old title'), findsOneWidget);
    expect(find.text('Salz'), findsOneWidget);
    expect(find.text('Old step'), findsOneWidget);

    await enterField(tester, 'Title', 'New title');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);

    final saved = (await repo.getAllRecipes()).single;
    expect(saved.id, id);
    expect(saved.sourceUrl, 'manual:123');
    expect(saved.title, 'New title');
    expect(saved.tags, ['pasta']);
    expect(saved.importedAt, DateTime.utc(2026, 1, 1));
    // Edit pops rather than pushing a detail screen.
    expect(find.byType(RecipeDetailScreen), findsNothing);
    await flushTeardown(tester);
  });
}
