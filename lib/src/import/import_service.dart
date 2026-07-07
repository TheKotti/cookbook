import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe.dart';
import '../parser/recipe_parser.dart';
import '../repository/recipe_repository.dart';
import 'url_validator.dart';

/// Verified necessary (§2): Chefkoch serves non-browser UAs a tiny block page.
const String kBrowserUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.6478.110 Mobile Safari/537.36';

enum ImportError { invalidUrl, offline, blocked, noRecipeFound }

class ImportException implements Exception {
  final ImportError error;
  final String message;
  const ImportException(this.error, this.message);

  @override
  String toString() => message;
}

/// One user action = one request (§3). Fetch → parse → save.
class ImportService {
  final http.Client client;
  final RecipeRepository repository;

  ImportService({required this.client, required this.repository});

  Future<Recipe> importFromText(String text) async {
    final Uri url;
    try {
      url = resolveChefkochUrl(text);
    } on InvalidRecipeUrlException catch (e) {
      throw ImportException(ImportError.invalidUrl, e.message);
    }

    final http.Response response;
    try {
      response = await client.get(url, headers: {
        'User-Agent': kBrowserUserAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-DE,de;q=0.9',
      });
    } catch (_) {
      throw const ImportException(
          ImportError.offline, 'Could not reach chefkoch.de. Check your connection.');
    }

    if (response.statusCode != 200) {
      throw ImportException(ImportError.blocked,
          'Chefkoch answered with HTTP ${response.statusCode}. Try again later.');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (body.length < 2048) {
      // Non-browser clients get a ~184-byte block page (§11).
      throw const ImportException(
          ImportError.blocked, 'Chefkoch served a block page instead of the recipe.');
    }

    final Recipe parsed;
    try {
      parsed = RecipeParser.parse(body, sourceUrl: url.toString());
    } on RecipeParseException {
      throw const ImportException(
          ImportError.noRecipeFound, 'No recipe was found on that page.');
    }

    final id = await repository.saveRecipe(parsed);
    return parsed.copyWith(id: id);
  }
}
