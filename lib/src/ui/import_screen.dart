import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/import_service.dart';
import '../providers.dart';
import 'recipe_detail_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  final String? initialSharedText;
  const ImportScreen({super.key, this.initialSharedText});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialSharedText ?? '');
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialSharedText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _import());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _importing) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final recipe = await ref.read(importServiceProvider).importFromText(text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipeId: recipe.id!)));
    } on ImportException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Import failed unexpectedly: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import recipe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paste a chefkoch.de recipe link, or share one straight '
                'from the Chefkoch app or your browser.'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Recipe link',
                hintText: 'https://www.chefkoch.de/rezepte/…',
                border: const OutlineInputBorder(),
                errorText: _error,
                errorMaxLines: 3,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _import(),
              enabled: !_importing,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(_importing ? 'Importing…' : 'Import'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Importing needs an internet connection. Everything you have '
              'imported stays available offline.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
