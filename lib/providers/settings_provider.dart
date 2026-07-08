import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class SettingsProvider extends ChangeNotifier {
  double _taxRatePercent = kDefaultTaxRatePercent;

  double get taxRatePercent => _taxRatePercent;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _taxRatePercent =
        prefs.getDouble(kTaxRatePrefsKey) ?? kDefaultTaxRatePercent;
    notifyListeners();
  }

  Future<void> setTaxRatePercent(double value) async {
    final clamped = value.clamp(0, 100).toDouble();
    _taxRatePercent = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kTaxRatePrefsKey, clamped);
  }
}
