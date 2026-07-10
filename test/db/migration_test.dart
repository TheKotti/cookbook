import 'dart:io';

import 'package:cookbook/src/db/database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw;

/// Builds an on-disk database with the exact v1 schema and one recipe row,
/// then opens it with the current AppDatabase to exercise onUpgrade.
void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('cookbook_mig'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  File createV1Database() {
    final file = File(p.join(tempDir.path, 'v1.db'));
    final db = raw.sqlite3.open(file.path);
    db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        image_url TEXT,
        base_servings INTEGER,
        prep_minutes INTEGER,
        cook_minutes INTEGER,
        total_minutes INTEGER,
        rating REAL,
        ingredients_json TEXT NOT NULL,
        steps_json TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        schema_version INTEGER NOT NULL
      )''');
    db.execute('''
      CREATE TABLE recipe_tags (
        recipe_id INTEGER NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
        tag TEXT NOT NULL,
        PRIMARY KEY (recipe_id, tag)
      )''');
    db.execute("CREATE VIRTUAL TABLE recipe_fts USING fts5("
        "title, tags, ingredients, tokenize = 'unicode61 remove_diacritics 2')");
    db.execute("INSERT INTO recipes (source_url, title, author, ingredients_json,"
        " steps_json, imported_at, schema_version) VALUES"
        " ('https://www.chefkoch.de/rezepte/1/a.html', 'Alt', 'x', '[]', '[]',"
        " '2026-07-07T00:00:00.000Z', 1)");
    db.execute('PRAGMA user_version = 1');
    db.dispose();
    return file;
  }

  test('v1 database upgrades to v2: new column and table exist, data survives', () async {
    final file = createV1Database();
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    // Old row survives and the new column reads as null.
    final rows = await db.select(db.recipes).get();
    expect(rows.single.title, 'Alt');
    expect(rows.single.localImagePath, null);

    // New table is usable.
    final id = await db.into(db.shoppingItems).insert(
        ShoppingItemsCompanion.insert(content: 'Milch', createdAt: '2026-07-10T00:00:00.000Z'));
    expect(id, 1);
  });

  test('fresh v2 database has shopping_items and local_image_path from onCreate', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.shoppingItems).insert(
        ShoppingItemsCompanion.insert(content: 'Brot', createdAt: '2026-07-10T00:00:00.000Z'));
    expect((await db.select(db.shoppingItems).get()).single.content, 'Brot');
    await db.into(db.recipes).insert(RecipesCompanion.insert(
          sourceUrl: 'manual:1',
          title: 't',
          author: '',
          ingredientsJson: '[]',
          stepsJson: '[]',
          importedAt: '2026-07-10T00:00:00.000Z',
          schemaVersion: 1,
          localImagePath: const Value('images/x.jpg'),
        ));
    expect((await db.select(db.recipes).get()).single.localImagePath, 'images/x.jpg');
  });
}
