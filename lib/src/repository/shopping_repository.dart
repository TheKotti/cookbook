import '../models/shopping_item.dart';

/// One global shopping list (spec §5). Checking off an item removes it —
/// there is no persisted "done" state.
abstract class ShoppingRepository {
  /// Items in insertion order (id ASC).
  Stream<List<ShoppingItem>> watchItems();

  /// Trims [text]; an empty result inserts nothing and returns -1.
  Future<int> addItem(String text);

  /// Trims [text]; an empty result leaves the item unchanged.
  Future<void> updateItem(int id, String text);

  Future<void> removeItem(int id);
  Future<void> clearAll();
}
