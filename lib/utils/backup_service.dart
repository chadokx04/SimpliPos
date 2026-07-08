import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import 'product_photo_store.dart';

/// Metadata for one backup zip, as listed by [BackupService.listBackups].
class BackupInfo {
  final String path;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupInfo({
    required this.path,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });
}

/// Zips the SQLite database and the product photos directory into one
/// backup file, and can restore either back from a chosen backup.
///
/// Backups live in the app's own documents directory under `backups/` —
/// the same private, permission-free storage the database and photos
/// already use, so none of this needs a storage permission prompt.
class BackupService {
  static const _backupsDirName = 'backups';
  static const _dbEntryPath = 'database/stockflow.db';
  static const _photosEntryDir = 'product_photos';

  static Future<Directory> _backupsDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, _backupsDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Matches this class's own `backup_<timestamp>.zip` naming (see
  /// [createBackup]) so the exact creation instant can be read back from
  /// the filename — see [listBackups] for why that's preferred over the
  /// file's filesystem mtime.
  static final _ownFileNamePattern = RegExp(
    r'^backup_(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})-(\d+)\.zip$',
  );

  static DateTime? _createdAtFromFileName(String fileName) {
    final match = _ownFileNamePattern.firstMatch(fileName);
    if (match == null) return null;
    final date = match.group(1)!;
    final hour = match.group(2)!;
    final minute = match.group(3)!;
    final second = match.group(4)!;
    final micros = match.group(5)!;
    return DateTime.tryParse('${date}T$hour:$minute:$second.$micros');
  }

  static Future<List<BackupInfo>> listBackups() async {
    final dir = await _backupsDir();
    final entries = <BackupInfo>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        final fileName = p.basename(entity.path);
        final stat = await entity.stat();
        entries.add(BackupInfo(
          path: entity.path,
          fileName: fileName,
          // Prefer the timestamp encoded in our own filename over the
          // file's filesystem mtime — mtime can drift (e.g. copies via
          // Android's Storage Access Framework/MediaStore have been
          // observed to touch it) even though nothing about the backup
          // itself changed. Falls back to mtime for an uploaded file
          // that doesn't follow this naming (e.g. user-renamed).
          createdAt: _createdAtFromFileName(fileName) ?? stat.modified,
          sizeBytes: stat.size,
        ));
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Deletes a backup file. Safe to call with a path that no longer exists.
  static Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Strips an OS-added " (1)", " (2)", etc. disambiguation suffix — e.g.
  /// Android's Storage Access Framework appends one automatically when
  /// [FileSaver.saveAs] writes to a destination that already has a file
  /// with that name. Without normalizing this away, downloading a backup
  /// and then re-uploading that exact same file would look like a
  /// brand-new, differently-named backup instead of the same one.
  static String normalizeFileName(String fileName) {
    final match = RegExp(r'^(.*) \(\d+\)(\.zip)$').firstMatch(fileName);
    return match == null ? fileName : '${match.group(1)}${match.group(2)}';
  }

  /// Whether a backup with this filename (after [normalizeFileName]) is
  /// already in the list — used to ask before overwriting on import, since
  /// an uploaded file keeps the name it was downloaded/shared with
  /// (normally the original `backup_<timestamp>.zip` this same feature
  /// creates, modulo that OS-added suffix).
  static Future<bool> backupFileExists(String fileName) async {
    final dir = await _backupsDir();
    return File(p.join(dir.path, normalizeFileName(fileName))).exists();
  }

  /// Copies an externally-picked zip into the app's own backups directory,
  /// under its own (normalized, see [normalizeFileName]) filename, so it
  /// shows up in [listBackups] like any other backup. Overwrites any
  /// existing file with that same name — callers should confirm with the
  /// user first via [backupFileExists].
  static Future<String> importBackup(File source) async {
    final dir = await _backupsDir();
    final fileName = normalizeFileName(p.basename(source.path));
    final destPath = p.join(dir.path, fileName);
    await source.copy(destPath);
    return destPath;
  }

  /// Zips the current database + product photos into a new timestamped
  /// backup file. The database connection is closed first (see
  /// [DatabaseHelper.close]) so the file on disk reflects everything
  /// committed and nothing else writes to it mid-copy; the next normal DB
  /// access afterward transparently reopens it. Returns the new backup's
  /// path.
  static Future<String> createBackup() async {
    await DatabaseHelper.instance.close();

    final dbFile = File(await DatabaseHelper.instance.getDatabaseFilePath());
    final photosDir = await ProductPhotoStore.photosDir();
    final backupsDir = await _backupsDir();

    final timestamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final zipPath = p.join(backupsDir.path, 'backup_$timestamp.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    if (await dbFile.exists()) {
      await encoder.addFile(dbFile, _dbEntryPath);
    }
    if (await photosDir.exists()) {
      // photosDir's own folder name is "product_photos", so entries land
      // at "product_photos/<file>" — matching _photosEntryDir on restore.
      await encoder.addDirectory(photosDir, includeDirName: true);
    }
    await encoder.close();

    return zipPath;
  }

  /// Extracts [backupPath] into a scratch directory, then overwrites the
  /// live database file and the entire product photos directory with its
  /// contents. The database connection is closed first, same as
  /// [createBackup].
  ///
  /// The caller must tell the user to restart the app afterward — every
  /// provider's already-loaded in-memory state (product lists, cart,
  /// categories, etc.) would otherwise keep showing pre-restore data until
  /// a fresh cold start re-reads everything from the now-restored database.
  static Future<void> restoreBackup(String backupPath) async {
    await DatabaseHelper.instance.close();

    final docsDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(p.join(docsDir.path, 'restore_tmp'));
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    try {
      await extractFileToDisk(backupPath, tempDir.path);

      final restoredDb = File(p.join(tempDir.path, _dbEntryPath));
      if (await restoredDb.exists()) {
        final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
        await restoredDb.copy(dbPath);
      }

      final restoredPhotosDir = Directory(p.join(tempDir.path, _photosEntryDir));
      final photosDir = await ProductPhotoStore.photosDir();
      if (await photosDir.exists()) {
        await photosDir.delete(recursive: true);
      }
      await photosDir.create(recursive: true);
      if (await restoredPhotosDir.exists()) {
        await for (final entity in restoredPhotosDir.list()) {
          if (entity is File) {
            await entity.copy(p.join(photosDir.path, p.basename(entity.path)));
          }
        }
      }
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}
