import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../providers.dart';
import '../scaling/serving_scaler.dart';
import 'recipe_form_screen.dart';
import 'tag_editor_sheet.dart';
import 'widgets/recipe_image.dart';

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
        content: Text(
          '"${recipe.title}" will be removed from your collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final localImagePath = recipe.localImagePath;
      await ref.read(recipeRepositoryProvider).deleteRecipe(recipe.id!);
      if (localImagePath != null) {
        await ref.read(imageStoreProvider).delete(localImagePath);
      }
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
    final author =
        recipe.author.isEmpty || recipe.author == 'Gelöschter Benutzer'
        ? 'Unknown author'
        : recipe.author;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit recipe',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeFormScreen(existing: recipe),
              ),
            ),
          ),
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
          if (recipe.localImagePath != null || recipe.imageUrl != null)
            RecipeImage(recipe: recipe, height: 220, width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text('By $author'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (recipe.prepMinutes != null)
                      _InfoItem(
                        icon: Icons.timer_outlined,
                        text: 'Prep ${_formatMinutes(recipe.prepMinutes!)}',
                      ),
                    if (recipe.cookMinutes != null)
                      _InfoItem(
                        icon: Icons.soup_kitchen_outlined,
                        text: 'Cook ${_formatMinutes(recipe.cookMinutes!)}',
                      ),
                    if (recipe.totalMinutes != null)
                      _InfoItem(
                        icon: Icons.schedule,
                        text: 'Total ${_formatMinutes(recipe.totalMinutes!)}',
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        tooltip: 'Rate $star of 5',
                        icon: Icon(
                          star <= (recipe.rating ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () =>
                            ref.read(recipeRepositoryProvider).setRating(
                                  recipe.id!,
                                  recipe.rating == star.toDouble()
                                      ? null
                                      : star.toDouble(),
                                ),
                      ),
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
                    Text(
                      'Ingredients',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    // Serving scaler is hidden entirely when yield is unknown (§7).
                    if (base != null) ...[
                      IconButton(
                        onPressed: target! > 1
                            ? () => setState(() => _targetServings = target - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$target servings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                        Expanded(
                          child: Text(
                            ServingScaler.scaledLine(ingredient, factor),
                          ),
                        ),
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
                        CircleAvatar(
                          radius: 12,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
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
