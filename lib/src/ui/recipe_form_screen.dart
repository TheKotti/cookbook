import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
  late String? _localImagePath = widget.existing?.localImagePath;
  final List<String> _orphanedPaths = [];
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

  Future<void> _pickImage(ImageSource source) async {
    final pickedPath = await ref.read(imagePickProvider)(source);
    if (pickedPath == null) return;
    final saved = await ref.read(imageStoreProvider).save(pickedPath);
    setState(() {
      if (_localImagePath != null) _orphanedPaths.add(_localImagePath!);
      _localImagePath = saved;
    });
  }

  void _showPhotoChooser() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() {
      if (_localImagePath != null) _orphanedPaths.add(_localImagePath!);
      _localImagePath = null;
    });
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

  // A recipe needs at least one real ingredient; `#` section headers alone
  // don't count (v1.3).
  String? _requireIngredient(String? value) =>
      (value ?? '').split('\n').any((l) {
        final line = l.trim();
        return line.isNotEmpty && !line.startsWith('#');
      })
      ? null
      : 'Add at least one ingredient';

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
        localImagePath: _localImagePath,
      );
      final id = await ref.read(recipeRepositoryProvider).saveRecipe(recipe);
      if (_orphanedPaths.isNotEmpty) {
        final store = ref.read(imageStoreProvider);
        for (final orphan in _orphanedPaths) {
          if (orphan != _localImagePath) await store.delete(orphan);
        }
        _orphanedPaths.clear();
      }
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
              // Not a lazy ListView: every form field must stay attached so
              // FormState.validate() covers fields scrolled out of view.
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_localImagePath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              ref
                                  .read(imageStoreProvider)
                                  .resolve(_localImagePath!),
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(
                                height: 120,
                                child: Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                          )
                        else if (widget.existing?.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: widget.existing!.imageUrl!,
                              height: 180,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const SizedBox(
                                height: 120,
                                child: Center(child: Icon(Icons.restaurant)),
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _showPhotoChooser,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: Text(
                                _localImagePath == null
                                    ? 'Add photo'
                                    : 'Change',
                              ),
                            ),
                            if (_localImagePath != null)
                              TextButton.icon(
                                onPressed: _removeImage,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                            validator: (v) => _optionalInt(
                              v,
                              message: 'Enter a whole number',
                            ),
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
                            validator: (v) => _optionalInt(
                              v,
                              message: 'Enter a whole number',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ingredients,
                      decoration: const InputDecoration(
                        labelText: 'Ingredients (one per line)',
                        hintText:
                            '# Klopse\n500 g Hackfleisch\n2 Eier\n# Sauce\n40 g Butter',
                        helperText: 'Start a line with # to add a section '
                            'header (e.g. # Sauce).',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      minLines: 5,
                      maxLines: 12,
                      validator: _requireIngredient,
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
