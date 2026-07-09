import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Product photos are copied into the app's own documents directory (under
/// `product_photos/`) rather than kept at wherever image_picker/the camera
/// originally wrote them — those source paths can be transient (e.g. a
/// camera cache file cleared by the OS) and aren't guaranteed to outlive
/// the picker call. Each photo is named after its product's SKU, so a
/// product's image can always be found/replaced/deleted by SKU alone.
class ProductPhotoStore {
  static const _dirName = 'product_photos';

  /// The directory all product photos live in — exposed for
  /// BackupService, which needs to zip/replace it wholesale.
  static Future<Directory> photosDir() => _photosDir();

  static Future<Directory> _photosDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies [source] into the app's photo directory as `<sku><ext>`,
  /// first deleting any existing photo already stored for that SKU (even
  /// under a different extension) so replacing a photo never leaves the
  /// old file orphaned. Returns the new file's absolute path.
  ///
  /// Also evicts that path from Flutter's image cache: since a replaced
  /// photo reuses the exact same `<sku><ext>` path, every `FileImage(File(
  /// path))` elsewhere in the app (product list/detail, POS cart/tiles)
  /// would otherwise keep rendering the stale cached bitmap instead of the
  /// new file's bytes — `FileImage` caches by path, not by file contents.
  static Future<String> save({required File source, required String sku}) async {
    final dir = await _photosDir();
    await _deleteForSku(dir, sku);
    final destPath = p.join(dir.path, '$sku${p.extension(source.path)}');
    final copied = await source.copy(destPath);
    await FileImage(copied).evict();
    return copied.path;
  }

  /// Deletes every stored product photo (used by the drawer's "Reset").
  /// The directory is recreated lazily on next use, same as a fresh
  /// install — see [_photosDir].
  static Future<void> deleteAll() async {
    final dir = await _photosDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Deletes the photo file at [path], if any. Safe to call with `null` or
  /// a path that no longer exists.
  static Future<void> delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> _deleteForSku(Directory dir, String sku) async {
    await for (final entity in dir.list()) {
      if (entity is File && p.basenameWithoutExtension(entity.path) == sku) {
        await entity.delete();
      }
    }
  }
}
