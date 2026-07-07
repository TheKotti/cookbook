import 'dart:io';

import 'package:cookbook/src/db/database.dart';
import 'package:cookbook/src/import/import_service.dart';
import 'package:cookbook/src/repository/local_recipe_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase db;
  late LocalRecipeRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalRecipeRepository(db);
  });

  tearDown(() => db.close());

  ImportService service(MockClient client) => ImportService(client: client, repository: repo);

  test('fetches with browser UA, parses, saves, and returns recipe with id', () async {
    final html = File('test/fixtures/lasagne.html').readAsStringSync();
    String? sentUserAgent;
    final client = MockClient((request) async {
      sentUserAgent = request.headers['User-Agent'];
      expect(request.url.toString(),
          'https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html');
      return http.Response(html, 200, headers: {'content-type': 'text/html; charset=utf-8'});
    });

    final recipe = await service(client).importFromText(
        'https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html?utm_source=x');
    expect(sentUserAgent, kBrowserUserAgent);
    expect(sentUserAgent, contains('Chrome'));
    expect(recipe.id, isNotNull);
    expect(recipe.title, 'Lasagne - wie beim Italiener');
    expect((await repo.getRecipe(recipe.id!))!.title, 'Lasagne - wie beim Italiener');
  });

  test('invalid URL throws ImportError.invalidUrl without any request', () async {
    final client = MockClient((request) async => fail('must not fetch'));
    expect(
      () => service(client).importFromText('https://example.com/x'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.invalidUrl)),
    );
  });

  test('network failure throws ImportError.offline', () async {
    final client = MockClient((request) async => throw http.ClientException('no route'));
    expect(
      () => service(client).importFromText('https://www.chefkoch.de/rezepte/1/x.html'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.offline)),
    );
  });

  test('non-200 response throws ImportError.blocked', () async {
    final client = MockClient((request) async => http.Response('gone', 410));
    expect(
      () => service(client).importFromText('https://www.chefkoch.de/rezepte/1/x.html'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.blocked)),
    );
  });

  test('tiny block-page body throws ImportError.blocked (§6 failure modes)', () async {
    final blockPage = File('test/fixtures/block_page.html').readAsStringSync();
    final client = MockClient((request) async => http.Response(blockPage, 200));
    expect(
      () => service(client).importFromText('https://www.chefkoch.de/rezepte/1/x.html'),
      throwsA(isA<ImportException>().having((e) => e.error, 'error', ImportError.blocked)),
    );
  });

  test('full page without recipe JSON-LD throws ImportError.noRecipeFound', () async {
    final bigNonRecipePage = '<html><body>${'x' * 5000}</body></html>';
    final client = MockClient((request) async => http.Response(bigNonRecipePage, 200));
    expect(
      () => service(client).importFromText('https://www.chefkoch.de/rezepte/1/x.html'),
      throwsA(
          isA<ImportException>().having((e) => e.error, 'error', ImportError.noRecipeFound)),
    );
  });

  test('re-import of the same URL overwrites instead of duplicating (§2)', () async {
    final html = File('test/fixtures/lasagne.html').readAsStringSync();
    final client = MockClient((request) async =>
        http.Response(html, 200, headers: {'content-type': 'text/html; charset=utf-8'}));
    final first = await service(client)
        .importFromText('https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html');
    final second = await service(client)
        .importFromText('https://www.chefkoch.de/rezepte/745721177147257/Lasagne.html');
    expect(second.id, first.id);
    expect(await repo.getAllRecipes(), hasLength(1));
  });
}
