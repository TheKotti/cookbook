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
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id!))),
      ),
    );
  }
}
