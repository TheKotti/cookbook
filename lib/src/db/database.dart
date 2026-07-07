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
