import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../manual/manual_recipe.dart';
import '../models/recipe.dart';
import '../providers.dart';
import 'recipe_detail_screen.dart';

/// Create (existing == null) or edit (existing != null) a recipe by hand.
/// Tags are edited on the detail screen, not here.
class RecipeFormScreen extends ConsumerStatefulWidget {
  final Recipe? existing;
  const RecipeFormScreen({super.key, this.existing});

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _servings;
  late final TextEditingController _prep;
  late final TextEditingController _cook;
  late final TextEditingController _ingredients;
  late final TextEditingController _steps;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _author = TextEditingController(text: widget.existing?.author ?? '');
    _servings = TextEditingController(
      text: widget.existing?.baseServings?.toString() ?? '',
    );
    _prep = TextEditingController(
      text: widget.existing?.prepMinutes?.toString() ?? '',
    );
    _cook = TextEditingController(
      text: widget.existing?.cookMinutes?.toString() ?? '',
    );
    _ingredients = TextEditingController(
      text: widget.existing?.ingredients.map((i) => i.raw).join('\n') ?? '',
    );
    _steps = TextEditingController(
      text: widget.existing?.steps.join('\n') ?? '',
    );
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _author,
      _servings,
      _prep,
      _cook,
      _ingredients,
      _steps,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optionalInt(String? value, {int min = 0, required String message}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final n = int.tryParse(text);
    return (n == null || n < min) ? message : null;
  }

  String? _requiredLines(String? value, String message) =>
      (value ?? '').split('\n').any((l) => l.trim().isNotEmpty)
      ? null
      : message;

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final recipe = buildManualRecipe(
        existing: widget.existing,
        title: _title.text,
        author: _author.text,
        servings: int.tryParse(_servings.text.trim()),
        prepMinutes: int.tryParse(_prep.text.trim()),
        cookMinutes: int.tryParse(_cook.text.trim()),
        ingredientsText: _ingredients.text,
        stepsText: _steps.text,
      );
      final id = await ref.read(recipeRepositoryProvider).saveRecipe(recipe);
      if (!mounted) return;
      if (widget.existing == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the recipe: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit recipe' : 'Add recipe')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _author,
                    decoration: const InputDecoration(
                      labelText: 'Author (optional)',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _servings,
                          decoration: const InputDecoration(
                            labelText: 'Servings',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => _optionalInt(
                            v,
                            min: 1,
                            message: 'Enter a whole number of 1 or more',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _prep,
                          decoration: const InputDecoration(
                            labelText: 'Prep time (min)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              _optionalInt(v, message: 'Enter a whole number'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cook,
                          decoration: const InputDecoration(
                            labelText: 'Cook time (min)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              _optionalInt(v, message: 'Enter a whole number'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ingredients,
                    decoration: const InputDecoration(
                      labelText: 'Ingredients (one per line)',
                      hintText: '200 g Mehl\n2 Eier\n1 Prise Salz',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 5,
                    maxLines: 12,
                    validator: (v) =>
                        _requiredLines(v, 'Add at least one ingredient'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _steps,
                    decoration: const InputDecoration(
                      labelText: 'Steps (one per line)',
                      hintText:
                          'Mix the dry ingredients.\nAdd the eggs and stir.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 5,
                    maxLines: 20,
                    validator: (v) =>
                        _requiredLines(v, 'Add at least one step'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
