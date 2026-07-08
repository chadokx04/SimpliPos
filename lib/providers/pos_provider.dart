import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/cart_line.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/sales_report_entry.dart';
import '../utils/constants.dart';

class PosTotals {
  final double subtotal;
  final double lineDiscountTotal;
  final double wholeSaleDiscount;
  final double discountAmount; // display-only combined figure, never persisted as one number
  final double taxAmount;
  final double total;

  const PosTotals({
    required this.subtotal,
    required this.lineDiscountTotal,
    required this.wholeSaleDiscount,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
  });
}

class StockShortfall {
  final int productId;
  final String productName;
  final int requested;
  final int available;

  const StockShortfall({
    required this.productId,
    required this.productName,
    required this.requested,
    required this.available,
  });
}

class CheckoutResult {
  final int? saleId;
  final List<StockShortfall> shortfalls;
  final double? amountTendered;
  final double? changeDue;

  const CheckoutResult._({
    this.saleId,
    this.shortfalls = const [],
    this.amountTendered,
    this.changeDue,
  });

  factory CheckoutResult.success(
    int saleId, {
    double? amountTendered,
    double? changeDue,
  }) {
    return CheckoutResult._(
      saleId: saleId,
      amountTendered: amountTendered,
      changeDue: changeDue,
    );
  }

  factory CheckoutResult.shortfall(List<StockShortfall> shortfalls) {
    return CheckoutResult._(shortfalls: shortfalls);
  }

  bool get isShortfall => shortfalls.isNotEmpty;
}

/// Holds the in-progress POS sale (cart) and drives hold/resume/checkout.
/// Cart mutations (tapping a tile, scanning a barcode) never check stock —
/// stock is validated only at checkout, per spec.
class PosProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<CartLine> _lines = [];
  DiscountType? _wholeSaleDiscountType;
  double? _wholeSaleDiscountValue;

  /// Set on resume() from the held sale's frozen tax_rate_applied; overrides
  /// the live Settings rate until the cart is cleared (hold/checkout/clear).
  double? _frozenTaxRate;

  /// Set on resume(); the held sale row is deleted only after the NEXT
  /// successful hold() or checkout() on this cart, never immediately on
  /// resume — so an abandoned resumed sale is still recoverable in Held
  /// Sales.
  int? _resumedSaleId;

  List<CartLine> get lines => List.unmodifiable(_lines);
  DiscountType? get wholeSaleDiscountType => _wholeSaleDiscountType;
  double? get wholeSaleDiscountValue => _wholeSaleDiscountValue;
  bool get isResumedSale => _resumedSaleId != null;

  /// Restores the cart snapshot saved by [_persist] — call once at app
  /// startup (mirrors [SettingsProvider.load]) so an in-progress sale
  /// survives the app being fully closed and reopened, not just
  /// backgrounded.
  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kPosCartStatePrefsKey);
    if (raw == null) return;

    final state = jsonDecode(raw) as Map<String, dynamic>;
    _lines = (state['lines'] as List)
        .map((m) => CartLine.fromMap(m as Map<String, dynamic>))
        .toList();
    _wholeSaleDiscountType =
        DiscountTypeStorage.fromDbValue(state['whole_sale_discount_type'] as String?);
    _wholeSaleDiscountValue = (state['whole_sale_discount_value'] as num?)?.toDouble();
    _frozenTaxRate = (state['frozen_tax_rate'] as num?)?.toDouble();
    _resumedSaleId = state['resumed_sale_id'] as int?;
    notifyListeners();
  }

  /// Snapshots the current cart to SharedPreferences — called after every
  /// mutation (fire-and-forget; the UI doesn't wait on disk I/O to update).
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'lines': _lines.map((l) => l.toMap()).toList(),
      'whole_sale_discount_type': _wholeSaleDiscountType?.dbValue,
      'whole_sale_discount_value': _wholeSaleDiscountValue,
      'frozen_tax_rate': _frozenTaxRate,
      'resumed_sale_id': _resumedSaleId,
    };
    await prefs.setString(kPosCartStatePrefsKey, jsonEncode(state));
  }

  void addOrIncrementProduct(Product product, {int quantity = 1}) {
    final index = _lines.indexWhere((l) => l.productId == product.id);
    if (index == -1) {
      _lines = [
        ..._lines,
        CartLine(
          productId: product.id!,
          productName: product.name,
          photoPath: product.photoPath,
          unitPrice: product.sellingPrice,
          quantity: quantity,
        ),
      ];
    } else {
      _lines = [
        for (final line in _lines)
          if (line.productId == product.id)
            line.copyWith(quantity: line.quantity + quantity)
          else
            line,
      ];
    }
    notifyListeners();
    _persist();
  }

  void updateLineQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeLine(productId);
      return;
    }
    _lines = [
      for (final line in _lines)
        if (line.productId == productId)
          line.copyWith(quantity: quantity)
        else
          line,
    ];
    notifyListeners();
    _persist();
  }

  void updateLinePrice(int productId, double newPrice) {
    _lines = [
      for (final line in _lines)
        if (line.productId == productId)
          line.copyWith(unitPrice: newPrice)
        else
          line,
    ];
    notifyListeners();
    _persist();
  }

  /// Pass `type: null, value: null` to clear a line's discount.
  void setLineDiscount(int productId, DiscountType? type, double? value) {
    _lines = [
      for (final line in _lines)
        if (line.productId == productId)
          CartLine(
            productId: line.productId,
            productName: line.productName,
            photoPath: line.photoPath,
            unitPrice: line.unitPrice,
            quantity: line.quantity,
            discountType: type,
            discountValue: value,
          )
        else
          line,
    ];
    notifyListeners();
    _persist();
  }

  void removeLine(int productId) {
    _lines = _lines.where((l) => l.productId != productId).toList();
    notifyListeners();
    _persist();
  }

  /// Pass `type: null, value: null` to clear the whole-sale discount.
  void setWholeSaleDiscount(DiscountType? type, double? value) {
    _wholeSaleDiscountType = type;
    _wholeSaleDiscountValue = value;
    notifyListeners();
    _persist();
  }

  void clearCart() {
    _lines = [];
    _wholeSaleDiscountType = null;
    _wholeSaleDiscountValue = null;
    _frozenTaxRate = null;
    _resumedSaleId = null;
    notifyListeners();
    _persist();
  }

  /// subtotal → discount → tax → total, per spec. [liveTaxRatePercent]
  /// (from SettingsProvider) is ignored if this cart came from resume() —
  /// the frozen rate wins.
  PosTotals computeTotals(double liveTaxRatePercent) {
    final subtotal = _lines.fold<double>(0, (sum, l) => sum + l.grossSubtotal);
    final lineDiscountTotal =
        _lines.fold<double>(0, (sum, l) => sum + l.resolvedDiscount);
    final afterLineDiscounts = subtotal - lineDiscountTotal;

    var wholeSaleDiscount = 0.0;
    if (_wholeSaleDiscountType != null && _wholeSaleDiscountValue != null) {
      wholeSaleDiscount = _wholeSaleDiscountType == DiscountType.fixed
          ? _wholeSaleDiscountValue!
          : afterLineDiscounts * _wholeSaleDiscountValue! / 100;
      wholeSaleDiscount = wholeSaleDiscount.clamp(0, afterLineDiscounts).toDouble();
    }

    final discountedSubtotal = afterLineDiscounts - wholeSaleDiscount;
    final effectiveTaxRate = _frozenTaxRate ?? liveTaxRatePercent;
    final taxAmount = discountedSubtotal * effectiveTaxRate / 100;
    final total = discountedSubtotal + taxAmount;

    return PosTotals(
      subtotal: subtotal,
      lineDiscountTotal: lineDiscountTotal,
      wholeSaleDiscount: wholeSaleDiscount,
      discountAmount: lineDiscountTotal + wholeSaleDiscount,
      taxAmount: taxAmount,
      total: total,
    );
  }

  /// Fetches a finalized or held sale fresh from the DB by id — used by the
  /// receipt screen, which re-reads rather than being handed a Sale object,
  /// matching the `/products/:id` re-fetch-by-id convention.
  Future<Sale?> getSale(int id) async {
    final row = await _db.getSaleById(id);
    return row == null ? null : Sale.fromMap(row);
  }

  Future<List<SaleItem>> getSaleItemsFor(int saleId) async {
    final rows = await _db.getSaleItems(saleId);
    return rows.map(SaleItem.fromMap).toList();
  }

  Future<double> getTodaySalesTotal() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _db.getTotalSalesSince(today);
  }

  Future<double> getMonthSalesTotal() {
    final month = DateTime.now().toIso8601String().substring(0, 7);
    return _db.getTotalSalesSince(month);
  }

  String _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String().substring(0, 10);

  /// Sales Report: sold line items with [from]/[to] both treated as
  /// whole calendar days, inclusive on both ends (regardless of time-of-day
  /// on either DateTime).
  Future<List<SalesReportEntry>> getSalesReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final toExclusive = _dateOnly(to.add(const Duration(days: 1)));
    final rows = await _db.getSaleItemsInRange(_dateOnly(from), toExclusive);
    return rows.map(SalesReportEntry.fromMap).toList();
  }

  /// Subtotal/discount/tax/total summary for the same [from]/[to] range as
  /// [getSalesReport] — see [DatabaseHelper.getSalesSummaryInRange]'s doc
  /// for why this always matches what the dashboard would show.
  Future<({double subtotal, double discount, double tax, double total})>
      getSalesSummaryForRange({
    required DateTime from,
    required DateTime to,
  }) {
    final toExclusive = _dateOnly(to.add(const Duration(days: 1)));
    return _db.getSalesSummaryInRange(_dateOnly(from), toExclusive);
  }

  List<Map<String, dynamic>> _buildItemRows() {
    return [
      for (final line in _lines)
        {
          'product_id': line.productId,
          'quantity': line.quantity,
          'unit_price_at_sale': line.unitPrice,
          'line_discount':
              line.resolvedDiscount == 0 ? null : line.resolvedDiscount,
        },
    ];
  }

  Map<String, dynamic> _buildSaleRow({
    required double liveTaxRatePercent,
    required String status,
    String? paymentMethodValue,
  }) {
    final totals = computeTotals(liveTaxRatePercent);
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'subtotal': totals.subtotal,
      'discount_amount': totals.wholeSaleDiscount,
      'discount_type': _wholeSaleDiscountType?.dbValue,
      'tax_rate_applied': _frozenTaxRate ?? liveTaxRatePercent,
      'tax_amount': totals.taxAmount,
      'total': totals.total,
      'payment_method': paymentMethodValue,
      'status': status,
    };
  }

  Future<void> hold(double liveTaxRatePercent) async {
    final saleRow = _buildSaleRow(
      liveTaxRatePercent: liveTaxRatePercent,
      status: 'held',
    );
    final itemRows = _buildItemRows();
    await _db.holdSale(saleRow, itemRows);
    if (_resumedSaleId != null) {
      await _db.deleteSale(_resumedSaleId!);
    }
    clearCart();
  }

  Future<List<Sale>> getHeldSales() async {
    final rows = await _db.getHeldSales();
    return rows.map(Sale.fromMap).toList();
  }

  /// Permanently discards a held sale without resuming it. Safe even if
  /// [saleId] happens to be the currently resumed cart's origin (the row
  /// simply won't be there for hold()/checkout() to delete again later).
  Future<void> deleteHeldSale(int saleId) => _db.deleteSale(saleId);

  /// Loads the held sale + its items into a fresh cart, freezes the tax
  /// rate, and remembers the row so it can be deleted once this cart is
  /// next held or checked out. Does NOT delete it now — see class doc.
  ///
  /// The resolved per-line and whole-sale discount amounts are recovered
  /// exactly, but their original fixed/percent nature is not (the schema
  /// only stores the resolved peso figure) — both are reconstructed as
  /// [DiscountType.fixed]. If the cashier edits a line's quantity after
  /// resuming, a discount that was originally a percentage will NOT
  /// rescale; it stays pinned at whatever peso amount it resolved to.
  Future<void> resume(int saleId) async {
    final saleRow = await _db.getSaleById(saleId);
    if (saleRow == null) return;
    final sale = Sale.fromMap(saleRow);
    final itemRows = await _db.getSaleItems(saleId);
    final items = itemRows.map(SaleItem.fromMap).toList();

    _lines = [
      for (final item in items)
        CartLine(
          productId: item.productId,
          productName: item.productName ?? 'Unknown product',
          photoPath: item.productPhotoPath,
          unitPrice: item.unitPriceAtSale,
          quantity: item.quantity,
          discountType:
              (item.lineDiscount ?? 0) > 0 ? DiscountType.fixed : null,
          discountValue: (item.lineDiscount ?? 0) > 0 ? item.lineDiscount : null,
        ),
    ];
    _wholeSaleDiscountType =
        sale.discountAmount > 0 ? DiscountType.fixed : null;
    _wholeSaleDiscountValue =
        sale.discountAmount > 0 ? sale.discountAmount : null;
    _frozenTaxRate = sale.taxRateApplied;
    _resumedSaleId = saleId;
    notifyListeners();
    _persist();
  }

  Future<CheckoutResult> checkout({
    required double liveTaxRatePercent,
    required PaymentMethod method,
    double? amountTendered,
  }) async {
    final shortfalls = <StockShortfall>[];
    for (final line in _lines) {
      final row = await _db.getProductById(line.productId);
      final available = row == null ? 0 : row['quantity'] as int;
      if (line.quantity > available) {
        shortfalls.add(StockShortfall(
          productId: line.productId,
          productName: line.productName,
          requested: line.quantity,
          available: available,
        ));
      }
    }
    if (shortfalls.isNotEmpty) {
      return CheckoutResult.shortfall(shortfalls);
    }

    final totals = computeTotals(liveTaxRatePercent);
    final saleRow = _buildSaleRow(
      liveTaxRatePercent: liveTaxRatePercent,
      status: 'completed',
      paymentMethodValue: method.dbValue,
    );
    final itemRows = _buildItemRows();
    final saleId = await _db.checkoutSale(saleRow, itemRows);

    if (_resumedSaleId != null) {
      await _db.deleteSale(_resumedSaleId!);
    }

    // Amount tendered / change due are UI-only — the given schema has no
    // column for them, so they're never persisted, only threaded through
    // to the receipt screen via navigation `extra`.
    double? changeDue;
    if (method == PaymentMethod.cash && amountTendered != null) {
      changeDue = amountTendered - totals.total;
    }

    clearCart();
    return CheckoutResult.success(
      saleId,
      amountTendered: amountTendered,
      changeDue: changeDue,
    );
  }
}
