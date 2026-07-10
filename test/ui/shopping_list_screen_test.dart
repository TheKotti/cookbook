import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/providers.dart';
import 'package:cookbook/src/ui/shopping_list_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> flushTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ShoppingListScreen()),
    ));
    await settle(tester);
  }

  testWidgets('empty state renders', (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('Your shopping list is empty'), findsOneWidget);
    await flushTeardown(tester);
  });

  testWidgets('bottom input adds an item and clears the field', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'Butter');
    await tester.tap(find.byIcon(Icons.add));
    await settle(tester);
    expect(find.text('Butter'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await flushTeardown(tester);
  });

  testWidgets('checking an item removes it', (tester) async {
    await container.read(shoppingRepositoryProvider).addItem('Milch');
    await pumpScreen(tester);
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    expect(find.text('Milch'), findsNothing);
    // Drift streams deliver via real timers — read them under runAsync.
    final remaining = await tester.runAsync(
        () => container.read(shoppingRepositoryProvider).watchItems().first);
    expect(remaining, isEmpty);
    await flushTeardown(tester);
  });

  testWidgets('tapping the text opens an edit dialog that updates the item', (
    tester,
  ) async {
    await container.read(shoppingRepositoryProvider).addItem('Zuker');
    await pumpScreen(tester);
    await tester.tap(find.text('Zuker'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Zucker');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(); // let the dialog's exit animation finish
    expect(find.text('Zucker'), findsOneWidget);
    expect(find.text('Zuker'), findsNothing);
    await flushTeardown(tester);
  });

  testWidgets('Clear all empties the list after confirmation', (tester) async {
    final repo = container.read(shoppingRepositoryProvider);
    await repo.addItem('A');
    await repo.addItem('B');
    await pumpScreen(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    final remaining = await tester.runAsync(() => repo.watchItems().first);
    expect(remaining, isEmpty);
    await flushTeardown(tester);
  });
}
