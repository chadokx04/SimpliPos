import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Desktop (Windows/Linux/macOS) needs the FFI-backed sqlite3 factory since
/// the plugin channel implementation only exists for Android/iOS. Mobile
/// falls through untouched and keeps using that plugin.
void configureDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
