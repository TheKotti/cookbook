class InvalidRecipeUrlException implements Exception {
  final String message;
  const InvalidRecipeUrlException(this.message);

  @override
  String toString() => message;
}

/// Extracts the first http(s) URL from shared text, validates that it points
/// at chefkoch.de (or a subdomain), upgrades to https, and strips query
/// params and fragments (§4 import flow, steps 1-2).
Uri resolveChefkochUrl(String text) {
  final match = RegExp(r'https?://\S+').firstMatch(text);
  if (match == null) {
    throw const InvalidRecipeUrlException('No link found in the text.');
  }
  final candidate = match[0]!.replaceAll(RegExp(r'''[>"'.,;:!?)\]]+$'''), '');
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.host.isEmpty) {
    throw const InvalidRecipeUrlException('That link could not be read.');
  }
  final host = uri.host.toLowerCase();
  if (host != 'chefkoch.de' && !host.endsWith('.chefkoch.de')) {
    throw const InvalidRecipeUrlException('Only chefkoch.de links can be imported.');
  }
  return Uri(scheme: 'https', host: uri.host, path: uri.path);
}
