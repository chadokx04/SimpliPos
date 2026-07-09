/// Products with quantity at or below this are counted as "low stock" on
/// the dashboard. Kept as a single constant rather than a per-product
/// column since no per-product threshold was requested.
const int kLowStockThreshold = 5;

/// Default POS tax rate (%) until a cashier sets one in Settings. Defaults
/// to 0 rather than a jurisdiction-specific rate so tax is never silently
/// applied before it's explicitly configured.
const double kDefaultTaxRatePercent = 0.0;

/// SharedPreferences key backing [kDefaultTaxRatePercent].
const String kTaxRatePrefsKey = 'pos_tax_rate_percent';

/// SharedPreferences key backing the persisted in-progress POS cart, so it
/// survives the app being closed and reopened rather than only surviving a
/// backgrounding (where the widget tree — and this provider — stays alive).
const String kPosCartStatePrefsKey = 'pos_cart_state';

/// SharedPreferences keys backing [AppLockProvider] — whether App Lock is
/// turned on, and the SHA-256 hash of the 6-digit code (never the raw
/// code itself).
const String kAppLockEnabledPrefsKey = 'app_lock_enabled';
const String kAppLockPinHashPrefsKey = 'app_lock_pin_hash';

/// SharedPreferences keys backing [AutoBackupProvider]'s enabled switch and
/// user-configurable run interval.
const String kAutoBackupEnabledPrefsKey = 'auto_backup_enabled';
const String kAutoBackupIntervalSecondsPrefsKey = 'auto_backup_interval_seconds';

/// Interval auto backup runs at until the user changes it in Backup &
/// Restore, and the shortest interval the picker allows (guards against an
/// accidental near-0 value hammering the database with backups).
const int kAutoBackupDefaultIntervalSeconds = 30;
const int kAutoBackupMinIntervalSeconds = 10;

/// How many of its own backups auto backup keeps before evicting the oldest.
const int kAutoBackupMaxCount = 10;
