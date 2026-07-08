import 'package:intl/intl.dart';

final NumberFormat _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: '₱',
  decimalDigits: 2,
);

/// Formats [value] as peso currency with thousands separators, e.g.
/// `formatCurrency(12345.6)` → `₱12,345.60`.
String formatCurrency(num value) => _currencyFormat.format(value);
