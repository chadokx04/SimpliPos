import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'navigation/restart_widget.dart';
import 'providers/app_lock_provider.dart';
import 'providers/auto_backup_provider.dart';
import 'providers/category_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/product_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/stock_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    RestartWidget(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProductProvider()..loadProducts()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()..loadCategories()),
          ChangeNotifierProvider(create: (_) => StockProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
          ChangeNotifierProvider(create: (_) => PosProvider()..loadCart()),
          ChangeNotifierProvider(create: (_) => AppLockProvider()..load()),
          ChangeNotifierProvider(create: (_) => AutoBackupProvider()..load()),
        ],
        child: const SimpliPosApp(),
      ),
    ),
  );
}
