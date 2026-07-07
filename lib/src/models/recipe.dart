import 'dart:convert';

const int kCurrentSchemaVersion = 1;

class Ingredient {
  final double? amount;
  final double? amountMax;
  final String? unit;
  final String name;
  final String raw;

  const Ingredient({
    this.amount,
    this.amountMax,
    this.unit,
    required this.name,
    required this.raw,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'amount_max': amountMax,
        'unit': unit,
        'name': name,
        'raw': raw,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        amount: (json['amount'] as num?)?.toDouble(),
        amountMax: (json['amount_max'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        name: json['name'] as String? ?? '',
        raw: json['raw'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.amount == amount &&
      other.amountMax == amountMax &&
      other.unit == unit &&
      other.name == name &&
      other.raw == raw;

  @override
  int get hashCode => Object.hash(amount, amountMax, unit, name, raw);

  @override
  String toString() =>
      'Ingredient(amount: $amount, amountMax: $amountMax, unit: $unit, name: $name, raw: $raw)';
}

class Recipe {
  final int? id;
  final String sourceUrl;
  final String title;
  final String author;
  final String? imageUrl;
  final int? baseServings;
  final int? prepMinutes;
  final int? cookMinutes;
  final int? totalMinutes;
  final double? rating;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final DateTime importedAt;
  final int schemaVersion;

  const Recipe({
    this.id,
    required this.sourceUrl,
    required this.title,
    required this.author,
    this.imageUrl,
    this.baseServings,
    this.prepMinutes,
    this.cookMinutes,
    this.totalMinutes,
    this.rating,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.importedAt,
    this.schemaVersion = kCurrentSchemaVersion,
  });

  Recipe copyWith({int? id, List<String>? tags}) => Recipe(
        id: id ?? this.id,
        sourceUrl: sourceUrl,
        title: title,
        author: author,
        imageUrl: imageUrl,
        baseServings: baseServings,
        prepMinutes: prepMinutes,
        cookMinutes: cookMinutes,
        totalMinutes: totalMinutes,
        rating: rating,
        ingredients: ingredients,
        steps: steps,
        tags: tags ?? this.tags,
        importedAt: importedAt,
        schemaVersion: schemaVersion,
      );

  /// Manually created recipes carry a synthetic `manual:<micros>` sourceUrl
  /// instead of a chefkoch link.
  bool get isManual => sourceUrl.startsWith('manual:');

  String get ingredientsJson => jsonEncode(ingredients.map((i) => i.toJson()).toList());

  String get stepsJson => jsonEncode(steps);

  static List<Ingredient> decodeIngredients(String json) => (jsonDecode(json) as List)
      .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
      .toList();

  static List<String> decodeSteps(String json) => (jsonDecode(json) as List).cast<String>();
}
