import 'dart:io';

import 'package:cookbook/src/images/image_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory base;
  late Directory sourceDir;
  late ImageStore store;

  setUp(() {
    base = Directory.systemTemp.createTempSync('cookbook_imgbase');
    sourceDir = Directory.systemTemp.createTempSync('cookbook_imgsrc');
    store = ImageStore(base);
  });

  tearDown(() {
    base.deleteSync(recursive: true);
    sourceDir.deleteSync(recursive: true);
  });

  test('save copies the file under images/ and returns a relative path', () async {
    final source = File(p.join(sourceDir.path, 'photo.jpg'))..writeAsBytesSync([1, 2, 3]);
    final rel = await store.save(source.path);
    expect(rel, startsWith('images/'));
    expect(rel, endsWith('.jpg'));
    expect(p.isRelative(rel), isTrue);
    expect(store.resolve(rel).readAsBytesSync(), [1, 2, 3]);
    // Source file is untouched.
    expect(source.existsSync(), isTrue);
  });

  test('two saves produce distinct filenames', () async {
    final source = File(p.join(sourceDir.path, 'photo.jpg'))..writeAsBytesSync([1]);
    final a = await store.save(source.path);
    final b = await store.save(source.path);
    expect(a, isNot(b));
  });

  test('delete removes the file and ignores a missing one', () async {
    final source = File(p.join(sourceDir.path, 'photo.png'))..writeAsBytesSync([9]);
    final rel = await store.save(source.path);
    await store.delete(rel);
    expect(store.resolve(rel).existsSync(), isFalse);
    await store.delete(rel); // second delete must not throw
    await store.delete('images/never-existed.jpg');
  });
}
