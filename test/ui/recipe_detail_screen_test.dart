import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/models/recipe.dart' as model;
import 'package:cookbook/src/providers.dart';
import 'package:cookbook/src/ui/recipe_detail_screen.dart';
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

  Future<int> save(ProviderContainer container, String sourceUrl) {
    return container
        .read(recipeRepositoryProvider)
        .saveRecipe(
          model.Recipe(
            sourceUrl: sourceUrl,
            title: 'Pancakes',
            author: 'Oma',
            ingredients: const [
              model.Ingredient(name: 'Mehl', raw: '200 g Mehl'),
            ],
            steps: const ['Mix.'],
            tags: const [],
            importedAt: DateTime.utc(2026, 7, 7),
          ),
        );
  }

  Future<ProviderContainer> pumpDetail(
    WidgetTester tester,
    String sourceUrl,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final id = await save(container, sourceUrl);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: RecipeDetailScreen(recipeId: id)),
      ),
    );
    await settle(tester);
    return container;
  }

  testWidgets('manual recipe shows plain author line without chefkoch link', (
    tester,
  ) async {
    await pumpDetail(tester, 'manual:123');
    expect(find.text('By Oma'), findsOneWidget);
    expect(find.textContaining('chefkoch.de'), findsNothing);
    await flushTeardown(tester);
  });

  testWidgets('imported recipe shows plain author line with no chefkoch link', (
    tester,
  ) async {
    await pumpDetail(tester, 'https://www.chefkoch.de/rezepte/1/a.html');
    expect(find.text('By Oma'), findsOneWidget);
    expect(find.textContaining('chefkoch.de'), findsNothing);
    await flushTeardown(tester);
  });

  testWidgets('tapping a star persists the rating; tapping it again clears', (
    tester,
  ) async {
    final container = await pumpDetail(tester, 'manual:123');
    final repo = container.read(recipeRepositoryProvider);

    expect(find.byIcon(Icons.star_border), findsNWidgets(5));

    await tester.tap(find.byIcon(Icons.star_border).at(3)); // 4th star
    await settle(tester);
    final id = (await repo.getAllRecipes()).single.id!;
    expect((await repo.getRecipe(id))!.rating, 4.0);
    expect(find.byIcon(Icons.star), findsNWidgets(4));
    expect(find.byIcon(Icons.star_border), findsNWidgets(1));

    await tester.tap(find.byIcon(Icons.star).at(3)); // tap current value → clear
    await settle(tester);
    expect((await repo.getRecipe(id))!.rating, isNull);
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    await flushTeardown(tester);
  });

  // Single-ingredient recipe (200 g Mehl @ 2 servings) for the cart tests, so
  // find.byIcon matches exactly one cart button.
  Future<ProviderContainer> pumpCartRecipe(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final id = await container.read(recipeRepositoryProvider).saveRecipe(
          model.Recipe(
            sourceUrl: 'manual:9',
            title: 'Nudeln',
            author: 'me',
            baseServings: 2,
            ingredients: const [
              model.Ingredient(
                  amount: 200, unit: 'g', name: 'Mehl', raw: '200 g Mehl'),
            ],
            steps: const ['Mix.'],
            tags: const [],
            importedAt: DateTime.utc(2026, 7, 10),
          ),
        );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: RecipeDetailScreen(recipeId: id)),
    ));
    await settle(tester);
    return container;
  }

  testWidgets(
      'cart button adds the scaled ingredient line and highlights, no snackbar',
      (tester) async {
    final container = await pumpCartRecipe(tester);

    // Scale 2 → 3 servings, then add to cart: expect the scaled line.
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
    await settle(tester);

    // Drift streams deliver via real timers — read them under runAsync, or
    // the await never completes inside the fake-async test zone.
    final items = await tester.runAsync(
        () => container.read(shoppingRepositoryProvider).watchItems().first);
    expect(items!.single.text, '300 g Mehl');
    // Button flips to the highlighted (filled) state; no snackbar feedback.
    expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
    expect(find.byIcon(Icons.add_shopping_cart_outlined), findsNothing);
    expect(find.text('Added to shopping list'), findsNothing);
    await flushTeardown(tester);
  });

  testWidgets('tapping the highlighted cart button removes the item it added', (
    tester,
  ) async {
    final container = await pumpCartRecipe(tester);

    await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
    await settle(tester);
    var items = await tester.runAsync(
        () => container.read(shoppingRepositoryProvider).watchItems().first);
    expect(items!, hasLength(1));

    await tester.tap(find.byIcon(Icons.shopping_cart)); // toggle off
    await settle(tester);
    items = await tester.runAsync(
        () => container.read(shoppingRepositoryProvider).watchItems().first);
    expect(items!, isEmpty);
    expect(find.byIcon(Icons.add_shopping_cart_outlined), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart), findsNothing);
    await flushTeardown(tester);
  });

  testWidgets('changing servings leaves the added item and highlight untouched', (
    tester,
  ) async {
    final container = await pumpCartRecipe(tester);

    // Add at the base 2 servings → '200 g Mehl'.
    await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
    await settle(tester);

    // Scale up to 3 servings afterwards.
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await settle(tester);

    // The list keeps the amount from the moment of adding; the highlight stays.
    final items = await tester.runAsync(
        () => container.read(shoppingRepositoryProvider).watchItems().first);
    expect(items!.single.text, '200 g Mehl');
    expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
    await flushTeardown(tester);
  });

  testWidgets('edit button opens the pre-filled form', (tester) async {
    await pumpDetail(tester, 'manual:123');
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();
    // Flutter 3.44's default Android page transition (FadeForwards) runs
    // 800 ms; pump past it so the detail route goes offstage and find.text
    // no longer matches its ingredient line.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Edit recipe'), findsOneWidget);
    expect(find.text('200 g Mehl'), findsOneWidget);
    await flushTeardown(tester);
  });
}
