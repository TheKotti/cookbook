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

  testWidgets('imported recipe keeps the chefkoch source link', (tester) async {
    await pumpDetail(tester, 'https://www.chefkoch.de/rezepte/1/a.html');
    expect(find.text('By Oma · chefkoch.de'), findsOneWidget);
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
