import 'dart:convert';

import '../models/recipe.dart';
import 'ingredient_parser.dart';
import 'scalar_parsers.dart';

class RecipeParseException implements Exception {
  final String code;
  final String message;
  const RecipeParseException(this.code, this.message);

  @override
  String toString() => 'RecipeParseException($code): $message';
}

/// Extracts the schema.org/Recipe JSON-LD from a Chefkoch HTML page and
/// normalizes it into a [Recipe]. Pure Dart, no platform dependencies (§6).
class RecipeParser {
  static Recipe parse(String html, {required String sourceUrl, DateTime Function()? now}) {
    final data = _findRecipeObject(html);
    if (data == null) {
      throw const RecipeParseException(
          'NO_RECIPE_FOUND', 'No schema.org/Recipe JSON-LD found on the page.');
    }
    return Recipe(
      sourceUrl: sourceUrl,
      title: (data['name'] as String?)?.trim() ?? '',
      author: _author(data['author']),
      imageUrl: _imageUrl(data['image']),
      baseServings: parseServings(data['recipeYield']),
      prepMinutes: parseIso8601DurationToMinutes(data['prepTime'] as String?),
      cookMinutes: parseIso8601DurationToMinutes(data['cookTime'] as String?),
      totalMinutes: parseIso8601DurationToMinutes(data['totalTime'] as String?),
      rating: _rating(data['aggregateRating']),
      ingredients: [
        for (final item in (data['recipeIngredient'] as List? ?? []))
          if (item is String) parseIngredient(item)
      ],
      steps: _steps(data['recipeInstructions']),
      tags: _tags(data['keywords']),
      importedAt: (now ?? DateTime.now)(),
    );
  }

  static Map<String, dynamic>? _findRecipeObject(String html) {
    final scripts = RegExp(
      r'''<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in scripts.allMatches(html)) {
      final Object? decoded;
      try {
        decoded = jsonDecode(match[1]!.trim());
      } on FormatException {
        continue; // malformed block — try the next one
      }
      final recipe = _recurseForRecipe(decoded);
      if (recipe != null) return recipe;
    }
    return null;
  }

  /// `@type` may be a string or a list; the Recipe may sit in an array or
  /// under `@graph` — recurse through maps and lists (§6 step 1).
  static Map<String, dynamic>? _recurseForRecipe(Object? node) {
    if (node is Map<String, dynamic>) {
      final type = node['@type'];
      if (type == 'Recipe' || (type is List && type.contains('Recipe'))) {
        return node;
      }
      for (final value in node.values) {
        final found = _recurseForRecipe(value);
        if (found != null) return found;
      }
    }
    if (node is List) {
      for (final value in node) {
        final found = _recurseForRecipe(value);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String _author(Object? node) {
    if (node is String) return node.trim();
    if (node is Map) return (node['name'] as String?)?.trim() ?? '';
    if (node is List && node.isNotEmpty) return _author(node.first);
    return '';
  }

  static String? _imageUrl(Object? node) {
    if (node is String && node.startsWith('http')) return node;
    if (node is Map) return _imageUrl(node['url']);
    if (node is List) {
      for (final item in node) {
        final url = _imageUrl(item);
        if (url != null) return url;
      }
    }
    return null;
  }

  static double? _rating(Object? node) {
    if (node is! Map) return null;
    final value = node['ratingValue'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String> _steps(Object? node) {
    if (node is String) {
      return node
          .split(RegExp(r'\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (node is List) {
      final steps = <String>[];
      for (final element in node) {
        if (element is String) {
          if (element.trim().isNotEmpty) steps.add(element.trim());
        } else if (element is Map) {
          final type = element['@type'];
          final isSection =
              type == 'HowToSection' || (type is List && type.contains('HowToSection'));
          if (isSection) {
            steps.addAll(_steps(element['itemListElement']));
          } else {
            final text = element['text'];
            if (text is String && text.trim().isNotEmpty) steps.add(text.trim());
          }
        }
      }
      return steps;
    }
    return [];
  }

  static List<String> _tags(Object? node) {
    Iterable<String> parts;
    if (node is String) {
      parts = node.split(',');
    } else if (node is List) {
      parts = node.whereType<String>();
    } else {
      return [];
    }
    final seen = <String>{};
    return [
      for (final part in parts)
        if (part.trim().isNotEmpty && seen.add(part.trim().toLowerCase()))
          part.trim().toLowerCase()
    ];
  }
}
