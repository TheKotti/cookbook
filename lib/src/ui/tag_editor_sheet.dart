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
    await widget.ref.read(recipeRepositoryProvider).setTags(widget.recipe.id!, _tags);
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
