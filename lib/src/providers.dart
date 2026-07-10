import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'backup/backup_service.dart';
import 'db/database.dart' show AppDatabase;
import 'images/image_store.dart';
import 'import/import_service.dart';
import 'models/recipe.dart';
import 'models/shopping_item.dart';
import 'repository/local_recipe_repository.dart';
import 'repository/local_shopping_repository.dart';
import 'repository/recipe_repository.dart';
import 'repository/shopping_repository.dart';

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

/// Real value is injected in main() (and in tests) because resolving the
/// documents directory is async platform work.
final imageStoreProvider = Provider<ImageStore>(
    (ref) => throw UnimplementedError('imageStoreProvider must be overridden'));

/// Returns the picked file's path, or null when the user cancels.
final imagePickProvider = Provider<Future<String?> Function(ImageSource source)>(
    (ref) => (source) async =>
        (await ImagePicker().pickImage(source: source, maxWidth: 1600))?.path);

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
    (ref) => LocalShoppingRepository(ref.watch(databaseProvider)));

final shoppingItemsProvider = StreamProvider<List<ShoppingItem>>(
    (ref) => ref.watch(shoppingRepositoryProvider).watchItems());
