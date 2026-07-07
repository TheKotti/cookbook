import 'dart:convert';

import '../models/recipe.dart';
import '../repository/recipe_repository.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

class BackupImportResult {
  final int added;
  final int updated;
  const BackupImportResult({required this.added, required this.updated});
}

/// Manual JSON export/import of the whole collection (§8) — the safety net
/// against a lost device and the migration format for future cloud sync.
class BackupService {
  final RecipeRepository repository;
  BackupService(this.repository);

  Future<String> exportJson({DateTime Function()? now}) async {
    final recipes = await repository.getAllRecipes();
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'cookbook',
      'format_version': 1,
      'exported_at': (now ?? DateTime.now)().toUtc().toIso8601String(),
      'recipes': [for (final r in recipes) _toJson(r)],
    });
  }

  Future<BackupImportResult> importJson(String jsonString) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException {
      throw const BackupException('That file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic> || decoded['recipes'] is! List) {
      throw const BackupException('That file is not a Cookbook backup.');
    }
    if (decoded['format_version'] != 1) {
      throw BackupException(
          'Unsupported backup version (${decoded['format_version']}). Update the app and try again.');
    }

    // Parse everything first so a bad entry rejects the file before any write.
    final recipes = <Recipe>[];
    for (final entry in decoded['recipes'] as List) {
      if (entry is! Map<String, dynamic>) {
        throw const BackupException('That file contains an invalid recipe entry.');
      }
      recipes.add(_fromJson(entry));
    }

    final existingUrls = (await repository.getAllRecipes()).map((r) => r.sourceUrl).toSet();
    var added = 0;
    var updated = 0;
    for (final recipe in recipes) {
      existingUrls.contains(recipe.sourceUrl) ? updated++ : added++;
      await repository.saveRecipe(recipe, tagMode: TagMode.replace);
    }
    return BackupImportResult(added: added, updated: updated);
  }

  Map<String, dynamic> _toJson(Recipe r) => {
        'source_url': r.sourceUrl,
        'title': r.title,
        'author': r.author,
        'image_url': r.imageUrl,
        'base_servings': r.baseServings,
        'prep_minutes': r.prepMinutes,
        'cook_minutes': r.cookMinutes,
        'total_minutes': r.totalMinutes,
        'rating': r.rating,
        'schema_version': r.schemaVersion,
        'imported_at': r.importedAt.toIso8601String(),
        'ingredients': [for (final i in r.ingredients) i.toJson()],
        'steps': r.steps,
        'tags': r.tags,
      };

  Recipe _fromJson(Map<String, dynamic> json) {
    final sourceUrl = json['source_url'];
    final title = json['title'];
    if (sourceUrl is! String || sourceUrl.isEmpty || title is! String) {
      throw const BackupException('That file contains a recipe without source_url or title.');
    }
    return Recipe(
      sourceUrl: sourceUrl,
      title: title,
      author: json['author'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      baseServings: json['base_servings'] as int?,
      prepMinutes: json['prep_minutes'] as int?,
      cookMinutes: json['cook_minutes'] as int?,
      totalMinutes: json['total_minutes'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
      ingredients: [
        for (final i in json['ingredients'] as List? ?? [])
          Ingredient.fromJson(i as Map<String, dynamic>)
      ],
      steps: (json['steps'] as List? ?? []).cast<String>(),
      tags: (json['tags'] as List? ?? []).cast<String>(),
      importedAt: DateTime.tryParse(json['imported_at'] as String? ?? '') ?? DateTime.now(),
      schemaVersion: json['schema_version'] as int? ?? kCurrentSchemaVersion,
    );
  }
}
