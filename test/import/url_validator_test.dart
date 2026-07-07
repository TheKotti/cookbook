import 'package:cookbook/src/import/url_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts plain chefkoch URLs and upgrades http to https', () {
    expect(resolveChefkochUrl('http://www.chefkoch.de/rezepte/1/x.html').toString(),
        'https://www.chefkoch.de/rezepte/1/x.html');
  });

  test('accepts bare domain and m. subdomain', () {
    expect(resolveChefkochUrl('https://chefkoch.de/rezepte/1/x.html').host, 'chefkoch.de');
    expect(resolveChefkochUrl('https://m.chefkoch.de/rezepte/1/x.html').host, 'm.chefkoch.de');
  });

  test('extracts the first URL from surrounding share text (§4 import flow)', () {
    final uri = resolveChefkochUrl(
        'Schau mal: https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html gefunden!');
    expect(uri.path, '/rezepte/745721177147257/Lasagne.html');
  });

  test('strips tracking params and fragments', () {
    final uri = resolveChefkochUrl(
        'https://www.chefkoch.de/rezepte/1/x.html?utm_source=share&portionen=4#kommentare');
    expect(uri.toString(), 'https://www.chefkoch.de/rezepte/1/x.html');
  });

  test('rejects non-chefkoch hosts including lookalikes', () {
    expect(() => resolveChefkochUrl('https://example.com/rezepte/1/x.html'),
        throwsA(isA<InvalidRecipeUrlException>()));
    expect(() => resolveChefkochUrl('https://notchefkoch.de/rezepte/1/x.html'),
        throwsA(isA<InvalidRecipeUrlException>()));
    expect(() => resolveChefkochUrl('https://chefkoch.de.evil.com/x'),
        throwsA(isA<InvalidRecipeUrlException>()));
  });

  test('rejects text without any URL', () {
    expect(() => resolveChefkochUrl('Lasagne wie beim Italiener'),
        throwsA(isA<InvalidRecipeUrlException>()));
  });
}
