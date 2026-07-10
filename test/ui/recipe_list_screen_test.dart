import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/models/recipe.dart' as model;
import 'package:cookbook/src/providers.dart';
import 'package:cookbook/src/ui/recipe_list_screen.dart';
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

  // Drift schedules a zero-duration timer when its query streams are closed on
  // ProviderScope disposal; tear the tree down and flush it so testWidgets
  // doesn't fail with "pending timers".
  Future<void> flushTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows empty state when no recipes exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await settle(tester);
    expect(find.text('No recipes yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await flushTeardown(tester);
  });

  testWidgets('lists recipes and filters via tag chip', (tester) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(recipeRepositoryProvider);
    await repo.saveRecipe(
      model.Recipe(
        sourceUrl: 'https://www.chefkoch.de/rezepte/1/a.html',
        title: 'Lasagne',
        author: 'x',
        ingredients: const [],
        steps: const [],
        tags: const ['pasta'],
        importedAt: DateTime.utc(2026, 7, 7),
      ),
    );
    await repo.saveRecipe(
      model.Recipe(
        sourceUrl: 'https://www.chefkoch.de/rezepte/2/b.html',
        title: 'Salat',
        author: 'x',
        ingredients: const [],
        steps: const [],
        tags: const ['leicht'],
        importedAt: DateTime.utc(2026, 7, 7),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await settle(tester);

    expect(find.text('Lasagne'), findsOneWidget);
    expect(find.text('Salat'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'pasta'));
    await settle(tester);
    expect(find.text('Lasagne'), findsOneWidget);
    expect(find.text('Salat'), findsNothing);
    await flushTeardown(tester);
  });

  testWidgets('cart icon shows a badge with the item count and opens the list', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(shoppingRepositoryProvider).addItem('Milch');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await settle(tester);

    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // badge label

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // page transition
    expect(find.text('Shopping list'), findsOneWidget);
    await flushTeardown(tester);
  });

  testWidgets('FAB opens a menu with import and manual-entry options', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await settle(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(find.text('Import from URL'), findsOneWidget);
    expect(find.text('Add manually'), findsOneWidget);

    await tester.tap(find.text('Add manually'));
    await settle(tester);
    expect(find.text('Add recipe'), findsOneWidget);
    await flushTeardown(tester);
  });
}
