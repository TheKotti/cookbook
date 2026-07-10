class ShoppingItem {
  final int id;
  final String text;
  final DateTime createdAt;

  const ShoppingItem({required this.id, required this.text, required this.createdAt});

  @override
  bool operator ==(Object other) =>
      other is ShoppingItem && other.id == id && other.text == text && other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, text, createdAt);

  @override
  String toString() => 'ShoppingItem($id, $text)';
}
