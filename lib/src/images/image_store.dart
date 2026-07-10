import 'dart:io';

import 'package:path/path.dart' as p;

/// Owns manually added recipe photos under `<baseDir>/images/`.
/// Paths handed out are relative so they survive app-data-dir moves (§4.4).
class ImageStore {
  final Directory baseDir;
  ImageStore(this.baseDir);

  /// Copies [sourceFilePath] into the store; returns the relative path.
  Future<String> save(String sourceFilePath) async {
    final extension = p.extension(sourceFilePath);
    final relative =
        p.join('images', '${DateTime.now().microsecondsSinceEpoch}$extension');
    final destination = File(p.join(baseDir.path, relative));
    await destination.parent.create(recursive: true);
    await File(sourceFilePath).copy(destination.path);
    return relative;
  }

  File resolve(String relativePath) => File(p.join(baseDir.path, relativePath));

  /// Best-effort delete; a missing file is not an error.
  Future<void> delete(String relativePath) async {
    try {
      await resolve(relativePath).delete();
    } on FileSystemException {
      // already gone — fine
    }
  }
}
