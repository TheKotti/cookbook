import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/repository/local_shopping_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalShoppingRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalShoppingRepository(db);
  });

  tearDown(() => db.close());

  test('addItem trims, watchItems keeps insertion order', () async {
    await repo.addItem('  500 g Spaghetti ');
    await repo.addItem('Parmesan');
    final items = await repo.watchItems().first;
    expect(items.map((i) => i.text), ['500 g Spaghetti', 'Parmesan']);
    expect(items.first.id, lessThan(items.last.id));
  });

  test('empty or whitespace text is ignored and returns -1', () async {
    expect(await repo.addItem('   '), -1);
    expect(await repo.watchItems().first, isEmpty);
  });

  test('updateItem changes text; empty update is a no-op', () async {
    final id = await repo.addItem('Milch');
    await repo.updateItem(id, ' Hafermilch ');
    expect((await repo.watchItems().first).single.text, 'Hafermilch');
    await repo.updateItem(id, '  ');
    expect((await repo.watchItems().first).single.text, 'Hafermilch');
  });

  test('removeItem removes one; clearAll removes everything', () async {
    final a = await repo.addItem('A');
    await repo.addItem('B');
    await repo.removeItem(a);
    expect((await repo.watchItems().first).map((i) => i.text), ['B']);
    await repo.clearAll();
    expect(await repo.watchItems().first, isEmpty);
  });

  test('duplicates are kept as separate rows (no merging, spec §5)', () async {
    await repo.addItem('Salz');
    await repo.addItem('Salz');
    expect(await repo.watchItems().first, hasLength(2));
  });
}
