import 'sale.dart';

/// One line of the in-progress POS sale. `toMap`/`fromMap` here are only
/// for [PosProvider]'s SharedPreferences cart-persistence snapshot — they
/// have nothing to do with the database, unlike every other model's
/// `toMap`/`fromMap`; the cart is resolved into real [SaleItem] rows only
/// at hold/checkout time.
class CartLine {
  final int productId;
  final String productName;
  final String? photoPath;
  final double unitPrice;
  final int quantity;
  final DiscountType? discountType;
  final double? discountValue; // pesos if fixed, 0-100 if percent

  const CartLine({
    required this.productId,
    required this.productName,
    this.photoPath,
    required this.unitPrice,
    required this.quantity,
    this.discountType,
    this.discountValue,
  });

  double get grossSubtotal => unitPrice * quantity;

  double get resolvedDiscount {
    if (discountType == null || discountValue == null) return 0;
    final raw = discountType == DiscountType.fixed
        ? discountValue!
        : grossSubtotal * discountValue! / 100;
    return raw.clamp(0, grossSubtotal).toDouble();
  }

  double get lineTotal => grossSubtotal - resolvedDiscount;

  CartLine copyWith({
    int? productId,
    String? productName,
    String? photoPath,
    double? unitPrice,
    int? quantity,
    DiscountType? discountType,
    double? discountValue,
  }) {
    return CartLine(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      photoPath: photoPath ?? this.photoPath,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'photo_path': photoPath,
      'unit_price': unitPrice,
      'quantity': quantity,
      'discount_type': discountType?.dbValue,
      'discount_value': discountValue,
    };
  }

  factory CartLine.fromMap(Map<String, dynamic> map) {
    return CartLine(
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      photoPath: map['photo_path'] as String?,
      unitPrice: (map['unit_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      discountType: DiscountTypeStorage.fromDbValue(map['discount_type'] as String?),
      discountValue: (map['discount_value'] as num?)?.toDouble(),
    );
  }
}
