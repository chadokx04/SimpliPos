/// One sold line item for the Sales Report — a [sale_items] row joined with
/// its parent sale's timestamp, scoped to a date range by
/// `DatabaseHelper.getSaleItemsInRange`. Distinct from [SaleItem] (used by
/// the receipt screen) since this join also carries `sale_id`/`timestamp`
/// fields that a single receipt already gets from its own [Sale].
class SalesReportEntry {
  final int saleId;
  final int productId;
  final String? productName;
  final int quantity;
  final double unitPriceAtSale;
  final double? lineDiscount;
  final String timestamp;

  const SalesReportEntry({
    required this.saleId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPriceAtSale,
    this.lineDiscount,
    required this.timestamp,
  });

  double get lineTotal => unitPriceAtSale * quantity - (lineDiscount ?? 0);

  factory SalesReportEntry.fromMap(Map<String, dynamic> map) {
    return SalesReportEntry(
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String?,
      quantity: map['quantity'] as int,
      unitPriceAtSale: (map['unit_price_at_sale'] as num).toDouble(),
      lineDiscount: (map['line_discount'] as num?)?.toDouble(),
      timestamp: map['timestamp'] as String,
    );
  }
}
