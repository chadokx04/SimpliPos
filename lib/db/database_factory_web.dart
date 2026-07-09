import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Swapped in for [configureDatabaseFactory] on web builds (see the
/// conditional import in database_helper.dart) since the plugin channel
/// implementation sqflite normally uses doesn't exist in a browser.
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
