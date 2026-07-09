import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/backup_service.dart';
import '../utils/constants.dart';

/// Drives the "Auto Backup" switch in Backup & Restore: while [enabled],
/// zips up a backup every [intervalSeconds] (user-configurable via
/// [setIntervalSeconds]) and prunes down to [kAutoBackupMaxCount] of them
/// (see [BackupService.pruneAutoBackups]).
///
/// Lives for the app's whole lifetime (constructed once in main.dart's
/// MultiProvider) rather than being scoped to the Backup & Restore screen,
/// so backups keep happening on schedule even while the cashier is on a
/// different screen — the timer is only ever cancelled by [setEnabled]
/// (false) or the app process itself ending, not by navigation.
class AutoBackupProvider extends ChangeNotifier {
  bool _enabled = false;
  int _intervalSeconds = kAutoBackupDefaultIntervalSeconds;
  Timer? _timer;

  /// Bumped after every attempted auto backup (success or failure) so a
  /// visible Backup & Restore screen knows to reload its auto backup list.
  int _runCount = 0;

  bool get enabled => _enabled;
  int get intervalSeconds => _intervalSeconds;
  int get runCount => _runCount;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(kAutoBackupEnabledPrefsKey) ?? false;
    _intervalSeconds = prefs.getInt(kAutoBackupIntervalSecondsPrefsKey) ??
        kAutoBackupDefaultIntervalSeconds;
    notifyListeners();
    if (_enabled) _startTimer();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAutoBackupEnabledPrefsKey, value);
    if (value) {
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Changes how often auto backup runs, restarting the timer immediately
  /// with the new interval if it's currently enabled — the cashier
  /// shouldn't have to toggle the switch off/on for a change to take effect.
  Future<void> setIntervalSeconds(int seconds) async {
    final clamped = seconds < kAutoBackupMinIntervalSeconds
        ? kAutoBackupMinIntervalSeconds
        : seconds;
    _intervalSeconds = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kAutoBackupIntervalSecondsPrefsKey, clamped);
    if (_enabled) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) => _runAutoBackup(),
    );
  }

  Future<void> _runAutoBackup() async {
    try {
      await BackupService.createBackup(auto: true);
      await BackupService.pruneAutoBackups(kAutoBackupMaxCount);
    } catch (_) {
      // Best-effort: a single failed auto backup (e.g. disk full) shouldn't
      // stop the periodic timer from trying again next tick.
    }
    _runCount++;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
