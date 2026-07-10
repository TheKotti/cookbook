import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shopping_item.dart';
import '../providers.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await ref.read(shoppingRepositoryProvider).addItem(_input.text);
    _input.clear();
    _inputFocus.requestFocus(); // rapid entry
  }

  Future<void> _edit(ShoppingItem item) async {
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => _EditItemDialog(initialText: item.text),
    );
    if (newText != null) {
      await ref.read(shoppingRepositoryProvider).updateItem(item.id, newText);
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear the shopping list?'),
        content: const Text('All items will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(shoppingRepositoryProvider).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        ref.watch(shoppingItemsProvider).value ?? const <ShoppingItem>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping list'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _confirmClearAll(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear all')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Your shopping list is empty. Add items from a recipe, '
                        'or type one below.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Checkbox(
                          value: false,
                          onChanged: (_) => ref
                              .read(shoppingRepositoryProvider)
                              .removeItem(item.id),
                        ),
                        title: Text(item.text),
                        onTap: () => _edit(item),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      decoration:
                          const InputDecoration(hintText: 'Add an item'),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _add,
                    tooltip: 'Add item',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns its TextEditingController so it outlives the dialog's exit animation
/// (disposing it from the caller right after pop crashes the closing route).
class _EditItemDialog extends StatefulWidget {
  final String initialText;
  const _EditItemDialog({required this.initialText});

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit item'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
