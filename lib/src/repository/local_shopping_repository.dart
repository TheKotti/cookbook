import 'package:drift/drift.dart';

// The generated drift row class is also called ShoppingItem — the domain
// model from models/ wins in this file.
import '../db/database.dart' hide ShoppingItem;
import '../models/shopping_item.dart';
import 'shopping_repository.dart';

class LocalShoppingRepository implements ShoppingRepository {
  final AppDatabase db;
  LocalShoppingRepository(this.db);

  @override
  Stream<List<ShoppingItem>> watchItems() {
    final query = db.select(db.shoppingItems)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return query.watch().map((rows) => [
          for (final row in rows)
            ShoppingItem(
              id: row.id,
              text: row.content,
              createdAt: DateTime.parse(row.createdAt),
            ),
        ]);
  }

  @override
  Future<int> addItem(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return -1;
    return db.into(db.shoppingItems).insert(ShoppingItemsCompanion.insert(
        content: trimmed, createdAt: DateTime.now().toIso8601String()));
  }

  @override
  Future<void> updateItem(int id, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await (db.update(db.shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(content: Value(trimmed)));
  }

  @override
  Future<void> removeItem(int id) async {
    await (db.delete(db.shoppingItems)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> clearAll() async {
    await db.delete(db.shoppingItems).go();
  }
}
