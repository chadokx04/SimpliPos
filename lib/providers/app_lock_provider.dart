import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Gates the whole app behind a 6-digit code, checked once per cold start.
///
/// [_pinHash] is only ever the SHA-256 hash of the code, never the raw
/// digits — `verifyPin` re-hashes the attempt and compares. Enabling always
/// goes through [setPin] (which also flips [isEnabled] on), and [disable]
/// always forgets the stored hash, so `isEnabled == false` implies
/// `hasPinSet == false` as an invariant callers can rely on.
///
/// [_unlockedThisSession] is deliberately in-memory only (never persisted)
/// — it resets to false every time the app process starts, which is what
/// makes the code get asked for again on the next cold start.
class AppLockProvider extends ChangeNotifier {
  bool _isReady = false;
  bool _isEnabled = false;
  String? _pinHash;
  bool _unlockedThisSession = false;

  /// False until [load] resolves the stored state — until then, the app
  /// should show neither the lock screen nor real content (see app.dart),
  /// since we don't yet know whether the lock is even on.
  bool get isReady => _isReady;

  bool get isEnabled => _isEnabled;
  bool get hasPinSet => _pinHash != null;

  /// Whether the real app content should be shown right now.
  bool get shouldShowApp => _isReady && (!_isEnabled || _unlockedThisSession);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(kAppLockEnabledPrefsKey) ?? false;
    _pinHash = prefs.getString(kAppLockPinHashPrefsKey);
    _isReady = true;
    notifyListeners();
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();

  /// Sets a new 6-digit code and turns App Lock on. Also unlocks the
  /// current session immediately — the cashier just proved they know the
  /// new code by typing it in to set it, so there's no point re-asking.
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    _pinHash = _hash(pin);
    _isEnabled = true;
    _unlockedThisSession = true;
    await prefs.setBool(kAppLockEnabledPrefsKey, true);
    await prefs.setString(kAppLockPinHashPrefsKey, _pinHash!);
    notifyListeners();
  }

  bool verifyPin(String pin) => _pinHash != null && _hash(pin) == _pinHash;

  /// Turns App Lock off and forgets the stored code. Callers must already
  /// have verified the current code via [verifyPin] before calling this.
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = false;
    _pinHash = null;
    await prefs.setBool(kAppLockEnabledPrefsKey, false);
    await prefs.remove(kAppLockPinHashPrefsKey);
    notifyListeners();
  }

  /// Called by the lock screen after [verifyPin] succeeds.
  void unlock() {
    _unlockedThisSession = true;
    notifyListeners();
  }
}
