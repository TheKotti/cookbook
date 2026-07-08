# Manual Recipe Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users create recipes by hand and edit existing recipes through one form screen, with manual recipes behaving identically to imported ones.

**Architecture:** A pure builder function (`buildManualRecipe`) turns raw form input into a `Recipe`, reusing the existing ingredient parser; manual recipes get a synthetic `manual:<micros>` sourceUrl so `RecipeRepository.saveRecipe`'s upsert-by-URL handles create and edit unchanged. One new `RecipeFormScreen` serves both modes; the list-screen FAB becomes a two-option menu; the detail screen gains an edit button and hides the source link for manual recipes.

**Tech Stack:** Flutter 3.44.5, Riverpod 3, drift (in-memory `NativeDatabase` in tests), existing `parseIngredient` from `lib/src/parser/ingredient_parser.dart`.

**Spec:** `docs/superpowers/specs/2026-07-07-manual-recipe-entry-design.md`

## Global Constraints

- Flutter is NOT on PATH. Prefix every `flutter` command with `export PATH="$HOME/flutter/bin:$PATH" && `.
- Work on branch `feature/manual-recipe-entry` (already checked out).
- Do not touch the DB schema, `pubspec.yaml`, or the backup JSON format — no new dependencies, no migration.
- Widget tests that open a drift + Riverpod tree MUST end with the `flushTeardown` pattern (pump `SizedBox`, then pump 1 ms) or they fail with "pending timers". Copy the pattern from `test/ui/recipe_list_screen_test.dart`.
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Manual recipe builder + `Recipe.isManual`

**Files:**
- Create: `lib/src/manual/manual_recipe.dart`
- Modify: `lib/src/models/recipe.dart` (add one getter after the `copyWith` method, around line 104)
- Test: `test/manual/manual_recipe_test.dart`

**Interfaces:**
- Consumes: `Recipe` from `lib/src/models/recipe.dart`, `parseIngredient(String)` from `lib/src/parser/ingredient_parser.dart`.
- Produces:
  - `bool Recipe.isManual` getter (`sourceUrl.startsWith('manual:')`).
  - `String newManualSourceUrl({DateTime? now})` → `'manual:<microsecondsSinceEpoch>'`.
  - `Recipe buildManualRecipe({Recipe? existing, required String title, required String author, int? servings, int? prepMinutes, int? cookMinutes, required String ingredientsText, required String stepsText, DateTime? now})` — Task 2's form calls this on save.

- [ ] **Step 1: Write the failing tests**

Create `test/manual/manual_recipe_test.dart`:

```dart
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
      expect(r.sourceUrl, 'manual:${DateTime.utc(2026, 7, 7).microsecondsSinceEpoch}');
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
          title: 't', author: '', prepMinutes: 15,
          ingredientsText: 'x', stepsText: 'y');
      expect(onlyPrep.totalMinutes, 15);
      final neither = buildManualRecipe(
          title: 't', author: '', ingredientsText: 'x', stepsText: 'y');
      expect(neither.totalMinutes, isNull);
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
  });

  test('isManual is false for chefkoch URLs', () {
    final r = Recipe(
      sourceUrl: 'https://www.chefkoch.de/rezepte/1/a.html',
      title: 't', author: '', ingredients: const [], steps: const [],
      tags: const [], importedAt: DateTime.utc(2026, 7, 7),
    );
    expect(r.isManual, isFalse);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/manual/manual_recipe_test.dart`
Expected: FAIL — compile error, `manual_recipe.dart` and `isManual` don't exist.

- [ ] **Step 3: Implement**

Add to `lib/src/models/recipe.dart`, directly after the `copyWith` method:

```dart
  /// Manually created recipes carry a synthetic `manual:<micros>` sourceUrl
  /// instead of a chefkoch link.
  bool get isManual => sourceUrl.startsWith('manual:');
```

Create `lib/src/manual/manual_recipe.dart`:

```dart
import '../models/recipe.dart';
import '../parser/ingredient_parser.dart';

String newManualSourceUrl({DateTime? now}) =>
    'manual:${(now ?? DateTime.now()).microsecondsSinceEpoch}';

List<String> _nonEmptyLines(String text) =>
    text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

/// Builds the [Recipe] to save from the manual form's raw inputs. With
/// [existing] set (edit mode), the fields the form doesn't own — id,
/// sourceUrl, imageUrl, rating, tags, importedAt — are preserved; otherwise
/// a fresh manual recipe is created.
Recipe buildManualRecipe({
  Recipe? existing,
  required String title,
  required String author,
  int? servings,
  int? prepMinutes,
  int? cookMinutes,
  required String ingredientsText,
  required String stepsText,
  DateTime? now,
}) {
  return Recipe(
    id: existing?.id,
    sourceUrl: existing?.sourceUrl ?? newManualSourceUrl(now: now),
    title: title.trim(),
    author: author.trim(),
    imageUrl: existing?.imageUrl,
    baseServings: servings,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    totalMinutes: prepMinutes == null && cookMinutes == null
        ? null
        : (prepMinutes ?? 0) + (cookMinutes ?? 0),
    rating: existing?.rating,
    ingredients: [
      for (final line in _nonEmptyLines(ingredientsText)) parseIngredient(line)
    ],
    steps: _nonEmptyLines(stepsText),
    tags: existing?.tags ?? const [],
    importedAt: existing?.importedAt ?? (now ?? DateTime.now()),
  );
}
```

Note: `baseServings` in edit mode intentionally comes from the form's `servings` argument (the form pre-fills it from the existing recipe), not from `existing` — the user may change it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/manual/manual_recipe_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/manual/manual_recipe.dart lib/src/models/recipe.dart test/manual/manual_recipe_test.dart
git commit -m "feat: add manual recipe builder and Recipe.isManual

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: RecipeFormScreen (create + edit)

**Files:**
- Create: `lib/src/ui/recipe_form_screen.dart`
- Test: `test/ui/recipe_form_screen_test.dart`

**Interfaces:**
- Consumes: `buildManualRecipe(...)` and `newManualSourceUrl` from Task 1; `recipeRepositoryProvider`, `recipeDetailProvider` from `lib/src/providers.dart`; `RecipeDetailScreen(recipeId:)` from `lib/src/ui/recipe_detail_screen.dart`.
- Produces: `class RecipeFormScreen extends ConsumerStatefulWidget` with constructor `RecipeFormScreen({super.key, this.existing})` where `existing` is `Recipe?`. Tasks 3 and 4 push this route.

- [ ] **Step 1: Write the failing widget tests**

Create `test/ui/recipe_form_screen_test.dart`:

```dart
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

  Future<ProviderContainer> pumpForm(WidgetTester tester,
      {model.Recipe? existing}) async {
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: RecipeFormScreen(existing: existing)),
    ));
    await settle(tester);
    return container;
  }

  Future<void> enterField(WidgetTester tester, String label, String text) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, label), text);
  }

  testWidgets('blocks save and shows errors when required fields are empty',
      (tester) async {
    final container = await pumpForm(tester);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Add at least one ingredient'), findsOneWidget);
    expect(find.text('Add at least one step'), findsOneWidget);
    final saved = await container.read(recipeRepositoryProvider).getAllRecipes();
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

  testWidgets('create saves a manual recipe and opens its detail screen',
      (tester) async {
    final container = await pumpForm(tester);
    await enterField(tester, 'Title', 'Pancakes');
    await enterField(tester, 'Servings', '4');
    await enterField(tester, 'Prep time (min)', '10');
    await enterField(tester, 'Cook time (min)', '20');
    await enterField(tester, 'Ingredients (one per line)', '200 g Mehl\n2 Eier');
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

  testWidgets('edit pre-fills fields and preserves identity and tags',
      (tester) async {
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
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

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: RecipeFormScreen(existing: existing)),
    ));
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/ui/recipe_form_screen_test.dart`
Expected: FAIL — compile error, `recipe_form_screen.dart` doesn't exist.

- [ ] **Step 3: Implement the screen**

Create `lib/src/ui/recipe_form_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../manual/manual_recipe.dart';
import '../models/recipe.dart';
import '../providers.dart';
import 'recipe_detail_screen.dart';

/// Create (existing == null) or edit (existing != null) a recipe by hand.
/// Tags are edited on the detail screen, not here.
class RecipeFormScreen extends ConsumerStatefulWidget {
  final Recipe? existing;
  const RecipeFormScreen({super.key, this.existing});

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _author = TextEditingController(text: widget.existing?.author ?? '');
  late final _servings =
      TextEditingController(text: widget.existing?.baseServings?.toString() ?? '');
  late final _prep =
      TextEditingController(text: widget.existing?.prepMinutes?.toString() ?? '');
  late final _cook =
      TextEditingController(text: widget.existing?.cookMinutes?.toString() ?? '');
  late final _ingredients = TextEditingController(
      text: widget.existing?.ingredients.map((i) => i.raw).join('\n') ?? '');
  late final _steps =
      TextEditingController(text: widget.existing?.steps.join('\n') ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _author, _servings, _prep, _cook, _ingredients, _steps]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optionalInt(String? value, {int min = 0, required String message}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final n = int.tryParse(text);
    return (n == null || n < min) ? message : null;
  }

  String? _requiredLines(String? value, String message) =>
      (value ?? '').split('\n').any((l) => l.trim().isNotEmpty) ? null : message;

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final recipe = buildManualRecipe(
        existing: widget.existing,
        title: _title.text,
        author: _author.text,
        servings: int.tryParse(_servings.text.trim()),
        prepMinutes: int.tryParse(_prep.text.trim()),
        cookMinutes: int.tryParse(_cook.text.trim()),
        ingredientsText: _ingredients.text,
        stepsText: _steps.text,
      );
      final id = await ref.read(recipeRepositoryProvider).saveRecipe(recipe);
      if (!mounted) return;
      if (widget.existing == null) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)));
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save the recipe: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit recipe' : 'Add recipe')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _author,
              decoration: const InputDecoration(
                  labelText: 'Author (optional)', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servings,
                    decoration: const InputDecoration(
                        labelText: 'Servings', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) => _optionalInt(v,
                        min: 1, message: 'Enter a whole number of 1 or more'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prep,
                    decoration: const InputDecoration(
                        labelText: 'Prep time (min)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        _optionalInt(v, message: 'Enter a whole number'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cook,
                    decoration: const InputDecoration(
                        labelText: 'Cook time (min)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        _optionalInt(v, message: 'Enter a whole number'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ingredients,
              decoration: const InputDecoration(
                labelText: 'Ingredients (one per line)',
                hintText: '200 g Mehl\n2 Eier\n1 Prise Salz',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 5,
              maxLines: 12,
              validator: (v) => _requiredLines(v, 'Add at least one ingredient'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _steps,
              decoration: const InputDecoration(
                labelText: 'Steps (one per line)',
                hintText: 'Mix the dry ingredients.\nAdd the eggs and stir.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 5,
              maxLines: 20,
              validator: (v) => _requiredLines(v, 'Add at least one step'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/ui/recipe_form_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/recipe_form_screen.dart test/ui/recipe_form_screen_test.dart
git commit -m "feat: add recipe form screen for manual create and edit

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: List-screen FAB menu

**Files:**
- Modify: `lib/src/ui/recipe_list_screen.dart` (FAB at ~line 42, empty-state text at ~line 99)
- Test: `test/ui/recipe_list_screen_test.dart` (append one test)

**Interfaces:**
- Consumes: `RecipeFormScreen()` from Task 2 (no-arg constructor = create mode); existing `ImportScreen`.
- Produces: no new API — UI behavior only.

- [ ] **Step 1: Write the failing test**

Append to `main()` in `test/ui/recipe_list_screen_test.dart` (the file already defines `settle` and `flushTeardown`):

```dart
  testWidgets('FAB opens a menu with import and manual-entry options',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: RecipeListScreen()),
    ));
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/ui/recipe_list_screen_test.dart`
Expected: the new test FAILS (FAB navigates straight to the import screen; 'Add manually' not found). Existing tests still pass.

- [ ] **Step 3: Implement**

In `lib/src/ui/recipe_list_screen.dart`:

1. Add import: `import 'recipe_form_screen.dart';`
2. Replace the `floatingActionButton:` block with:

```dart
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context),
        tooltip: 'Add recipe',
        child: const Icon(Icons.add),
      ),
```

3. Add this method to `RecipeListScreen` (next to `_exportBackup`):

```dart
  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Import from URL'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImportScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Add manually'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RecipeFormScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
```

4. Update the empty-state string from `'Tap + to import your first recipe from chefkoch.de.'` to `'Tap + to import a recipe from chefkoch.de or add one manually.'`

- [ ] **Step 4: Run tests to verify they pass**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/ui/recipe_list_screen_test.dart`
Expected: PASS (all tests, including the new one).

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/recipe_list_screen.dart test/ui/recipe_list_screen_test.dart
git commit -m "feat: FAB menu with import and manual-entry options

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Detail-screen edit button + manual source line

**Files:**
- Modify: `lib/src/ui/recipe_detail_screen.dart` (app bar actions ~line 69, source line ~line 97)
- Modify: `lib/src/ui/tag_editor_sheet.dart` (stale comment, line 7)
- Test: `test/ui/recipe_detail_screen_test.dart` (create)

**Interfaces:**
- Consumes: `RecipeFormScreen(existing: recipe)` from Task 2; `Recipe.isManual` from Task 1.
- Produces: no new API — UI behavior only.

- [ ] **Step 1: Write the failing widget tests**

Create `test/ui/recipe_detail_screen_test.dart`:

```dart
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
    return container.read(recipeRepositoryProvider).saveRecipe(model.Recipe(
          sourceUrl: sourceUrl,
          title: 'Pancakes',
          author: 'Oma',
          ingredients: const [model.Ingredient(name: 'Mehl', raw: '200 g Mehl')],
          steps: const ['Mix.'],
          tags: const [],
          importedAt: DateTime.utc(2026, 7, 7),
        ));
  }

  Future<ProviderContainer> pumpDetail(WidgetTester tester, String sourceUrl) async {
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final id = await save(container, sourceUrl);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: RecipeDetailScreen(recipeId: id)),
    ));
    await settle(tester);
    return container;
  }

  testWidgets('manual recipe shows plain author line without chefkoch link',
      (tester) async {
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
    await settle(tester);
    expect(find.text('Edit recipe'), findsOneWidget);
    expect(find.text('200 g Mehl'), findsOneWidget);
    await flushTeardown(tester);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/ui/recipe_detail_screen_test.dart`
Expected: FAIL — 'By Oma' not found (link text says chefkoch.de) and `Icons.edit_outlined` not found.

- [ ] **Step 3: Implement**

In `lib/src/ui/recipe_detail_screen.dart`:

1. Add import: `import 'recipe_form_screen.dart';`
2. In the app bar `actions`, insert before the delete `IconButton`:

```dart
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit recipe',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RecipeFormScreen(existing: recipe))),
          ),
```

3. Replace the `InkWell(...)` source-line widget with:

```dart
                recipe.isManual
                    ? Text('By $author')
                    : InkWell(
                        onTap: () => launchUrl(Uri.parse(recipe.sourceUrl),
                            mode: LaunchMode.externalApplication),
                        child: Text(
                          'By $author · chefkoch.de',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
```

In `lib/src/ui/tag_editor_sheet.dart`, replace the comment on line 7:

```dart
/// Tags are edited here (not in the recipe form) for imported and manual
/// recipes alike.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/ui/recipe_detail_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/recipe_detail_screen.dart lib/src/ui/tag_editor_sheet.dart test/ui/recipe_detail_screen_test.dart
git commit -m "feat: edit button on detail screen; plain source line for manual recipes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Full verification

**Files:** none new.

**Interfaces:** n/a — verification only.

- [ ] **Step 1: Run the full test suite**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test`
Expected: ALL tests pass (pre-existing suites in test/backup, test/import, test/models, test/parser, test/repository, test/scaling, test/ui plus the new ones).

- [ ] **Step 2: Run the analyzer**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Fix anything that surfaced, re-run both, commit fixes**

Only if Steps 1–2 flagged issues:

```bash
git add -A
git commit -m "fix: address analyzer/test findings for manual recipe entry

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
