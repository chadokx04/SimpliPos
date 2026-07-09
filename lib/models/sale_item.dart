/// A line item on a [Sale]. [lineDiscount] is the resolved monetary amount
/// deducted from this line (never a fixed/percent pair) — the given schema
/// only stores the resolved figure, matching [Sale.discountAmount] at the
/// whole-sale level.
class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final String? productName;
  final String? productPhotoPath;
  final int quantity;
  final double unitPriceAtSale;
  final double? lineDiscount;

  const SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    this.productName,
    this.productPhotoPath,
    required this.quantity,
    required this.unitPriceAtSale,
    this.lineDiscount,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price_at_sale': unitPriceAtSale,
      'line_discount': lineDiscount,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String?,
      productPhotoPath: map['product_photo_path'] as String?,
      quantity: map['quantity'] as int,
      unitPriceAtSale: (map['unit_price_at_sale'] as num).toDouble(),
      lineDiscount: (map['line_discount'] as num?)?.toDouble(),
    );
  }
}
