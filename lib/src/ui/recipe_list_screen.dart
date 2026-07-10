import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../backup/backup_service.dart';
import '../models/recipe.dart';
import '../providers.dart';
import 'import_screen.dart';
import 'recipe_detail_screen.dart';
import 'recipe_form_screen.dart';
import 'widgets/recipe_image.dart';

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipeListProvider);
    final tags = ref.watch(allTagsProvider).value ?? const <String>[];
    final selectedTags = ref.watch(selectedTagsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context),
        tooltip: 'Add recipe',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              hintText: 'Search recipes',
              leading: const Icon(Icons.search),
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).set(value),
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
                          onSelected: (_) => ref
                              .read(selectedTagsProvider.notifier)
                              .toggle(tag),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: recipes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Something went wrong: $error')),
              data: (list) {
                if (list.isEmpty) {
                  final filtered = query.isNotEmpty || selectedTags.isNotEmpty;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filtered
                              ? Icons.search_off
                              : Icons.menu_book_outlined,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          filtered ? 'No matching recipes' : 'No recipes yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          filtered
                              ? 'Try a different search or clear the tag filter.'
                              : 'Tap + to import a recipe from chefkoch.de or add one manually.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      _RecipeCard(recipe: list[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ImportScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Add manually'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecipeFormScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
      final picked = await FilePicker.pickFiles();
      final file = picked?.files.single;
      if (file == null) return; // user cancelled
      final bytes = await file.readAsBytes();
      final result = await ref
          .read(backupServiceProvider)
          .importJson(utf8.decode(bytes));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Backup imported: ${result.added} added, ${result.updated} updated.',
          ),
        ),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: RecipeImage(recipe: recipe, width: 56, height: 56, iconSize: 28),
          ),
        ),
        title: Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: recipe.tags.isEmpty ? null : Text(recipe.tags.join(' · ')),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id!),
          ),
        ),
      ),
    );
  }
}
