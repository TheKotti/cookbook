# Cookbook Recipe Importer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A local-only Flutter Android app that imports recipes from chefkoch.de by URL, stores them in Drift/SQLite, and offers search (FTS5), tags, serving scaling, and JSON backup — per `DESIGN.md` (Draft v3).

**Architecture:** Everything on-device. A pure-Dart `RecipeParser` turns fetched Chefkoch HTML (schema.org/Recipe JSON-LD) into a normalized `Recipe`. All storage goes through a `RecipeRepository` interface backed by `LocalRecipeRepository` (Drift + FTS5). Riverpod wires repositories/services to three screens (List, Detail, Import) plus a tag editor sheet. An Android share-target feeds shared URLs into the import flow via a MethodChannel.

**Tech Stack:** Flutter 3.44.5 / Dart 3.12, flutter_riverpod (v3 Notifier API), drift + drift_flutter, http, cached_network_image, share_plus, file_picker, url_launcher.

## Global Constraints

- **Spec:** `/home/kotti/Desktop/Code/cookbook/DESIGN.md` is authoritative. Sections referenced as §N.
- **Flutter is NOT on PATH.** Every shell command that uses `flutter`/`dart` must run `export PATH="$HOME/flutter/bin:$PATH"` first (repeat in every new shell).
- **Working directory:** `/home/kotti/Desktop/Code/cookbook` for all commands.
- **UI language: English.** All user-facing strings in English. Number display uses **German comma decimals** (`2,5`) — only for scaled amounts (§7).
- **Android applicationId: `dev.cookbook.app`.** App display name: `Cookbook`.
- **Kotlin/namespace package:** `dev.cookbook.cookbook` (from `flutter create --org dev.cookbook`); only `applicationId` is overridden to `dev.cookbook.app`.
- Imported recipe fields are **read-only**; tags are the only editable field (§2).
- Re-import of an existing `source_url` **overwrites** the recipe row but **keeps the user's existing tags**; keyword seeds apply only on first import. Backup import **replaces** tags (§8: "rows in the file replace matching local rows").
- Ingredients are **never dropped**: on any parse uncertainty keep `raw` and null the structured fields (§6).
- Tags are stored **lowercase, trimmed, deduplicated**.
- One network request per user action; browser-like User-Agent (§2, §11).
- TDD: every code task writes the failing test first. Commit after every task.
- Test fixtures `test/fixtures/ofenkartoffeln.html` and `test/fixtures/lasagne.html` are **already downloaded** (real Chefkoch pages, July 2026). Do not re-fetch; do not commit new fetches.

### Fixture ground truth (verified from the downloaded files — use in tests)

`ofenkartoffeln.html` (source URL `https://www.chefkoch.de/rezepte/1064631211795001/Knusprige-Ofenkartoffeln.html`):
- name `Knusprige Ofenkartoffeln von mareikaeferchen`, author.name `mareikaeferchen`
- recipeYield `"3 Portionen"`, prepTime `P0DT0H20M`, cookTime `P0DT0H40M`, totalTime `P0DT1H0M`
- image: **string** `https://img.chefkoch-cdn.de/rezepte/1064631211795001/bilder/1619953/crop-960x540/knusprige-ofenkartoffeln.jpg`
- aggregateRating.ratingValue `4.8`
- keywords: `"Backen, Saucen, Dips, Beilage, raffiniert oder preiswert, einfach, Kartoffel, Snack"`
- 12 `recipeIngredient` strings incl. `"10 m.-große Kartoffeln, festkochende"`, `"3 EL Olivenöl"`, `" etwas Chilipulver"`, `"1  Zitrone(n), Saft davon"`, `"1 EL Rosmarin (getrocknet (frische Nadeln schmecken natürlich intensiver))"`
- recipeInstructions: **list of `HowToSection`** with `itemListElement` of `HowToStep`; first step text starts `Die geschälten, geviertelten Kartoffeln`

`lasagne.html` (source URL `https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html`):
- name `Lasagne - wie beim Italiener`, recipeYield `"4 Portionen"`, prepTime `P0DT0H30M`, cookTime `P0DT1H10M`, totalTime `P0DT1H40M`, ratingValue `4.7`
- 19 ingredients incl. `"0.5 Liter Milch"` (dot decimal!), `"1 Msp. Muskat (frisch gerieben)"`, `"1 Dose Tomaten, geschälte (800 g)"`, `"  Salz und Pfeffer"`, `" etwas Rotwein (50–100 ml)"`, `"1 Bund Petersilie (oder TK)"`

---

## File Structure

```
lib/
  main.dart                                  # entry, MaterialApp, share-intent wiring
  src/
    models/recipe.dart                       # Recipe + Ingredient domain models, JSON
    parser/scalar_parsers.dart               # ISO-8601 duration → minutes; yield → servings
    parser/ingredient_parser.dart            # German ingredient string → Ingredient
    parser/recipe_parser.dart                # HTML → JSON-LD → Recipe
    db/database.dart (+ database.g.dart)     # Drift tables + FTS5 + migrations
    repository/recipe_repository.dart        # abstract interface + TagMode
    repository/local_recipe_repository.dart  # Drift implementation
    import/url_validator.dart                # URL extraction + host validation
    import/import_service.dart               # fetch (browser UA) → parse → save
    scaling/serving_scaler.dart              # scaling + rounding/formatting (§7)
    backup/backup_service.dart               # JSON export/import (§8)
    providers.dart                           # Riverpod wiring
    share/share_intent_handler.dart          # MethodChannel for Android share target
    ui/recipe_list_screen.dart
    ui/recipe_detail_screen.dart
    ui/import_screen.dart
    ui/tag_editor_sheet.dart
test/
  fixtures/{ofenkartoffeln,lasagne}.html     # already present
  fixtures/synthetic_variants.html           # created in Task 5
  fixtures/block_page.html                   # created in Task 5
  models/recipe_test.dart
  parser/{scalar_parsers,ingredient_parser,recipe_parser}_test.dart
  repository/local_recipe_repository_test.dart
  import/{url_validator,import_service}_test.dart
  scaling/serving_scaler_test.dart
  backup/backup_service_test.dart
  ui/recipe_list_screen_test.dart
android/app/src/main/AndroidManifest.xml     # INTERNET, share intent-filter, label
android/app/src/main/kotlin/dev/cookbook/cookbook/MainActivity.kt
```

---

### Task 1: Project scaffold, git, dependencies, Android config

**Files:**
- Create: Flutter project scaffold in `.` (existing `DESIGN.md`, `docs/`, `test/fixtures/` stay)
- Modify: `pubspec.yaml`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- Create: `test/smoke_test.dart`; Delete: `test/widget_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: a compiling Flutter project named `cookbook`, org `dev.cookbook`, with all runtime/dev dependencies installed; git repo with initial commit.

- [ ] **Step 1: Initialize git and commit pre-existing docs/fixtures**

```bash
cd /home/kotti/Desktop/Code/cookbook
git init -b main
git add DESIGN.md docs/ test/fixtures/ofenkartoffeln.html test/fixtures/lasagne.html
git commit -m "docs: add design document, implementation plan, and parser fixtures"
```

- [ ] **Step 2: Create the Flutter project in place**

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd /home/kotti/Desktop/Code/cookbook
flutter create --org dev.cookbook --project-name cookbook --platforms android,ios .
```
Expected: "All done!" and `lib/main.dart`, `android/`, `ios/` exist.

- [ ] **Step 3: Add dependencies**

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub add flutter_riverpod drift drift_flutter http cached_network_image share_plus file_picker url_launcher path_provider path
flutter pub add --dev drift_dev build_runner
```
Expected: exit 0, all resolve. (`flutter_lints` is already a dev dep from the template.)

- [ ] **Step 4: Set applicationId and app label**

In `android/app/build.gradle.kts`, inside `defaultConfig`, change `applicationId` to:

```kotlin
        applicationId = "dev.cookbook.app"
```
(Leave `namespace = "dev.cookbook.cookbook"` untouched.)

In `android/app/src/main/AndroidManifest.xml`, ensure the `<application>` tag has `android:label="Cookbook"` and add the INTERNET permission plus a `<queries>` block for url_launcher as direct children of `<manifest>` (before `<application>`):

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
    </queries>
```

- [ ] **Step 5: Replace the template test with a smoke test**

Delete `test/widget_test.dart`. Create `test/smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke', () {
    expect(1 + 1, 2);
  });
}
```

- [ ] **Step 6: Verify analyze and test pass**

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter analyze && flutter test
```
Expected: "No issues found!" and "All tests passed!".

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: scaffold Flutter project with dependencies and Android config"
```

---

### Task 2: Domain models (`Recipe`, `Ingredient`)

**Files:**
- Create: `lib/src/models/recipe.dart`
- Test: `test/models/recipe_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `const int kCurrentSchemaVersion = 1;`
  - `class Ingredient { final double? amount; final double? amountMax; final String? unit; final String name; final String raw; }` with `toJson()`, `Ingredient.fromJson(Map)`, value equality.
  - `class Recipe { final int? id; final String sourceUrl; final String title; final String author; final String? imageUrl; final int? baseServings; final int? prepMinutes; final int? cookMinutes; final int? totalMinutes; final double? rating; final List<Ingredient> ingredients; final List<String> steps; final List<String> tags; final DateTime importedAt; final int schemaVersion; }` with `copyWith(...)`, `String get ingredientsJson`, `String get stepsJson`, `static List<Ingredient> decodeIngredients(String json)`, `static List<String> decodeSteps(String json)`.

- [ ] **Step 1: Write the failing test**

Create `test/models/recipe_test.dart`:

```dart
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
    final salt = Ingredient.fromJson({'amount': null, 'amount_max': null, 'unit': null, 'name': 'Salz', 'raw': ' Salz'});
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/models/recipe_test.dart
```
Expected: FAIL — `Error: Couldn't resolve the package 'cookbook'` / URI doesn't exist.

- [ ] **Step 3: Write the implementation**

Create `lib/src/models/recipe.dart`:

```dart
import 'dart:convert';

const int kCurrentSchemaVersion = 1;

class Ingredient {
  final double? amount;
  final double? amountMax;
  final String? unit;
  final String name;
  final String raw;

  const Ingredient({
    this.amount,
    this.amountMax,
    this.unit,
    required this.name,
    required this.raw,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'amount_max': amountMax,
        'unit': unit,
        'name': name,
        'raw': raw,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        amount: (json['amount'] as num?)?.toDouble(),
        amountMax: (json['amount_max'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        name: json['name'] as String? ?? '',
        raw: json['raw'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.amount == amount &&
      other.amountMax == amountMax &&
      other.unit == unit &&
      other.name == name &&
      other.raw == raw;

  @override
  int get hashCode => Object.hash(amount, amountMax, unit, name, raw);

  @override
  String toString() => 'Ingredient(amount: $amount, amountMax: $amountMax, unit: $unit, name: $name, raw: $raw)';
}

class Recipe {
  final int? id;
  final String sourceUrl;
  final String title;
  final String author;
  final String? imageUrl;
  final int? baseServings;
  final int? prepMinutes;
  final int? cookMinutes;
  final int? totalMinutes;
  final double? rating;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final DateTime importedAt;
  final int schemaVersion;

  const Recipe({
    this.id,
    required this.sourceUrl,
    required this.title,
    required this.author,
    this.imageUrl,
    this.baseServings,
    this.prepMinutes,
    this.cookMinutes,
    this.totalMinutes,
    this.rating,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.importedAt,
    this.schemaVersion = kCurrentSchemaVersion,
  });

  Recipe copyWith({int? id, List<String>? tags}) => Recipe(
        id: id ?? this.id,
        sourceUrl: sourceUrl,
        title: title,
        author: author,
        imageUrl: imageUrl,
        baseServings: baseServings,
        prepMinutes: prepMinutes,
        cookMinutes: cookMinutes,
        totalMinutes: totalMinutes,
        rating: rating,
        ingredients: ingredients,
        steps: steps,
        tags: tags ?? this.tags,
        importedAt: importedAt,
        schemaVersion: schemaVersion,
      );

  String get ingredientsJson => jsonEncode(ingredients.map((i) => i.toJson()).toList());

  String get stepsJson => jsonEncode(steps);

  static List<Ingredient> decodeIngredients(String json) => (jsonDecode(json) as List)
      .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
      .toList();

  static List<String> decodeSteps(String json) => (jsonDecode(json) as List).cast<String>();
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/models/recipe_test.dart
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/models/recipe.dart test/models/recipe_test.dart
git commit -m "feat: add Recipe and Ingredient domain models with JSON codecs"
```

---

### Task 3: Scalar parsers (ISO-8601 durations, servings yield)

**Files:**
- Create: `lib/src/parser/scalar_parsers.dart`
- Test: `test/parser/scalar_parsers_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `int? parseIso8601DurationToMinutes(String? value)` — full day/hour/minute parse; `null` for null/unparseable/zero total.
  - `int? parseServings(Object? yieldValue)` — handles `num`, `String` (leading integer, e.g. `"2 Portionen"`), `List` (first element); `null` otherwise or when < 1.

- [ ] **Step 1: Write the failing test**

Create `test/parser/scalar_parsers_test.dart`:

```dart
import 'package:cookbook/src/parser/scalar_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseIso8601DurationToMinutes', () {
    test('parses the real Chefkoch P0DT0H15M shape', () {
      expect(parseIso8601DurationToMinutes('P0DT0H15M'), 15);
      expect(parseIso8601DurationToMinutes('P0DT1H0M'), 60);
      expect(parseIso8601DurationToMinutes('P0DT1H40M'), 100);
    });
    test('parses plain schema.org shapes', () {
      expect(parseIso8601DurationToMinutes('PT15M'), 15);
      expect(parseIso8601DurationToMinutes('PT2H'), 120);
      expect(parseIso8601DurationToMinutes('P1DT2H30M'), 1590);
    });
    test('returns null for null, garbage, and zero durations', () {
      expect(parseIso8601DurationToMinutes(null), isNull);
      expect(parseIso8601DurationToMinutes(''), isNull);
      expect(parseIso8601DurationToMinutes('15 Minuten'), isNull);
      expect(parseIso8601DurationToMinutes('P0DT0H0M'), isNull);
    });
  });

  group('parseServings', () {
    test('parses the real "N Portionen" string shape', () {
      expect(parseServings('3 Portionen'), 3);
      expect(parseServings('12 Stück'), 12);
    });
    test('accepts plain numbers', () {
      expect(parseServings(4), 4);
      expect(parseServings(4.0), 4);
    });
    test('takes the first element of a list', () {
      expect(parseServings(['2 Portionen']), 2);
    });
    test('returns null when no leading integer exists', () {
      expect(parseServings('Portionen'), isNull);
      expect(parseServings(null), isNull);
      expect(parseServings(0), isNull);
      expect(parseServings(''), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/parser/scalar_parsers_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/src/parser/scalar_parsers.dart`:

```dart
/// Parses an ISO-8601 duration (e.g. `PT15M` or Chefkoch's `P0DT0H15M`)
/// into total minutes. Returns null when absent, unparseable, or zero.
int? parseIso8601DurationToMinutes(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$')
      .firstMatch(value.trim());
  if (match == null) return null;
  if (match[1] == null && match[2] == null && match[3] == null && match[4] == null) {
    return null;
  }
  final minutes = int.parse(match[1] ?? '0') * 24 * 60 +
      int.parse(match[2] ?? '0') * 60 +
      int.parse(match[3] ?? '0');
  return minutes == 0 ? null : minutes;
}

/// Parses schema.org `recipeYield` into a serving count.
/// Real Chefkoch value is a string like `"2 Portionen"` — take the leading
/// integer. Returns null when it can't be determined (scaler is then hidden).
int? parseServings(Object? yieldValue) {
  if (yieldValue is num) {
    final n = yieldValue.toInt();
    return n >= 1 ? n : null;
  }
  if (yieldValue is String) {
    final match = RegExp(r'^\s*(\d+)').firstMatch(yieldValue);
    if (match == null) return null;
    final n = int.parse(match[1]!);
    return n >= 1 ? n : null;
  }
  if (yieldValue is List && yieldValue.isNotEmpty) {
    return parseServings(yieldValue.first);
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/parser/scalar_parsers_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/parser/scalar_parsers.dart test/parser/scalar_parsers_test.dart
git commit -m "feat: parse ISO-8601 durations and recipeYield servings"
```

---

### Task 4: German-aware ingredient parser

**Files:**
- Create: `lib/src/parser/ingredient_parser.dart`
- Test: `test/parser/ingredient_parser_test.dart`

**Interfaces:**
- Consumes: `Ingredient` from `lib/src/models/recipe.dart`.
- Produces: `Ingredient parseIngredient(String input)` — never throws, never drops an ingredient; on failure returns `Ingredient(name: <trimmed input>, raw: <trimmed input>)`.

Parsing rules (from §5/§6, in order):
1. `raw` = input trimmed with internal whitespace collapsed to single spaces. All later steps work on `raw`.
2. Strip a leading qualifier `etwas |ca. |evtl. |ggf. ` (case-insensitive) for structure parsing (it stays in `raw`).
3. Amount at string start, first match wins, must be followed by whitespace or end:
   - range `2-3` / `2–3` / `2,5-3` → `amount` low, `amountMax` high
   - mixed unicode fraction `1 ½` → `1.5`
   - lone unicode fraction `½` → `0.5` (map: ½ ⅓ ⅔ ¼ ¾ ⅕ ⅛ ⅜ ⅝ ⅞)
   - ASCII fraction `1/2` → `0.5`
   - decimal with comma **or dot** (`0,5`, `0.5`) or integer
   - no match → `amount: null, amountMax: null`
4. Unit: only if an amount was found — next whitespace-delimited token if it is in the known-units set **and** a non-empty name follows. Known units: `g, kg, mg, ml, cl, l, Liter, EL, TL, Msp., Prise, Prisen, Bund, Dose, Dosen, Stück, Pck., Päckchen, Packung, Becher, Tasse, Tassen, Glas, Zehe, Zehen, Scheibe, Scheiben, Blatt, Blätter, Zweig, Zweige, Stange, Stangen, Würfel, Tropfen, Schuss, Handvoll`.
5. Name = remainder; cut at the first ` (` (space+paren — keeps `Zitrone(n)`/`Ei(er)` intact, drops ` (Größe M)` including unbalanced nesting); then cut at the first `,`; trim. Empty name → fall back to `raw`.

- [ ] **Step 1: Write the failing test**

Create `test/parser/ingredient_parser_test.dart` (cases from the two real fixtures + §5 examples):

```dart
import 'package:cookbook/src/models/recipe.dart';
import 'package:cookbook/src/parser/ingredient_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Matcher parsed({double? amount, double? amountMax, String? unit, required String name}) =>
      isA<Ingredient>()
          .having((i) => i.amount, 'amount', amount)
          .having((i) => i.amountMax, 'amountMax', amountMax)
          .having((i) => i.unit, 'unit', unit)
          .having((i) => i.name, 'name', name);

  test('simple amount + unit + name', () {
    expect(parseIngredient('500 g Spaghetti'), parsed(amount: 500, unit: 'g', name: 'Spaghetti'));
    expect(parseIngredient('3 EL Olivenöl'), parsed(amount: 3, unit: 'EL', name: 'Olivenöl'));
  });

  test('dot and comma decimals', () {
    expect(parseIngredient('0.5 Liter Milch'), parsed(amount: 0.5, unit: 'Liter', name: 'Milch'));
    expect(parseIngredient('0,5 l Sahne'), parsed(amount: 0.5, unit: 'l', name: 'Sahne'));
  });

  test('unicode and ascii fractions', () {
    expect(parseIngredient('½ Ei'), parsed(amount: 0.5, name: 'Ei'));
    expect(parseIngredient('1/2 Zitrone'), parsed(amount: 0.5, name: 'Zitrone'));
    expect(parseIngredient('1 ½ TL Salz'), parsed(amount: 1.5, unit: 'TL', name: 'Salz'));
  });

  test('ranges scale into amount/amountMax', () {
    expect(parseIngredient('2-3 Zehen Knoblauch'),
        parsed(amount: 2, amountMax: 3, unit: 'Zehen', name: 'Knoblauch'));
    expect(parseIngredient('2–3 EL Zucker'),
        parsed(amount: 2, amountMax: 3, unit: 'EL', name: 'Zucker'));
  });

  test('bare count with no unit', () {
    expect(parseIngredient('2  Ei(er) (Größe M)'), parsed(amount: 2, name: 'Ei(er)'));
    expect(parseIngredient('1  Zitrone(n), Saft davon'), parsed(amount: 1, name: 'Zitrone(n)'));
  });

  test('trailing parentheticals and comma qualifiers are cut from name, kept in raw', () {
    final pancetta = parseIngredient('100 g Pancetta (oder Guanciale, , alternativ Bacon)');
    expect(pancetta, parsed(amount: 100, unit: 'g', name: 'Pancetta'));
    expect(pancetta.raw, '100 g Pancetta (oder Guanciale, , alternativ Bacon)');
    expect(parseIngredient('1 Dose Tomaten, geschälte (800 g)'),
        parsed(amount: 1, unit: 'Dose', name: 'Tomaten'));
    expect(parseIngredient('1 EL Rosmarin (getrocknet (frische Nadeln schmecken natürlich intensiver))'),
        parsed(amount: 1, unit: 'EL', name: 'Rosmarin'));
  });

  test('amount-less items keep null amount and clean name', () {
    expect(parseIngredient('  Salz und Pfeffer'), parsed(name: 'Salz und Pfeffer'));
    expect(parseIngredient(' etwas Chilipulver'), parsed(name: 'Chilipulver'));
    expect(parseIngredient(' etwas Rotwein (50–100 ml)'), parsed(name: 'Rotwein'));
    expect(parseIngredient('Salz, nach Belieben'), parsed(name: 'Salz'));
  });

  test('non-unit token after amount stays in name', () {
    expect(parseIngredient('10 m.-große Kartoffeln, festkochende'),
        parsed(amount: 10, name: 'm.-große Kartoffeln'));
  });

  test('raw is always the collapsed trimmed original and nothing is ever dropped', () {
    final weird = parseIngredient('   ');
    expect(weird.raw, '');
    expect(weird.name, '');
    final salz = parseIngredient('  Salz');
    expect(salz.raw, 'Salz');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/parser/ingredient_parser_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/src/parser/ingredient_parser.dart`:

```dart
import '../models/recipe.dart';

const Set<String> _units = {
  'g', 'kg', 'mg', 'ml', 'cl', 'l', 'Liter',
  'EL', 'TL', 'Msp.', 'Prise', 'Prisen', 'Bund',
  'Dose', 'Dosen', 'Stück', 'Pck.', 'Päckchen', 'Packung',
  'Becher', 'Tasse', 'Tassen', 'Glas', 'Zehe', 'Zehen',
  'Scheibe', 'Scheiben', 'Blatt', 'Blätter', 'Zweig', 'Zweige',
  'Stange', 'Stangen', 'Würfel', 'Tropfen', 'Schuss', 'Handvoll',
};

const Map<String, double> _fractions = {
  '½': 0.5, '⅓': 1 / 3, '⅔': 2 / 3, '¼': 0.25, '¾': 0.75,
  '⅕': 0.2, '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
};

final RegExp _leadingQualifier =
    RegExp(r'^(etwas|ca\.|evtl\.|ggf\.)\s+', caseSensitive: false);
final RegExp _range =
    RegExp(r'^(\d+(?:[.,]\d+)?)\s*[-–—]\s*(\d+(?:[.,]\d+)?)(?=\s|$)');
final RegExp _mixedFraction = RegExp(r'^(\d+)\s*([½⅓⅔¼¾⅕⅛⅜⅝⅞])(?=\s|$)');
final RegExp _loneFraction = RegExp(r'^([½⅓⅔¼¾⅕⅛⅜⅝⅞])(?=\s|$)');
final RegExp _asciiFraction = RegExp(r'^(\d+)\s*/\s*(\d+)(?=\s|$)');
final RegExp _decimal = RegExp(r'^(\d+(?:[.,]\d+)?)(?=\s|$)');

double _toDouble(String s) => double.parse(s.replaceAll(',', '.'));

/// Parses one Chefkoch `recipeIngredient` string. Never throws and never
/// drops the ingredient: on any uncertainty the structured fields are null
/// and `raw` carries the original text (§6).
Ingredient parseIngredient(String input) {
  final raw = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  try {
    var rest = raw.replaceFirst(_leadingQualifier, '');

    double? amount;
    double? amountMax;
    RegExpMatch? m;
    if ((m = _range.firstMatch(rest)) != null) {
      amount = _toDouble(m![1]!);
      amountMax = _toDouble(m[2]!);
    } else if ((m = _mixedFraction.firstMatch(rest)) != null) {
      amount = int.parse(m![1]!) + _fractions[m[2]!]!;
    } else if ((m = _loneFraction.firstMatch(rest)) != null) {
      amount = _fractions[m![1]!]!;
    } else if ((m = _asciiFraction.firstMatch(rest)) != null) {
      amount = int.parse(m![1]!) / int.parse(m[2]!);
    } else if ((m = _decimal.firstMatch(rest)) != null) {
      amount = _toDouble(m![1]!);
    }
    if (m != null) rest = rest.substring(m.end).trim();

    String? unit;
    if (amount != null) {
      final unitMatch = RegExp(r'^(\S+)\s+(\S.*)$').firstMatch(rest);
      if (unitMatch != null && _units.contains(unitMatch[1])) {
        unit = unitMatch[1];
        rest = unitMatch[2]!;
      }
    }

    var name = rest;
    final parenIndex = name.indexOf(' (');
    if (parenIndex > 0) name = name.substring(0, parenIndex);
    final commaIndex = name.indexOf(',');
    if (commaIndex > 0) name = name.substring(0, commaIndex);
    name = name.trim();
    if (name.isEmpty && raw.isNotEmpty) {
      return Ingredient(name: raw, raw: raw);
    }
    return Ingredient(amount: amount, amountMax: amountMax, unit: unit, name: name, raw: raw);
  } catch (_) {
    return Ingredient(name: raw, raw: raw);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/parser/ingredient_parser_test.dart
```
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/parser/ingredient_parser.dart test/parser/ingredient_parser_test.dart
git commit -m "feat: add German-aware ingredient string parser"
```

---

### Task 5: `RecipeParser` (JSON-LD → `Recipe`) with real-fixture tests

**Files:**
- Create: `lib/src/parser/recipe_parser.dart`
- Create: `test/fixtures/synthetic_variants.html`, `test/fixtures/block_page.html`
- Test: `test/parser/recipe_parser_test.dart`

**Interfaces:**
- Consumes: `Recipe`, `Ingredient`, `kCurrentSchemaVersion` (Task 2); `parseIso8601DurationToMinutes`, `parseServings` (Task 3); `parseIngredient` (Task 4).
- Produces:
  - `class RecipeParseException implements Exception { final String code; final String message; }` with `code == 'NO_RECIPE_FOUND'`.
  - `class RecipeParser { static Recipe parse(String html, {required String sourceUrl, DateTime Function()? now}); }` — throws `RecipeParseException` when no usable `Recipe` JSON-LD exists.

Mapping rules (§6): `@type` may be string or list, Recipe may nest in arrays/`@graph` — recurse. `author` may be Map/List/String/absent; empty → stored `''`. `image` string/list/ImageObject → first usable `http(s)` URL. `keywords` comma-separated string (or list) → lowercase, trimmed, deduped tags; **ignore `recipeCategory`**. `recipeInstructions` string / `HowToStep[]` / `HowToSection[]` (real shape) → flattened step texts. Zero-total durations → null.

- [ ] **Step 1: Create the synthetic fixtures**

Create `test/fixtures/block_page.html` (models the 184-byte non-browser-UA block):

```html
<!DOCTYPE html><html><head><title>chefkoch.de</title></head><body>Access denied.</body></html>
```

Create `test/fixtures/synthetic_variants.html` — exercises every alternate shape absent from the real pages (`@graph` nesting, `@type` as list, string instructions, `PT`-style durations, `ImageObject` image, keywords as list, deleted author, unparseable yield):

```html
<!DOCTYPE html>
<html>
<head>
<script type="application/ld+json">
{"@context": "https://schema.org", "@type": "Organization", "name": "Not a recipe"}
</script>
<script type="application/ld+json">
{ this block is deliberately malformed JSON }
</script>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {"@type": "WebPage", "name": "wrapper"},
    {
      "@type": ["Recipe", "Thing"],
      "name": "Synthetisches Testrezept",
      "author": {"@type": "Person", "name": "Gelöschter Benutzer"},
      "recipeYield": "Portionen",
      "prepTime": "PT15M",
      "totalTime": "PT45M",
      "image": {"@type": "ImageObject", "url": "https://img.chefkoch-cdn.de/synthetic.jpg"},
      "aggregateRating": {"@type": "AggregateRating", "ratingValue": "3.5"},
      "keywords": ["Einfach", "einfach", "Pasta"],
      "recipeCategory": "Kochen",
      "recipeIngredient": ["2 EL Butter", "Salz"],
      "recipeInstructions": "Butter schmelzen.\nSalzen.\n\nServieren."
    }
  ]
}
</script>
</head>
<body>Synthetic page</body>
</html>
```

- [ ] **Step 2: Write the failing test**

Create `test/parser/recipe_parser_test.dart`:

```dart
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
          sourceUrl: 'https://www.chefkoch.de/rezepte/1064631211795001/Knusprige-Ofenkartoffeln.html');
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

    test('finds Recipe inside @graph with list @type, skipping non-recipe and malformed blocks', () {
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
      () => RecipeParser.parse(fixture('block_page.html'), sourceUrl: 'https://www.chefkoch.de/x'),
      throwsA(isA<RecipeParseException>()
          .having((e) => e.code, 'code', 'NO_RECIPE_FOUND')),
    );
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/parser/recipe_parser_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 4: Write the implementation**

Create `lib/src/parser/recipe_parser.dart`:

```dart
import 'dart:convert';

import '../models/recipe.dart';
import 'ingredient_parser.dart';
import 'scalar_parsers.dart';

class RecipeParseException implements Exception {
  final String code;
  final String message;
  const RecipeParseException(this.code, this.message);

  @override
  String toString() => 'RecipeParseException($code): $message';
}

/// Extracts the schema.org/Recipe JSON-LD from a Chefkoch HTML page and
/// normalizes it into a [Recipe]. Pure Dart, no platform dependencies (§6).
class RecipeParser {
  static Recipe parse(String html, {required String sourceUrl, DateTime Function()? now}) {
    final data = _findRecipeObject(html);
    if (data == null) {
      throw const RecipeParseException(
          'NO_RECIPE_FOUND', 'No schema.org/Recipe JSON-LD found on the page.');
    }
    return Recipe(
      sourceUrl: sourceUrl,
      title: (data['name'] as String?)?.trim() ?? '',
      author: _author(data['author']),
      imageUrl: _imageUrl(data['image']),
      baseServings: parseServings(data['recipeYield']),
      prepMinutes: parseIso8601DurationToMinutes(data['prepTime'] as String?),
      cookMinutes: parseIso8601DurationToMinutes(data['cookTime'] as String?),
      totalMinutes: parseIso8601DurationToMinutes(data['totalTime'] as String?),
      rating: _rating(data['aggregateRating']),
      ingredients: [
        for (final item in (data['recipeIngredient'] as List? ?? []))
          if (item is String) parseIngredient(item)
      ],
      steps: _steps(data['recipeInstructions']),
      tags: _tags(data['keywords']),
      importedAt: (now ?? DateTime.now)(),
    );
  }

  static Map<String, dynamic>? _findRecipeObject(String html) {
    final scripts = RegExp(
      r'''<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in scripts.allMatches(html)) {
      final Object? decoded;
      try {
        decoded = jsonDecode(match[1]!.trim());
      } on FormatException {
        continue; // malformed block — try the next one
      }
      final recipe = _recurseForRecipe(decoded);
      if (recipe != null) return recipe;
    }
    return null;
  }

  /// `@type` may be a string or a list; the Recipe may sit in an array or
  /// under `@graph` — recurse through maps and lists (§6 step 1).
  static Map<String, dynamic>? _recurseForRecipe(Object? node) {
    if (node is Map<String, dynamic>) {
      final type = node['@type'];
      if (type == 'Recipe' || (type is List && type.contains('Recipe'))) {
        return node;
      }
      for (final value in node.values) {
        final found = _recurseForRecipe(value);
        if (found != null) return found;
      }
    }
    if (node is List) {
      for (final value in node) {
        final found = _recurseForRecipe(value);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String _author(Object? node) {
    if (node is String) return node.trim();
    if (node is Map) return (node['name'] as String?)?.trim() ?? '';
    if (node is List && node.isNotEmpty) return _author(node.first);
    return '';
  }

  static String? _imageUrl(Object? node) {
    if (node is String && node.startsWith('http')) return node;
    if (node is Map) return _imageUrl(node['url']);
    if (node is List) {
      for (final item in node) {
        final url = _imageUrl(item);
        if (url != null) return url;
      }
    }
    return null;
  }

  static double? _rating(Object? node) {
    if (node is! Map) return null;
    final value = node['ratingValue'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String> _steps(Object? node) {
    if (node is String) {
      return node
          .split(RegExp(r'\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (node is List) {
      final steps = <String>[];
      for (final element in node) {
        if (element is String) {
          if (element.trim().isNotEmpty) steps.add(element.trim());
        } else if (element is Map) {
          final type = element['@type'];
          final isSection = type == 'HowToSection' || (type is List && type.contains('HowToSection'));
          if (isSection) {
            steps.addAll(_steps(element['itemListElement']));
          } else {
            final text = element['text'];
            if (text is String && text.trim().isNotEmpty) steps.add(text.trim());
          }
        }
      }
      return steps;
    }
    return [];
  }

  static List<String> _tags(Object? node) {
    Iterable<String> parts;
    if (node is String) {
      parts = node.split(',');
    } else if (node is List) {
      parts = node.whereType<String>();
    } else {
      return [];
    }
    final seen = <String>{};
    return [
      for (final part in parts)
        if (part.trim().isNotEmpty && seen.add(part.trim().toLowerCase()))
          part.trim().toLowerCase()
    ];
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/parser/recipe_parser_test.dart
```
Expected: PASS. If an ingredient-count or first-step assertion fails, inspect the actual fixture JSON-LD (`python3 -c "..."` extraction) and fix the **parser**, not the assertion, unless the assertion contradicts the fixture ground truth listed in Global Constraints.

- [ ] **Step 6: Run the full suite and commit**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test
git add lib/src/parser/recipe_parser.dart test/parser/recipe_parser_test.dart test/fixtures/synthetic_variants.html test/fixtures/block_page.html
git commit -m "feat: parse Chefkoch JSON-LD into normalized recipes"
```

---

### Task 6: Drift database + FTS5 + `LocalRecipeRepository`

**Files:**
- Create: `lib/src/db/database.dart` (generates `lib/src/db/database.g.dart`)
- Create: `lib/src/repository/recipe_repository.dart`
- Create: `lib/src/repository/local_recipe_repository.dart`
- Test: `test/repository/local_recipe_repository_test.dart`

**Interfaces:**
- Consumes: `Recipe`, `Ingredient` (Task 2).
- Produces:
  - `class AppDatabase extends _$AppDatabase { AppDatabase(super.e); }` — tables `Recipes` (columns per §5, `sourceUrl` unique) and `RecipeTags`; FTS5 virtual table `recipe_fts(title, tags, ingredients)` with `unicode61 remove_diacritics 2`, rowid = recipe id.
  - `enum TagMode { seedIfNew, replace }`
  - `abstract class RecipeRepository` with exactly:
    ```dart
    Stream<List<Recipe>> watchRecipes({String query = '', Set<String> tags = const {}});
    Stream<Recipe?> watchRecipe(int id);
    Future<Recipe?> getRecipe(int id);
    Future<List<Recipe>> getAllRecipes();
    Future<int> saveRecipe(Recipe recipe, {TagMode tagMode = TagMode.seedIfNew});
    Future<void> deleteRecipe(int id);
    Future<void> setTags(int recipeId, List<String> tags);
    Stream<List<String>> watchAllTags();
    ```
  - `class LocalRecipeRepository implements RecipeRepository { LocalRecipeRepository(AppDatabase db); }`

Semantics: `saveRecipe` upserts by `sourceUrl`; `seedIfNew` keeps existing tags on overwrite, `replace` always writes `recipe.tags`. Tag filter is **AND** across selected tags (§8). Search tokens get FTS5 prefix matching (`"token"*`), results ordered by `rank`; empty query orders by `imported_at DESC`. Every insert/update/delete/setTags rewrites the FTS row in the same transaction.

- [ ] **Step 1: Write the database schema**

Create `lib/src/db/database.dart`:

```dart
import 'package:drift/drift.dart';

part 'database.g.dart';

class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceUrl => text().unique()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get baseServings => integer().nullable()();
  IntColumn get prepMinutes => integer().nullable()();
  IntColumn get cookMinutes => integer().nullable()();
  IntColumn get totalMinutes => integer().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get ingredientsJson => text()();
  TextColumn get stepsJson => text()();
  TextColumn get importedAt => text()();
  IntColumn get schemaVersion => integer()();
}

class RecipeTags extends Table {
  IntColumn get recipeId =>
      integer().references(Recipes, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {recipeId, tag};
}

@DriftDatabase(tables: [Recipes, RecipeTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            "CREATE VIRTUAL TABLE recipe_fts USING fts5("
            "title, tags, ingredients, "
            "tokenize = 'unicode61 remove_diacritics 2')",
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
```

- [ ] **Step 2: Run code generation**

```bash
export PATH="$HOME/flutter/bin:$PATH" && dart run build_runner build --delete-conflicting-outputs
```
Expected: `database.g.dart` generated, exit 0.

- [ ] **Step 3: Write the failing repository test**

Create `test/repository/local_recipe_repository_test.dart`:

```dart
import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/models/recipe.dart';
import 'package:cookbook/src/repository/local_recipe_repository.dart';
import 'package:cookbook/src/repository/recipe_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe makeRecipe({
  String sourceUrl = 'https://www.chefkoch.de/rezepte/1/test.html',
  String title = 'Käsespätzle',
  List<String> tags = const ['hauptspeise', 'pasta'],
  List<Ingredient> ingredients = const [
    Ingredient(amount: 500, unit: 'g', name: 'Spätzle', raw: '500 g Spätzle'),
    Ingredient(amount: 200, unit: 'g', name: 'Bergkäse', raw: '200 g Bergkäse'),
  ],
}) =>
    Recipe(
      sourceUrl: sourceUrl,
      title: title,
      author: 'tester',
      baseServings: 2,
      ingredients: ingredients,
      steps: const ['Kochen.', 'Essen.'],
      tags: tags,
      importedAt: DateTime.utc(2026, 7, 7),
    );

void main() {
  late AppDatabase db;
  late LocalRecipeRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalRecipeRepository(db);
  });

  tearDown(() => db.close());

  test('saveRecipe inserts and getRecipe round-trips all fields', () async {
    final id = await repo.saveRecipe(makeRecipe());
    final loaded = await repo.getRecipe(id);
    expect(loaded, isNotNull);
    expect(loaded!.title, 'Käsespätzle');
    expect(loaded.ingredients, hasLength(2));
    expect(loaded.ingredients.first.name, 'Spätzle');
    expect(loaded.steps, ['Kochen.', 'Essen.']);
    expect(loaded.tags, ['hauptspeise', 'pasta']);
    expect(loaded.baseServings, 2);
    expect(loaded.importedAt, DateTime.utc(2026, 7, 7));
  });

  test('saveRecipe with same sourceUrl overwrites and keeps existing tags by default', () async {
    final id1 = await repo.saveRecipe(makeRecipe());
    await repo.setTags(id1, ['meins']);
    final id2 = await repo.saveRecipe(makeRecipe(title: 'Käsespätzle v2', tags: ['neu']));
    expect(id2, id1);
    final loaded = await repo.getRecipe(id1);
    expect(loaded!.title, 'Käsespätzle v2');
    expect(loaded.tags, ['meins']); // user tags survive re-import (§2)
    expect(await repo.getAllRecipes(), hasLength(1));
  });

  test('saveRecipe with TagMode.replace overwrites tags (backup semantics §8)', () async {
    final id = await repo.saveRecipe(makeRecipe());
    await repo.saveRecipe(makeRecipe(tags: ['aus-backup']), tagMode: TagMode.replace);
    final loaded = await repo.getRecipe(id);
    expect(loaded!.tags, ['aus-backup']);
  });

  test('deleteRecipe removes recipe, tags, and search hits', () async {
    final id = await repo.saveRecipe(makeRecipe());
    await repo.deleteRecipe(id);
    expect(await repo.getRecipe(id), isNull);
    expect(await repo.watchRecipes(query: 'spätzle').first, isEmpty);
    expect(await repo.watchAllTags().first, isEmpty);
  });

  group('search (FTS5)', () {
    setUp(() async {
      await repo.saveRecipe(makeRecipe());
      await repo.saveRecipe(makeRecipe(
        sourceUrl: 'https://www.chefkoch.de/rezepte/2/lasagne.html',
        title: 'Lasagne',
        tags: ['nudeln'],
        ingredients: const [
          Ingredient(amount: 500, unit: 'g', name: 'Hackfleisch', raw: '500 g Hackfleisch'),
        ],
      ));
    });

    test('matches title with prefix', () async {
      final hits = await repo.watchRecipes(query: 'lasag').first;
      expect(hits.map((r) => r.title), ['Lasagne']);
    });

    test('is umlaut-tolerant (kase matches Käsespätzle)', () async {
      final hits = await repo.watchRecipes(query: 'kase').first;
      expect(hits.map((r) => r.title), ['Käsespätzle']);
    });

    test('matches ingredient names', () async {
      final hits = await repo.watchRecipes(query: 'hackfleisch').first;
      expect(hits.map((r) => r.title), ['Lasagne']);
    });

    test('matches tags and empty query returns everything', () async {
      expect((await repo.watchRecipes(query: 'nudeln').first).map((r) => r.title), ['Lasagne']);
      expect(await repo.watchRecipes().first, hasLength(2));
    });

    test('FTS reflects overwrite', () async {
      await repo.saveRecipe(makeRecipe(title: 'Umbenannt'));
      expect(await repo.watchRecipes(query: 'käsespätzle').first, isEmpty);
      expect((await repo.watchRecipes(query: 'umbenannt').first), hasLength(1));
    });

    test('search input with FTS metacharacters does not throw', () async {
      // Tokens are ANDed by FTS5, so this finds nothing — the assertion is
      // only that hostile input produces a valid (empty) result, not an error.
      expect(await repo.watchRecipes(query: '"AND" (x OR *) NEAR').first, isA<List>());
    });
  });

  group('tag filter', () {
    setUp(() async {
      await repo.saveRecipe(makeRecipe()); // tags: hauptspeise, pasta
      await repo.saveRecipe(makeRecipe(
        sourceUrl: 'https://www.chefkoch.de/rezepte/2/salat.html',
        title: 'Salat',
        tags: ['vegetarisch'],
      ));
      await repo.saveRecipe(makeRecipe(
        sourceUrl: 'https://www.chefkoch.de/rezepte/3/auflauf.html',
        title: 'Auflauf',
        tags: ['hauptspeise', 'vegetarisch'],
      ));
    });

    test('single tag filters', () async {
      final hits = await repo.watchRecipes(tags: {'vegetarisch'}).first;
      expect(hits.map((r) => r.title).toSet(), {'Salat', 'Auflauf'});
    });

    test('multiple tags are AND (§8)', () async {
      final hits = await repo.watchRecipes(tags: {'vegetarisch', 'hauptspeise'}).first;
      expect(hits.map((r) => r.title), ['Auflauf']);
    });

    test('tag filter combines with search term', () async {
      final hits = await repo.watchRecipes(query: 'auflauf', tags: {'hauptspeise'}).first;
      expect(hits.map((r) => r.title), ['Auflauf']);
    });

    test('watchAllTags returns sorted distinct tags', () async {
      expect(await repo.watchAllTags().first, ['hauptspeise', 'pasta', 'vegetarisch']);
    });
  });

  test('setTags normalizes to lowercase trimmed dedupe and updates search', () async {
    final id = await repo.saveRecipe(makeRecipe());
    await repo.setTags(id, [' Sommer ', 'sommer', 'GRILL']);
    final loaded = await repo.getRecipe(id);
    expect(loaded!.tags, ['grill', 'sommer']);
    expect((await repo.watchRecipes(query: 'grill').first), hasLength(1));
  });

  test('watchRecipe emits updates after setTags', () async {
    final id = await repo.saveRecipe(makeRecipe());
    expect((await repo.watchRecipe(id).first)!.tags, ['hauptspeise', 'pasta']);
    await repo.setTags(id, ['neu']);
    expect((await repo.watchRecipe(id).first)!.tags, ['neu']);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/repository/local_recipe_repository_test.dart
```
Expected: FAIL — repository URIs don't exist.

- [ ] **Step 5: Write the repository interface**

Create `lib/src/repository/recipe_repository.dart`:

```dart
import '../models/recipe.dart';

/// How [RecipeRepository.saveRecipe] treats tags when the recipe already
/// exists (matched by sourceUrl).
enum TagMode {
  /// URL re-import: keep the user's existing tags; recipe.tags only seed a
  /// brand-new recipe (§2 — tags are the user's only editable field).
  seedIfNew,

  /// Backup import: tags in the payload replace local tags (§8).
  replace,
}

/// The single seam between UI/services and storage (§4). A future
/// SyncedRecipeRepository plugs in here (§12).
abstract class RecipeRepository {
  Stream<List<Recipe>> watchRecipes({String query = '', Set<String> tags = const {}});
  Stream<Recipe?> watchRecipe(int id);
  Future<Recipe?> getRecipe(int id);
  Future<List<Recipe>> getAllRecipes();

  /// Upserts by [Recipe.sourceUrl] (§2 re-import = overwrite). Returns the row id.
  Future<int> saveRecipe(Recipe recipe, {TagMode tagMode = TagMode.seedIfNew});

  Future<void> deleteRecipe(int id);
  Future<void> setTags(int recipeId, List<String> tags);
  Stream<List<String>> watchAllTags();
}

List<String> normalizeTags(Iterable<String> tags) {
  final seen = <String>{};
  final result = [
    for (final tag in tags)
      if (tag.trim().isNotEmpty && seen.add(tag.trim().toLowerCase())) tag.trim().toLowerCase()
  ];
  result.sort();
  return result;
}
```

- [ ] **Step 6: Write the local implementation**

Create `lib/src/repository/local_recipe_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/recipe.dart' as model;
import 'recipe_repository.dart';

class LocalRecipeRepository implements RecipeRepository {
  final AppDatabase db;
  LocalRecipeRepository(this.db);

  @override
  Future<int> saveRecipe(model.Recipe recipe, {TagMode tagMode = TagMode.seedIfNew}) {
    return db.transaction(() async {
      final existing = await (db.select(db.recipes)
            ..where((r) => r.sourceUrl.equals(recipe.sourceUrl)))
          .getSingleOrNull();
      final companion = RecipesCompanion(
        sourceUrl: Value(recipe.sourceUrl),
        title: Value(recipe.title),
        author: Value(recipe.author),
        imageUrl: Value(recipe.imageUrl),
        baseServings: Value(recipe.baseServings),
        prepMinutes: Value(recipe.prepMinutes),
        cookMinutes: Value(recipe.cookMinutes),
        totalMinutes: Value(recipe.totalMinutes),
        rating: Value(recipe.rating),
        ingredientsJson: Value(recipe.ingredientsJson),
        stepsJson: Value(recipe.stepsJson),
        importedAt: Value(recipe.importedAt.toIso8601String()),
        schemaVersion: Value(recipe.schemaVersion),
      );

      final int id;
      final List<String> tags;
      if (existing == null) {
        id = await db.into(db.recipes).insert(companion);
        tags = normalizeTags(recipe.tags);
      } else {
        id = existing.id;
        await (db.update(db.recipes)..where((r) => r.id.equals(id))).write(companion);
        tags = tagMode == TagMode.replace
            ? normalizeTags(recipe.tags)
            : await _tagsFor(id);
      }
      await _writeTags(id, tags);
      await _writeFtsRow(id, recipe.title, tags, recipe.ingredients);
      return id;
    });
  }

  @override
  Future<void> deleteRecipe(int id) {
    return db.transaction(() async {
      await (db.delete(db.recipes)..where((r) => r.id.equals(id))).go();
      await db.customStatement('DELETE FROM recipe_fts WHERE rowid = ?', [id]);
    });
  }

  @override
  Future<void> setTags(int recipeId, List<String> tags) {
    return db.transaction(() async {
      final row = await (db.select(db.recipes)..where((r) => r.id.equals(recipeId)))
          .getSingleOrNull();
      if (row == null) return;
      final normalized = normalizeTags(tags);
      await _writeTags(recipeId, normalized);
      await _writeFtsRow(recipeId, row.title, normalized,
          model.Recipe.decodeIngredients(row.ingredientsJson));
      // Touch the recipe row so table watchers re-emit.
      await (db.update(db.recipes)..where((r) => r.id.equals(recipeId)))
          .write(RecipesCompanion(title: Value(row.title)));
    });
  }

  @override
  Future<model.Recipe?> getRecipe(int id) async {
    final row = await (db.select(db.recipes)..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _toModel(row, await _tagsFor(id));
  }

  @override
  Stream<model.Recipe?> watchRecipe(int id) {
    final stream = (db.select(db.recipes)..where((r) => r.id.equals(id))).watchSingleOrNull();
    return stream.asyncMap((row) async => row == null ? null : _toModel(row, await _tagsFor(id)));
  }

  @override
  Future<List<model.Recipe>> getAllRecipes() async {
    final rows = await (db.select(db.recipes)
          ..orderBy([(r) => OrderingTerm.desc(r.importedAt)]))
        .get();
    return _withTags(rows);
  }

  @override
  Stream<List<model.Recipe>> watchRecipes({String query = '', Set<String> tags = const {}}) {
    final match = _ftsMatchQuery(query);
    final variables = <Variable>[];
    var sql = 'SELECT r.* FROM recipes r';
    if (match != null) {
      sql += ' JOIN (SELECT rowid AS rid, rank FROM recipe_fts WHERE recipe_fts MATCH ?) f'
          ' ON f.rid = r.id';
      variables.add(Variable.withString(match));
    }
    if (tags.isNotEmpty) {
      final placeholders = List.filled(tags.length, '?').join(', ');
      sql += ' WHERE r.id IN (SELECT recipe_id FROM recipe_tags WHERE tag IN ($placeholders)'
          ' GROUP BY recipe_id HAVING COUNT(DISTINCT tag) = ${tags.length})';
      variables.addAll(tags.map(Variable.withString));
    }
    sql += match != null ? ' ORDER BY f.rank' : ' ORDER BY r.imported_at DESC';

    return db
        .customSelect(sql, variables: variables, readsFrom: {db.recipes, db.recipeTags})
        .watch()
        .asyncMap((rows) async {
      // TableInfo.map returns FutureOr — await each row explicitly.
      final mapped = <Recipe>[];
      for (final row in rows) {
        mapped.add(await db.recipes.map(row.data));
      }
      return _withTags(mapped);
    });
  }

  @override
  Stream<List<String>> watchAllTags() {
    return db
        .customSelect('SELECT DISTINCT tag FROM recipe_tags ORDER BY tag',
            readsFrom: {db.recipeTags})
        .watch()
        .map((rows) => rows.map((r) => r.read<String>('tag')).toList());
  }

  Future<List<String>> _tagsFor(int recipeId) async {
    final rows = await (db.select(db.recipeTags)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.asc(t.tag)]))
        .get();
    return rows.map((r) => r.tag).toList();
  }

  Future<void> _writeTags(int recipeId, List<String> tags) async {
    await (db.delete(db.recipeTags)..where((t) => t.recipeId.equals(recipeId))).go();
    for (final tag in tags) {
      await db.into(db.recipeTags).insert(RecipeTagsCompanion.insert(recipeId: recipeId, tag: tag));
    }
  }

  Future<void> _writeFtsRow(
      int id, String title, List<String> tags, List<model.Ingredient> ingredients) async {
    await db.customStatement('DELETE FROM recipe_fts WHERE rowid = ?', [id]);
    await db.customStatement(
      'INSERT INTO recipe_fts(rowid, title, tags, ingredients) VALUES (?, ?, ?, ?)',
      [id, title, tags.join(' '), ingredients.map((i) => i.name).join(' ')],
    );
  }

  Future<List<model.Recipe>> _withTags(List<Recipe> rows) async {
    if (rows.isEmpty) return [];
    final tagRows = await db.select(db.recipeTags).get();
    final byRecipe = <int, List<String>>{};
    for (final row in tagRows) {
      byRecipe.putIfAbsent(row.recipeId, () => []).add(row.tag);
    }
    return [
      for (final row in rows) _toModel(row, (byRecipe[row.id] ?? [])..sort()),
    ];
  }

  model.Recipe _toModel(Recipe row, List<String> tags) => model.Recipe(
        id: row.id,
        sourceUrl: row.sourceUrl,
        title: row.title,
        author: row.author,
        imageUrl: row.imageUrl,
        baseServings: row.baseServings,
        prepMinutes: row.prepMinutes,
        cookMinutes: row.cookMinutes,
        totalMinutes: row.totalMinutes,
        rating: row.rating,
        ingredients: model.Recipe.decodeIngredients(row.ingredientsJson),
        steps: model.Recipe.decodeSteps(row.stepsJson),
        tags: tags,
        importedAt: DateTime.parse(row.importedAt),
        schemaVersion: row.schemaVersion,
      );

  /// Turns free text into an FTS5 MATCH expression with per-token prefix
  /// matching; strips metacharacters by tokenizing on non-letter/digit.
  String? _ftsMatchQuery(String input) {
    final tokens = input
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    return tokens.map((t) => '"$t"*').join(' ');
  }
}
```

Note: the generated Drift row class is also called `Recipe` — that's why the model is imported `as model` here. Don't rename either class.

- [ ] **Step 7: Run test to verify it passes**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/repository/local_recipe_repository_test.dart
```
Expected: PASS. Known pitfall: if drift complains that `recipe_fts` is unknown in `customSelect`, it's because `readsFrom` only lists real tables — that's intentional; watching `recipes`/`recipeTags` is sufficient because every FTS write happens in a transaction that also touches `recipes`.

- [ ] **Step 8: Run full suite, analyze, commit**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter analyze && flutter test
git add lib/src/db/ lib/src/repository/ test/repository/
git commit -m "feat: add Drift database with FTS5 search and local repository"
```

---

### Task 7: URL validation + `ImportService`

**Files:**
- Create: `lib/src/import/url_validator.dart`
- Create: `lib/src/import/import_service.dart`
- Test: `test/import/url_validator_test.dart`, `test/import/import_service_test.dart`

**Interfaces:**
- Consumes: `RecipeParser`, `RecipeParseException` (Task 5); `RecipeRepository` (Task 6); `Recipe` (Task 2); `package:http`.
- Produces:
  - `class InvalidRecipeUrlException implements Exception { final String message; }`
  - `Uri resolveChefkochUrl(String text)` — extracts the first http(s) URL from shared text, validates host `chefkoch.de` or subdomain, returns https URL with query/fragment stripped; throws `InvalidRecipeUrlException`.
  - `const String kBrowserUserAgent` — the mobile Chrome UA string below.
  - `enum ImportError { invalidUrl, offline, blocked, noRecipeFound }`
  - `class ImportException implements Exception { final ImportError error; final String message; }`
  - `class ImportService { ImportService({required http.Client client, required RecipeRepository repository}); Future<Recipe> importFromText(String text); }` — returned `Recipe` has its DB `id` set.

- [ ] **Step 1: Write the failing URL validator test**

Create `test/import/url_validator_test.dart`:

```dart
import 'package:cookbook/src/import/url_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts plain chefkoch URLs and upgrades http to https', () {
    expect(resolveChefkochUrl('http://www.chefkoch.de/rezepte/1/x.html').toString(),
        'https://www.chefkoch.de/rezepte/1/x.html');
  });

  test('accepts bare domain and m. subdomain', () {
    expect(resolveChefkochUrl('https://chefkoch.de/rezepte/1/x.html').host, 'chefkoch.de');
    expect(resolveChefkochUrl('https://m.chefkoch.de/rezepte/1/x.html').host, 'm.chefkoch.de');
  });

  test('extracts the first URL from surrounding share text (§4 import flow)', () {
    final uri = resolveChefkochUrl(
        'Schau mal: https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html gefunden!');
    expect(uri.path, '/rezepte/745721177147257/Lasagne.html');
  });

  test('strips tracking params and fragments', () {
    final uri = resolveChefkochUrl(
        'https://www.chefkoch.de/rezepte/1/x.html?utm_source=share&portionen=4#kommentare');
    expect(uri.toString(), 'https://www.chefkoch.de/rezepte/1/x.html');
  });

  test('rejects non-chefkoch hosts including lookalikes', () {
    expect(() => resolveChefkochUrl('https://example.com/rezepte/1/x.html'),
        throwsA(isA<InvalidRecipeUrlException>()));
    expect(() => resolveChefkochUrl('https://notchefkoch.de/rezepte/1/x.html'),
        throwsA(isA<InvalidRecipeUrlException>()));
    expect(() => resolveChefkochUrl('https://chefkoch.de.evil.com/x'),
        throwsA(isA<InvalidRecipeUrlException>()));
  });

  test('rejects text without any URL', () {
    expect(() => resolveChefkochUrl('Lasagne wie beim Italiener'),
        throwsA(isA<InvalidRecipeUrlException>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/import/url_validator_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Implement the URL validator**

Create `lib/src/import/url_validator.dart`:

```dart
class InvalidRecipeUrlException implements Exception {
  final String message;
  const InvalidRecipeUrlException(this.message);

  @override
  String toString() => message;
}

/// Extracts the first http(s) URL from shared text, validates that it points
/// at chefkoch.de (or a subdomain), upgrades to https, and strips query
/// params and fragments (§4 import flow, steps 1-2).
Uri resolveChefkochUrl(String text) {
  final match = RegExp(r'https?://\S+').firstMatch(text);
  if (match == null) {
    throw const InvalidRecipeUrlException('No link found in the text.');
  }
  final candidate = match[0]!.replaceAll(RegExp(r'''[>"'.,;:!?)\]]+$'''), '');
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.host.isEmpty) {
    throw const InvalidRecipeUrlException('That link could not be read.');
  }
  final host = uri.host.toLowerCase();
  if (host != 'chefkoch.de' && !host.endsWith('.chefkoch.de')) {
    throw const InvalidRecipeUrlException('Only chefkoch.de links can be imported.');
  }
  return Uri(scheme: 'https', host: uri.host, path: uri.path);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/import/url_validator_test.dart
```
Expected: PASS.

- [ ] **Step 5: Write the failing ImportService test**

Create `test/import/import_service_test.dart` (uses `MockClient` from `package:http/testing.dart` and a real in-memory repository):

```dart
import 'dart:io';

import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/import/import_service.dart';
import 'package:cookbook/src/repository/local_recipe_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase db;
  late LocalRecipeRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalRecipeRepository(db);
  });

  tearDown(() => db.close());

  ImportService service(MockClient client) =>
      ImportService(client: client, repository: repo);

  test('fetches with browser UA, parses, saves, and returns recipe with id', () async {
    final html = File('test/fixtures/lasagne.html').readAsStringSync();
    String? sentUserAgent;
    final client = MockClient((request) async {
      sentUserAgent = request.headers['User-Agent'];
      expect(request.url.toString(),
          'https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html');
      return http.Response(html, 200, headers: {'content-type': 'text/html; charset=utf-8'});
    });

    final recipe = await service(client)
        .importFromText('https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html?utm_source=x');
    expect(sentUserAgent, kBrowserUserAgent);
    expect(sentUserAgent, contains('Chrome'));
    expect(recipe.id, isNotNull);
    expect(recipe.title, 'Lasagne - wie beim Italiener');
    expect((await repo.getRecipe(recipe.id!))!.title, 'Lasagne - wie beim Italiener');
  });

  test('invalid URL throws ImportError.invalidUrl without any request', () async {
    final client = MockClient((request) async => fail('must not fetch'));
    expect(
      () => service(client).importFromText('https://example.com/x'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.invalidUrl)),
    );
  });

  test('network failure throws ImportError.offline', () async {
    final client = MockClient((request) async => throw http.ClientException('no route'));
    expect(
      () => service(client).importFromText('https://www.chefkoch.de/rezepte/1/x.html'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.offline)),
    );
  });

  test('non-200 response throws ImportError.blocked', () async {
    final client = MockClient((request) async => http.Response('gone', 410));
    expect(
      () => service(client).importFromText('https://www.chefkoch.de/rezepte/1/x.html'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.blocked)),
    );
  });

  test('tiny block-page body throws ImportError.blocked (§6 failure modes)', () async {
    final blockPage = File('test/fixtures/block_page.html').readAsStringSync();
    final client = MockClient((request) async => http.Response(blockPage, 200));
    expect(
      () => service(client).importFromText('https://www.chefkoch.de/rezepte/1/x.html'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.blocked)),
    );
  });

  test('full page without recipe JSON-LD throws ImportError.noRecipeFound', () async {
    final bigNonRecipePage = '<html><body>${'x' * 5000}</body></html>';
    final client = MockClient((request) async => http.Response(bigNonRecipePage, 200));
    expect(
      () => service(client).importFromText('https://www.chefkoch.de/rezepte/1/x.html'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.noRecipeFound)),
    );
  });

  test('re-import of the same URL overwrites instead of duplicating (§2)', () async {
    final html = File('test/fixtures/lasagne.html').readAsStringSync();
    final client = MockClient((request) async => http.Response(html, 200));
    final first = await service(client)
        .importFromText('https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html');
    final second = await service(client)
        .importFromText('https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html');
    expect(second.id, first.id);
    expect(await repo.getAllRecipes(), hasLength(1));
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/import/import_service_test.dart
```
Expected: FAIL — `import_service.dart` does not exist.

- [ ] **Step 7: Implement ImportService**

Create `lib/src/import/import_service.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe.dart';
import '../parser/recipe_parser.dart';
import '../repository/recipe_repository.dart';
import 'url_validator.dart';

/// Verified necessary (§2): Chefkoch serves non-browser UAs a tiny block page.
const String kBrowserUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.6478.110 Mobile Safari/537.36';

enum ImportError { invalidUrl, offline, blocked, noRecipeFound }

class ImportException implements Exception {
  final ImportError error;
  final String message;
  const ImportException(this.error, this.message);

  @override
  String toString() => message;
}

/// One user action = one request (§3). Fetch → parse → save.
class ImportService {
  final http.Client client;
  final RecipeRepository repository;

  ImportService({required this.client, required this.repository});

  Future<Recipe> importFromText(String text) async {
    final Uri url;
    try {
      url = resolveChefkochUrl(text);
    } on InvalidRecipeUrlException catch (e) {
      throw ImportException(ImportError.invalidUrl, e.message);
    }

    final http.Response response;
    try {
      response = await client.get(url, headers: {
        'User-Agent': kBrowserUserAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-DE,de;q=0.9',
      });
    } catch (_) {
      throw const ImportException(
          ImportError.offline, 'Could not reach chefkoch.de. Check your connection.');
    }

    if (response.statusCode != 200) {
      throw ImportException(ImportError.blocked,
          'Chefkoch answered with HTTP ${response.statusCode}. Try again later.');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (body.length < 2048) {
      // Non-browser clients get a ~184-byte block page (§11).
      throw const ImportException(
          ImportError.blocked, 'Chefkoch served a block page instead of the recipe.');
    }

    final Recipe parsed;
    try {
      parsed = RecipeParser.parse(body, sourceUrl: url.toString());
    } on RecipeParseException {
      throw const ImportException(
          ImportError.noRecipeFound, 'No recipe was found on that page.');
    }

    final id = await repository.saveRecipe(parsed);
    return parsed.copyWith(id: id);
  }
}
```

- [ ] **Step 8: Run tests, analyze, commit**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter analyze && flutter test
git add lib/src/import/ test/import/
git commit -m "feat: add URL validation and import service with error taxonomy"
```

---

### Task 8: Serving scaler with German rounding rules

**Files:**
- Create: `lib/src/scaling/serving_scaler.dart`
- Test: `test/scaling/serving_scaler_test.dart`

**Interfaces:**
- Consumes: `Ingredient` (Task 2).
- Produces:
  - `class ServingScaler` with static methods:
    - `String formatNumber(double value, {required bool countable})` — §7 rounding: ≥10 → integer; 1–10 → 1 decimal; <1 → 2 decimals; comma separator; trailing zeros trimmed. Countable → nearest ½ rendered as `2 ½`/`½` (never `0` for a positive amount).
    - `bool isCountable(Ingredient ing)` — `unit == null || unit == 'Stück'`.
    - `String scaledLine(Ingredient ing, double factor)` — display line: `raw` when `amount == null` or `factor == 1.0` (original fidelity); otherwise `"<amount>[–<amountMax>][ <unit>] <name>"`.

- [ ] **Step 1: Write the failing test**

Create `test/scaling/serving_scaler_test.dart`:

```dart
import 'package:cookbook/src/models/recipe.dart';
import 'package:cookbook/src/scaling/serving_scaler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatNumber (non-countable, §7 rounding rules)', () {
    test('>= 10 rounds to integer', () {
      expect(ServingScaler.formatNumber(245.0, countable: false), '245');
      expect(ServingScaler.formatNumber(10.4, countable: false), '10');
      expect(ServingScaler.formatNumber(9.96, countable: false), '10');
    });
    test('1..10 rounds to 1 decimal with German comma', () {
      expect(ServingScaler.formatNumber(2.5, countable: false), '2,5');
      expect(ServingScaler.formatNumber(2.0, countable: false), '2');
      expect(ServingScaler.formatNumber(1.25, countable: false), '1,3');
    });
    test('< 1 rounds to 2 decimals', () {
      expect(ServingScaler.formatNumber(0.25, countable: false), '0,25');
      expect(ServingScaler.formatNumber(1 / 3, countable: false), '0,33');
      expect(ServingScaler.formatNumber(0.5, countable: false), '0,5');
    });
  });

  group('formatNumber (countable → nearest half, fractions)', () {
    test('renders halves as fractions, never decimals', () {
      expect(ServingScaler.formatNumber(2.66, countable: true), '2 ½');
      expect(ServingScaler.formatNumber(0.5, countable: true), '½');
      expect(ServingScaler.formatNumber(3.0, countable: true), '3');
      expect(ServingScaler.formatNumber(2.24, countable: true), '2');
    });
    test('a tiny positive amount never becomes 0', () {
      expect(ServingScaler.formatNumber(0.2, countable: true), '½');
    });
  });

  group('scaledLine', () {
    const spaghetti = Ingredient(amount: 500, unit: 'g', name: 'Spaghetti', raw: '500 g Spaghetti');
    const egg = Ingredient(amount: 2, name: 'Ei(er)', raw: '2 Ei(er) (Größe M)');
    const garlic = Ingredient(amount: 2, amountMax: 3, unit: 'Zehen', name: 'Knoblauch', raw: '2-3 Zehen Knoblauch');
    const salt = Ingredient(name: 'Salz', raw: 'Salz, nach Belieben');

    test('factor 1 shows the original raw text', () {
      expect(ServingScaler.scaledLine(spaghetti, 1.0), '500 g Spaghetti');
      expect(ServingScaler.scaledLine(egg, 1.0), '2 Ei(er) (Größe M)');
    });

    test('scales amount and keeps unit and name', () {
      expect(ServingScaler.scaledLine(spaghetti, 0.49), '245 g Spaghetti');
      expect(ServingScaler.scaledLine(spaghetti, 2.0), '1000 g Spaghetti');
    });

    test('ranges scale both bounds and render an en-dash (§5)', () {
      expect(ServingScaler.scaledLine(garlic, 2.0), '4–6 Zehen Knoblauch');
      expect(ServingScaler.scaledLine(garlic, 0.5), '1–1,5 Zehen Knoblauch');
    });

    test('countable ingredients render half-fractions (2,66 Eier never happens)', () {
      expect(ServingScaler.scaledLine(egg, 1.33), '2 ½ Ei(er)');
    });

    test('amount-less ingredients show raw unchanged at any factor', () {
      expect(ServingScaler.scaledLine(salt, 3.0), 'Salz, nach Belieben');
    });
  });
}
```

Note: `garlic` has unit `Zehen`, which is not countable — bounds use decimal rules (`1–1,5`). `egg` has no unit → countable.

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/scaling/serving_scaler_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/src/scaling/serving_scaler.dart`:

```dart
import '../models/recipe.dart';

/// Display-only serving scaling (§7). Never mutates stored data.
class ServingScaler {
  /// Bare counts and pieces get half-step rounding (§7: "2,66 → 2 ½,
  /// never 2,66 Ei(er)").
  static bool isCountable(Ingredient ing) => ing.unit == null || ing.unit == 'Stück';

  static String formatNumber(double value, {required bool countable}) {
    if (countable) {
      final halves = (value * 2).round();
      if (halves == 0) return value > 0 ? '½' : '0';
      final whole = halves ~/ 2;
      if (halves.isEven) return '$whole';
      return whole == 0 ? '½' : '$whole ½';
    }
    if (value >= 10) return value.round().toString();
    final decimals = value >= 1 ? 1 : 2;
    var text = value.toStringAsFixed(decimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text.replaceAll('.', ',');
  }

  /// One display line per ingredient. Original `raw` text is shown when there
  /// is nothing to scale (null amount) or nothing scaled (factor 1).
  static String scaledLine(Ingredient ing, double factor) {
    final amount = ing.amount;
    if (amount == null || factor == 1.0) return ing.raw;
    final countable = isCountable(ing);
    final low = formatNumber(amount * factor, countable: countable);
    final high = ing.amountMax == null
        ? ''
        : '–${formatNumber(ing.amountMax! * factor, countable: countable)}';
    final unit = ing.unit == null ? '' : ' ${ing.unit}';
    return '$low$high$unit ${ing.name}';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/scaling/serving_scaler_test.dart
```
Expected: PASS. If `formatNumber(1.25, countable: false)` yields `'1,2'` (banker's-rounding artifact of `toStringAsFixed`), change the assertion to `'1,2'` — either rounding of the half-step is acceptable; document with a comment.

- [ ] **Step 5: Commit**

```bash
git add lib/src/scaling/ test/scaling/
git commit -m "feat: add serving scaler with German rounding and fraction display"
```

---

### Task 9: JSON backup export/import (`BackupService`)

**Files:**
- Create: `lib/src/backup/backup_service.dart`
- Test: `test/backup/backup_service_test.dart`

**Interfaces:**
- Consumes: `RecipeRepository`, `TagMode` (Task 6); `Recipe`, `Ingredient` (Task 2).
- Produces:
  - `class BackupException implements Exception { final String message; }`
  - `class BackupImportResult { final int added; final int updated; }`
  - `class BackupService { BackupService(this.repository); final RecipeRepository repository; Future<String> exportJson({DateTime Function()? now}); Future<BackupImportResult> importJson(String jsonString); }`

Format exactly per §8: top-level `{app: "cookbook", format_version: 1, exported_at, recipes: [...]}`; recipe objects carry `source_url`, `title`, `author`, `image_url`, `base_servings`, `prep_minutes`, `cook_minutes`, `total_minutes`, `rating`, `schema_version`, `imported_at`, `ingredients` (the `{amount, amount_max, unit, name, raw}` objects), `steps`, `tags` — **no `id`**. Import: reject `format_version != 1` before writing anything; merge by `source_url` with `TagMode.replace`; never deletes local rows.

- [ ] **Step 1: Write the failing test**

Create `test/backup/backup_service_test.dart`:

```dart
import 'dart:convert';

import 'package:cookbook/src/backup/backup_service.dart';
import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/models/recipe.dart';
import 'package:cookbook/src/repository/local_recipe_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe makeRecipe(String url, String title, {List<String> tags = const ['pasta']}) => Recipe(
      sourceUrl: url,
      title: title,
      author: 'tester',
      imageUrl: 'https://img.chefkoch-cdn.de/x.jpg',
      baseServings: 2,
      prepMinutes: 15,
      rating: 4.5,
      ingredients: const [
        Ingredient(amount: 500, unit: 'g', name: 'Spaghetti', raw: '500 g Spaghetti'),
      ],
      steps: const ['Kochen.'],
      tags: tags,
      importedAt: DateTime.utc(2026, 7, 7, 9),
    );

void main() {
  late AppDatabase db;
  late LocalRecipeRepository repo;
  late BackupService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalRecipeRepository(db);
    service = BackupService(repo);
  });

  tearDown(() => db.close());

  test('export produces the §8 format without local ids', () async {
    await repo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/1/a.html', 'A'));
    final json = jsonDecode(await service.exportJson(now: () => DateTime.utc(2026, 7, 7, 10)))
        as Map<String, dynamic>;
    expect(json['app'], 'cookbook');
    expect(json['format_version'], 1);
    expect(json['exported_at'], '2026-07-07T10:00:00.000Z');
    final recipes = json['recipes'] as List;
    expect(recipes, hasLength(1));
    final r = recipes.first as Map<String, dynamic>;
    expect(r['source_url'], 'https://www.chefkoch.de/rezepte/1/a.html');
    expect(r['title'], 'A');
    expect(r['base_servings'], 2);
    expect(r['prep_minutes'], 15);
    expect(r['cook_minutes'], isNull);
    expect(r['rating'], 4.5);
    expect(r['schema_version'], 1);
    expect(r['imported_at'], '2026-07-07T09:00:00.000Z');
    expect(r['tags'], ['pasta']);
    expect((r['ingredients'] as List).first,
        {'amount': 500.0, 'amount_max': null, 'unit': 'g', 'name': 'Spaghetti', 'raw': '500 g Spaghetti'});
    expect(r['steps'], ['Kochen.']);
    expect(r.containsKey('id'), isFalse);
  });

  test('import merges by source_url: adds new, overwrites existing incl. tags, keeps local-only', () async {
    await repo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/1/a.html', 'A lokal'));
    await repo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/2/b.html', 'B lokal'));

    final otherDb = AppDatabase(NativeDatabase.memory());
    final otherRepo = LocalRecipeRepository(otherDb);
    await otherRepo.saveRecipe(
        makeRecipe('https://www.chefkoch.de/rezepte/1/a.html', 'A aus Backup', tags: ['backup']));
    await otherRepo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/3/c.html', 'C neu'));
    final exported = await BackupService(otherRepo).exportJson();
    await otherDb.close();

    final result = await service.importJson(exported);
    expect(result.added, 1);
    expect(result.updated, 1);

    final all = await repo.getAllRecipes();
    expect(all.map((r) => r.title).toSet(), {'A aus Backup', 'B lokal', 'C neu'});
    final a = all.firstWhere((r) => r.sourceUrl.endsWith('/1/a.html'));
    expect(a.tags, ['backup']); // backup import replaces tags (§8)
  });

  test('round-trip export → import is lossless', () async {
    await repo.saveRecipe(makeRecipe('https://www.chefkoch.de/rezepte/1/a.html', 'A'));
    final exported = await service.exportJson();
    final db2 = AppDatabase(NativeDatabase.memory());
    final repo2 = LocalRecipeRepository(db2);
    await BackupService(repo2).importJson(exported);
    final restored = (await repo2.getAllRecipes()).single;
    final original = (await repo.getAllRecipes()).single;
    expect(restored.title, original.title);
    expect(restored.ingredients, original.ingredients);
    expect(restored.steps, original.steps);
    expect(restored.tags, original.tags);
    expect(restored.importedAt, original.importedAt);
    await db2.close();
  });

  test('unknown format_version is rejected without partial import (§8)', () async {
    final bad = jsonEncode({'app': 'cookbook', 'format_version': 99, 'recipes': [{'source_url': 'x', 'title': 'x'}]});
    expect(() => service.importJson(bad), throwsA(isA<BackupException>()));
    expect(await repo.getAllRecipes(), isEmpty);
  });

  test('garbage input is rejected with BackupException', () async {
    expect(() => service.importJson('not json'), throwsA(isA<BackupException>()));
    expect(() => service.importJson('{"foo": 1}'), throwsA(isA<BackupException>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/backup/backup_service_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/src/backup/backup_service.dart`:

```dart
import 'dart:convert';

import '../models/recipe.dart';
import '../repository/recipe_repository.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

class BackupImportResult {
  final int added;
  final int updated;
  const BackupImportResult({required this.added, required this.updated});
}

/// Manual JSON export/import of the whole collection (§8) — the safety net
/// against a lost device and the migration format for future cloud sync.
class BackupService {
  final RecipeRepository repository;
  BackupService(this.repository);

  Future<String> exportJson({DateTime Function()? now}) async {
    final recipes = await repository.getAllRecipes();
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'cookbook',
      'format_version': 1,
      'exported_at': (now ?? DateTime.now)().toUtc().toIso8601String(),
      'recipes': [for (final r in recipes) _toJson(r)],
    });
  }

  Future<BackupImportResult> importJson(String jsonString) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException {
      throw const BackupException('That file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic> || decoded['recipes'] is! List) {
      throw const BackupException('That file is not a Cookbook backup.');
    }
    if (decoded['format_version'] != 1) {
      throw BackupException(
          'Unsupported backup version (${decoded['format_version']}). Update the app and try again.');
    }

    // Parse everything first so a bad entry rejects the file before any write.
    final recipes = <Recipe>[];
    for (final entry in decoded['recipes'] as List) {
      if (entry is! Map<String, dynamic>) {
        throw const BackupException('That file contains an invalid recipe entry.');
      }
      recipes.add(_fromJson(entry));
    }

    final existingUrls = (await repository.getAllRecipes()).map((r) => r.sourceUrl).toSet();
    var added = 0;
    var updated = 0;
    for (final recipe in recipes) {
      existingUrls.contains(recipe.sourceUrl) ? updated++ : added++;
      await repository.saveRecipe(recipe, tagMode: TagMode.replace);
    }
    return BackupImportResult(added: added, updated: updated);
  }

  Map<String, dynamic> _toJson(Recipe r) => {
        'source_url': r.sourceUrl,
        'title': r.title,
        'author': r.author,
        'image_url': r.imageUrl,
        'base_servings': r.baseServings,
        'prep_minutes': r.prepMinutes,
        'cook_minutes': r.cookMinutes,
        'total_minutes': r.totalMinutes,
        'rating': r.rating,
        'schema_version': r.schemaVersion,
        'imported_at': r.importedAt.toIso8601String(),
        'ingredients': [for (final i in r.ingredients) i.toJson()],
        'steps': r.steps,
        'tags': r.tags,
      };

  Recipe _fromJson(Map<String, dynamic> json) {
    final sourceUrl = json['source_url'];
    final title = json['title'];
    if (sourceUrl is! String || sourceUrl.isEmpty || title is! String) {
      throw const BackupException('That file contains a recipe without source_url or title.');
    }
    return Recipe(
      sourceUrl: sourceUrl,
      title: title,
      author: json['author'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      baseServings: json['base_servings'] as int?,
      prepMinutes: json['prep_minutes'] as int?,
      cookMinutes: json['cook_minutes'] as int?,
      totalMinutes: json['total_minutes'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
      ingredients: [
        for (final i in json['ingredients'] as List? ?? [])
          Ingredient.fromJson(i as Map<String, dynamic>)
      ],
      steps: (json['steps'] as List? ?? []).cast<String>(),
      tags: (json['tags'] as List? ?? []).cast<String>(),
      importedAt: DateTime.tryParse(json['imported_at'] as String? ?? '') ?? DateTime.now(),
      schemaVersion: json['schema_version'] as int? ?? kCurrentSchemaVersion,
    );
  }
}
```

- [ ] **Step 4: Run tests, analyze, commit**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter analyze && flutter test
git add lib/src/backup/ test/backup/
git commit -m "feat: add JSON backup export/import with merge-by-source-url"
```

---

### Task 10: Riverpod providers, app entry, Recipe List screen

**Files:**
- Create: `lib/src/providers.dart`, `lib/src/ui/recipe_list_screen.dart`
- Modify: `lib/main.dart` (replace template)
- Test: `test/ui/recipe_list_screen_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 2–9.
- Produces (in `lib/src/providers.dart`):
  ```dart
  final databaseProvider = Provider<AppDatabase>(...);        // drift_flutter file DB
  final recipeRepositoryProvider = Provider<RecipeRepository>(...);
  final httpClientProvider = Provider<http.Client>(...);
  final importServiceProvider = Provider<ImportService>(...);
  final backupServiceProvider = Provider<BackupService>(...);
  final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(...);   // .set(String)
  final selectedTagsProvider = NotifierProvider<SelectedTagsNotifier, Set<String>>(...); // .toggle(String)
  final recipeListProvider = StreamProvider<List<Recipe>>(...);
  final allTagsProvider = StreamProvider<List<String>>(...);
  final recipeDetailProvider = StreamProvider.family<Recipe?, int>(...);
  ```
- Produces (UI): `class CookbookApp extends StatelessWidget` in `main.dart`; `class RecipeListScreen extends ConsumerWidget` with search bar, tag filter chips, recipe cards navigating to `RecipeDetailScreen(recipeId: ...)`, FAB navigating to `ImportScreen()`, and an overflow menu with `Export backup` / `Import backup` (wired in Task 13; in this task the menu calls placeholder no-op callbacks passed as optional constructor params — **define the constructor now**: `RecipeListScreen({this.onExport, this.onImport})` — no, keep it simpler: the menu items are added in Task 13; this task ships without the menu).

Note: Tasks 11 (`RecipeDetailScreen`) and 12 (`ImportScreen`) don't exist yet. In this task create both files as minimal placeholders so navigation compiles:
- `lib/src/ui/recipe_detail_screen.dart`: `class RecipeDetailScreen extends StatelessWidget { final int recipeId; const RecipeDetailScreen({super.key, required this.recipeId}); @override Widget build(context) => const Scaffold(body: Center(child: Text('TODO detail'))); }`
- `lib/src/ui/import_screen.dart`: `class ImportScreen extends StatelessWidget { final String? initialSharedText; const ImportScreen({super.key, this.initialSharedText}); @override Widget build(context) => const Scaffold(body: Center(child: Text('TODO import'))); }`
These placeholders are replaced by Tasks 11/12 (this is the one sanctioned use of placeholder screens; their constructors are final).

- [ ] **Step 1: Write the failing widget test**

Create `test/ui/recipe_list_screen_test.dart`:

```dart
import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/models/recipe.dart';
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

  Widget app() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RecipeListScreen()),
      );

  testWidgets('shows empty state when no recipes exist', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('No recipes yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('lists recipes and filters via tag chip', (tester) async {
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final repo = container.read(recipeRepositoryProvider);
    await repo.saveRecipe(Recipe(
      sourceUrl: 'https://www.chefkoch.de/rezepte/1/a.html',
      title: 'Lasagne',
      author: 'x',
      ingredients: const [],
      steps: const [],
      tags: const ['pasta'],
      importedAt: DateTime.utc(2026, 7, 7),
    ));
    await repo.saveRecipe(Recipe(
      sourceUrl: 'https://www.chefkoch.de/rezepte/2/b.html',
      title: 'Salat',
      author: 'x',
      ingredients: const [],
      steps: const [],
      tags: const ['leicht'],
      importedAt: DateTime.utc(2026, 7, 7),
    ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: RecipeListScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lasagne'), findsOneWidget);
    expect(find.text('Salat'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'pasta'));
    await tester.pumpAndSettle();
    expect(find.text('Lasagne'), findsOneWidget);
    expect(find.text('Salat'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test test/ui/recipe_list_screen_test.dart
```
Expected: FAIL — URIs don't exist.

- [ ] **Step 3: Write providers**

Create `lib/src/providers.dart`:

```dart
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'backup/backup_service.dart';
import 'db/database.dart';
import 'import/import_service.dart';
import 'models/recipe.dart';
import 'repository/local_recipe_repository.dart';
import 'repository/recipe_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'cookbook'));
  ref.onDispose(db.close);
  return db;
});

final recipeRepositoryProvider = Provider<RecipeRepository>(
    (ref) => LocalRecipeRepository(ref.watch(databaseProvider)));

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final importServiceProvider = Provider<ImportService>((ref) => ImportService(
      client: ref.watch(httpClientProvider),
      repository: ref.watch(recipeRepositoryProvider),
    ));

final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService(ref.watch(recipeRepositoryProvider)));

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SelectedTagsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void toggle(String tag) =>
      state = state.contains(tag) ? ({...state}..remove(tag)) : {...state, tag};
}

final selectedTagsProvider =
    NotifierProvider<SelectedTagsNotifier, Set<String>>(SelectedTagsNotifier.new);

final recipeListProvider = StreamProvider<List<Recipe>>((ref) {
  return ref.watch(recipeRepositoryProvider).watchRecipes(
        query: ref.watch(searchQueryProvider),
        tags: ref.watch(selectedTagsProvider),
      );
});

final allTagsProvider = StreamProvider<List<String>>(
    (ref) => ref.watch(recipeRepositoryProvider).watchAllTags());

final recipeDetailProvider = StreamProvider.family<Recipe?, int>(
    (ref, id) => ref.watch(recipeRepositoryProvider).watchRecipe(id));
```

- [ ] **Step 4: Write list screen, placeholder screens, and main.dart**

Create `lib/src/ui/recipe_detail_screen.dart` and `lib/src/ui/import_screen.dart` placeholders exactly as specified in Interfaces above.

Create `lib/src/ui/recipe_list_screen.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../providers.dart';
import 'import_screen.dart';
import 'recipe_detail_screen.dart';

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipeListProvider);
    final tags = ref.watch(allTagsProvider).value ?? const <String>[];
    final selectedTags = ref.watch(selectedTagsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cookbook')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ImportScreen())),
        tooltip: 'Import recipe',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              hintText: 'Search recipes',
              leading: const Icon(Icons.search),
              onChanged: (value) => ref.read(searchQueryProvider.notifier).set(value),
            ),
          ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final tag in tags)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag),
                          selected: selectedTags.contains(tag),
                          onSelected: (_) =>
                              ref.read(selectedTagsProvider.notifier).toggle(tag),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: recipes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Something went wrong: $error')),
              data: (list) {
                if (list.isEmpty) {
                  final filtered = query.isNotEmpty || selectedTags.isNotEmpty;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(filtered ? Icons.search_off : Icons.menu_book_outlined, size: 56),
                        const SizedBox(height: 12),
                        Text(filtered ? 'No matching recipes' : 'No recipes yet',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          filtered
                              ? 'Try a different search or clear the tag filter.'
                              : 'Tap + to import your first recipe from chefkoch.de.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) => _RecipeCard(recipe: list[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: recipe.imageUrl == null
              ? const Icon(Icons.restaurant)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: recipe.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.restaurant),
                  ),
                ),
        ),
        title: Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: recipe.tags.isEmpty ? null : Text(recipe.tags.join(' · ')),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id!))),
      ),
    );
  }
}
```

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/ui/recipe_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: CookbookApp()));
}

class CookbookApp extends StatelessWidget {
  const CookbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cookbook',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const RecipeListScreen(),
    );
  }
}
```

- [ ] **Step 5: Run tests, analyze, commit**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter analyze && flutter test
```
Expected: all pass. Pitfall: if the widget test hangs on `pumpAndSettle`, the `CircularProgressIndicator` from `StreamProvider`'s loading state may animate forever — replace `pumpAndSettle()` after `pumpWidget` with `await tester.pump(); await tester.pump(const Duration(milliseconds: 100));`.

```bash
git add lib/main.dart lib/src/providers.dart lib/src/ui/ test/ui/
git commit -m "feat: add Riverpod wiring and recipe list screen with search and tag filter"
```

---

### Task 11: Recipe Detail screen with serving scaler and tag editor

**Files:**
- Create: `lib/src/ui/tag_editor_sheet.dart`
- Modify: `lib/src/ui/recipe_detail_screen.dart` (replace placeholder; constructor unchanged)

**Interfaces:**
- Consumes: `recipeDetailProvider`, `recipeRepositoryProvider`, `allTagsProvider` (Task 10); `ServingScaler` (Task 8); `url_launcher`.
- Produces:
  - `class RecipeDetailScreen extends ConsumerStatefulWidget { final int recipeId; }` — image header, title, author + tappable source link, times row, rating, tag chips + edit button, serving stepper (hidden when `baseServings == null`), scaled ingredient list, numbered steps, delete action with confirmation.
  - `Future<void> showTagEditorSheet(BuildContext context, WidgetRef ref, Recipe recipe)` in `tag_editor_sheet.dart`.

This task is UI-only; the scaling/repository logic it calls is already fully unit-tested. Verification is `flutter analyze` + full test suite + manual review of the code against the checklist below (device verification happens in Task 13).

- [ ] **Step 1: Implement the tag editor sheet**

Create `lib/src/ui/tag_editor_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../providers.dart';

/// Tags are the only editable field (§2).
Future<void> showTagEditorSheet(BuildContext context, WidgetRef ref, Recipe recipe) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: _TagEditor(recipe: recipe, ref: ref),
    ),
  );
}

class _TagEditor extends StatefulWidget {
  final Recipe recipe;
  final WidgetRef ref;
  const _TagEditor({required this.recipe, required this.ref});

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  late final List<String> _tags = [...widget.recipe.tags];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String value) {
    final tag = value.trim().toLowerCase();
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _controller.clear();
    });
  }

  Future<void> _save() async {
    await widget.ref
        .read(recipeRepositoryProvider)
        .setTags(widget.recipe.id!, _tags);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = (widget.ref.read(allTagsProvider).value ?? const <String>[])
        .where((t) => !_tags.contains(t))
        .toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit tags', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final tag in _tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                ),
            ],
          ),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Add a tag'),
            textInputAction: TextInputAction.done,
            onSubmitted: _add,
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in suggestions.take(12))
                  ActionChip(label: Text(tag), onPressed: () => _add(tag)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the detail screen**

Replace `lib/src/ui/recipe_detail_screen.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe.dart';
import '../providers.dart';
import '../scaling/serving_scaler.dart';
import 'tag_editor_sheet.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final int recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _targetServings;

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('"${recipe.title}" will be removed from your collection.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(recipeRepositoryProvider).deleteRecipe(recipe.id!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final recipe = recipeAsync.value;
    if (recipe == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final base = recipe.baseServings;
    final target = _targetServings ?? base;
    final factor = (base != null && target != null) ? target / base : 1.0;
    final author = recipe.author.isEmpty || recipe.author == 'Gelöschter Benutzer'
        ? 'Unknown author'
        : recipe.author;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete recipe',
            onPressed: () => _confirmDelete(recipe),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (recipe.imageUrl != null)
            CachedNetworkImage(
              imageUrl: recipe.imageUrl!,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                  height: 220, child: Center(child: CircularProgressIndicator())),
              errorWidget: (_, __, ___) => const SizedBox(
                  height: 120, child: Center(child: Icon(Icons.restaurant, size: 48))),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                InkWell(
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (recipe.prepMinutes != null)
                      _InfoItem(icon: Icons.timer_outlined, text: 'Prep ${_formatMinutes(recipe.prepMinutes!)}'),
                    if (recipe.cookMinutes != null)
                      _InfoItem(icon: Icons.soup_kitchen_outlined, text: 'Cook ${_formatMinutes(recipe.cookMinutes!)}'),
                    if (recipe.totalMinutes != null)
                      _InfoItem(icon: Icons.schedule, text: 'Total ${_formatMinutes(recipe.totalMinutes!)}'),
                    if (recipe.rating != null)
                      _InfoItem(icon: Icons.star, text: recipe.rating!.toStringAsFixed(1).replaceAll('.', ',')),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final tag in recipe.tags) Chip(label: Text(tag)),
                    ActionChip(
                      avatar: const Icon(Icons.edit, size: 18),
                      label: Text(recipe.tags.isEmpty ? 'Add tags' : 'Edit'),
                      onPressed: () => showTagEditorSheet(context, ref, recipe),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Ingredients', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    // Serving scaler is hidden entirely when yield is unknown (§7).
                    if (base != null) ...[
                      IconButton(
                        onPressed: target! > 1
                            ? () => setState(() => _targetServings = target - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$target servings',
                          style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        onPressed: target < 99
                            ? () => setState(() => _targetServings = target + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                for (final ingredient in recipe.ingredients)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 8),
                          child: Icon(Icons.circle, size: 6),
                        ),
                        Expanded(child: Text(ServingScaler.scaledLine(ingredient, factor))),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text('Steps', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final (index, step) in recipe.steps.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 12, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(step)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(text)],
    );
  }
}
```

- [ ] **Step 3: Verify against the design checklist**

Confirm each §7 detail-screen requirement is present in the code: image ✓, title ✓, source link + attribution ✓, times ✓, ingredients ✓, steps ✓, scaler hidden when `baseServings == null` ✓ (the `if (base != null)` guard), scaler display-only ✓ (only `_targetServings` state changes), delete ✓, tag editing ✓.

- [ ] **Step 4: Analyze, run suite, commit**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter analyze && flutter test
git add lib/src/ui/recipe_detail_screen.dart lib/src/ui/tag_editor_sheet.dart
git commit -m "feat: add recipe detail screen with serving scaler and tag editor"
```

---

### Task 12: Import screen + Android share target

**Files:**
- Modify: `lib/src/ui/import_screen.dart` (replace placeholder; constructor unchanged)
- Create: `lib/src/share/share_intent_handler.dart`
- Modify: `lib/main.dart` (wire shared text to the import screen)
- Modify: `android/app/src/main/AndroidManifest.xml` (share intent-filter)
- Modify: `android/app/src/main/kotlin/dev/cookbook/cookbook/MainActivity.kt`

**Interfaces:**
- Consumes: `importServiceProvider` (Task 10); `ImportException`/`ImportError` (Task 7); `RecipeDetailScreen` (Task 11).
- Produces:
  - `class ImportScreen extends ConsumerStatefulWidget { final String? initialSharedText; }` — URL field, Import button, progress state, per-`ImportError` messages, auto-starts when `initialSharedText` is provided, navigates to the detail screen on success (replacing itself).
  - `class ShareIntentHandler { static Future<String?> getInitialSharedText(); static void listen(void Function(String) onSharedText); }` over MethodChannel `app.cookbook/share`.

- [ ] **Step 1: Implement the import screen**

Replace `lib/src/ui/import_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/import_service.dart';
import '../providers.dart';
import 'recipe_detail_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  final String? initialSharedText;
  const ImportScreen({super.key, this.initialSharedText});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialSharedText ?? '');
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialSharedText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _import());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _importing) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final recipe = await ref.read(importServiceProvider).importFromText(text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipeId: recipe.id!)));
    } on ImportException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Import failed unexpectedly: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import recipe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paste a chefkoch.de recipe link, or share one straight '
                'from the Chefkoch app or your browser.'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Recipe link',
                hintText: 'https://www.chefkoch.de/rezepte/…',
                border: const OutlineInputBorder(),
                errorText: _error,
                errorMaxLines: 3,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _import(),
              enabled: !_importing,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(_importing ? 'Importing…' : 'Import'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Importing needs an internet connection. Everything you have '
              'imported stays available offline.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the Dart share handler and wire it in main.dart**

Create `lib/src/share/share_intent_handler.dart`:

```dart
import 'package:flutter/services.dart';

/// Receives text shared into the app from Android's share sheet (§7 screen 3).
class ShareIntentHandler {
  static const MethodChannel _channel = MethodChannel('app.cookbook/share');

  /// Text the app was launched with (cold start via share), or null.
  static Future<String?> getInitialSharedText() async {
    try {
      return await _channel.invokeMethod<String>('getInitialSharedText');
    } on MissingPluginException {
      return null; // non-Android platforms and tests
    }
  }

  /// Text shared while the app is already running.
  static void listen(void Function(String) onSharedText) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        onSharedText(call.arguments as String);
      }
    });
  }
}
```

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/share/share_intent_handler.dart';
import 'src/ui/import_screen.dart';
import 'src/ui/recipe_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: CookbookApp()));
}

class CookbookApp extends StatefulWidget {
  const CookbookApp({super.key});

  @override
  State<CookbookApp> createState() => _CookbookAppState();
}

class _CookbookAppState extends State<CookbookApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    ShareIntentHandler.listen(_openImport);
    ShareIntentHandler.getInitialSharedText().then((text) {
      if (text != null) _openImport(text);
    });
  }

  void _openImport(String sharedText) {
    _navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => ImportScreen(initialSharedText: sharedText)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cookbook',
      navigatorKey: _navigatorKey,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const RecipeListScreen(),
    );
  }
}
```

- [ ] **Step 3: Add the Android share target**

In `android/app/src/main/AndroidManifest.xml`, inside the `<activity android:name=".MainActivity" ...>` element (next to the existing MAIN/LAUNCHER intent-filter), add:

```xml
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
```

Replace `android/app/src/main/kotlin/dev/cookbook/cookbook/MainActivity.kt`:

```kotlin
package dev.cookbook.cookbook

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.cookbook/share")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialSharedText") {
                result.success(extractSharedText(intent))
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent)
        if (text != null) {
            channel?.invokeMethod("sharedText", text)
        }
    }

    private fun extractSharedText(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain")
            intent.getStringExtra(Intent.EXTRA_TEXT)
        else null
}
```

- [ ] **Step 4: Analyze, run suite, commit**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter analyze && flutter test
git add lib/main.dart lib/src/ui/import_screen.dart lib/src/share/ android/app/src/main/
git commit -m "feat: add import screen and Android share target"
```

---

### Task 13: Backup UI, Android SDK licenses, APK build, final verification

**Files:**
- Modify: `lib/src/ui/recipe_list_screen.dart` (add overflow menu with backup actions)
- Possibly modify: `$HOME/Android/Sdk` (cmdline-tools install — system-level, not committed)

**Interfaces:**
- Consumes: `backupServiceProvider` (Task 10); `BackupService`, `BackupException`, `BackupImportResult` (Task 9); `share_plus`, `file_picker`, `path_provider`.
- Produces: `Export backup` / `Import backup` menu on the list screen; a built APK at `build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 1: Add the backup menu to the list screen**

In `lib/src/ui/recipe_list_screen.dart` add imports at the top:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../backup/backup_service.dart';
```

In `RecipeListScreen.build`, change the `AppBar` to:

```dart
      appBar: AppBar(
        title: const Text('Cookbook'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) => action == 'export'
                ? _exportBackup(context, ref)
                : _importBackup(context, ref),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Export backup')),
              PopupMenuItem(value: 'import', child: Text('Import backup')),
            ],
          ),
        ],
      ),
```

Add these methods to `RecipeListScreen` (below `build`):

```dart
  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await ref.read(backupServiceProvider).exportJson();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().split('T').first;
      final file = File('${dir.path}/cookbook-backup-$stamp.json');
      await file.writeAsString(json);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await FilePicker.platform.pickFiles(withData: true);
      final bytes = picked?.files.single.bytes;
      if (bytes == null) return; // user cancelled
      final result = await ref.read(backupServiceProvider).importJson(utf8.decode(bytes));
      messenger.showSnackBar(SnackBar(
          content: Text('Backup imported: ${result.added} added, ${result.updated} updated.')));
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
```

Note: if the installed share_plus major version predates the `SharePlus.instance` API, use `Share.shareXFiles([XFile(file.path, mimeType: 'application/json')])` instead — check with `grep -A1 'share_plus' pubspec.lock`.

- [ ] **Step 2: Run analyze and the full test suite**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter analyze && flutter test
```
Expected: no issues, all tests pass.

- [ ] **Step 3: Fix the Android SDK (cmdline-tools + licenses)**

`flutter doctor` reported missing cmdline-tools and unaccepted licenses. Locate the SDK first:

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter doctor -v 2>&1 | grep -i 'android sdk at' || ls ~/Android/Sdk
```

Install cmdline-tools into the SDK root found above (adjust `SDK` accordingly):

```bash
SDK=$HOME/Android/Sdk
curl -L -o /tmp/clt.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
mkdir -p "$SDK/cmdline-tools"
unzip -q /tmp/clt.zip -d "$SDK/cmdline-tools"
mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --licenses
export PATH="$HOME/flutter/bin:$PATH" && flutter doctor
```
Expected: `[✓] Android toolchain`. If the download URL 404s (Google rotates versions), find the current one at https://developer.android.com/studio#command-line-tools-only.

- [ ] **Step 4: Build the APK**

```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter build apk
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`. First Gradle run downloads dependencies — allow up to 10 minutes (`timeout: 600000`).

Verify the applicationId inside the built APK:

```bash
"$HOME/Android/Sdk/build-tools/$(ls "$HOME/Android/Sdk/build-tools" | sort -V | tail -1)/aapt" dump badging build/app/outputs/flutter-apk/app-release.apk | head -2
```
Expected: `package: name='dev.cookbook.app'`.

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/recipe_list_screen.dart
git commit -m "feat: add JSON backup export/import UI and finalize Android build"
```

- [ ] **Step 6: Final spec sweep**

Walk DESIGN.md §1 goals and confirm each ships: import by URL ✓ (Task 7/12), local storage ✓ (Task 6), offline reading ✓ (local DB), view/delete ✓ (Tasks 10/11), search ✓ (Task 6/10), tags ✓ (Tasks 6/11), serving scaling ✓ (Tasks 8/11), JSON backup ✓ (Tasks 9/13), share-target ✓ (Task 12), attribution + source link ✓ (Task 11). Report any gap instead of claiming completion.
