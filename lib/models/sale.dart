enum SaleStatus { held, completed }

extension SaleStatusStorage on SaleStatus {
  String get dbValue => this == SaleStatus.held ? 'held' : 'completed';

  static SaleStatus fromDbValue(String value) {
    return value == 'held' ? SaleStatus.held : SaleStatus.completed;
  }
}

enum DiscountType { fixed, percent }

extension DiscountTypeStorage on DiscountType {
  String get dbValue => this == DiscountType.fixed ? 'fixed' : 'percent';

  static DiscountType? fromDbValue(String? value) {
    if (value == null) return null;
    return value == 'fixed' ? DiscountType.fixed : DiscountType.percent;
  }
}

enum PaymentMethod { cash, card }

extension PaymentMethodStorage on PaymentMethod {
  String get dbValue => this == PaymentMethod.cash ? 'cash' : 'card';

  static PaymentMethod? fromDbValue(String? value) {
    if (value == null) return null;
    return value == 'cash' ? PaymentMethod.cash : PaymentMethod.card;
  }
}

/// A POS sale. [discountAmount]/[discountType] describe the whole-sale
/// discount only — per-item discounts live on each [SaleItem] and are not
/// included here. The combined figure shown to the cashier/receipt is
/// computed at render time, never persisted as a single number, so a
/// resumed held sale can still tell the two apart.
class Sale {
  final int? id;
  final String timestamp;
  final double subtotal;
  final double discountAmount;
  final DiscountType? discountType;
  final double taxRateApplied;
  final double taxAmount;
  final double total;
  final PaymentMethod? paymentMethod;
  final SaleStatus status;
  final int? itemCount; // join-only, like Product.categoryName; excluded from toMap

  const Sale({
    this.id,
    required this.timestamp,
    required this.subtotal,
    this.discountAmount = 0,
    this.discountType,
    required this.taxRateApplied,
    required this.taxAmount,
    required this.total,
    this.paymentMethod,
    required this.status,
    this.itemCount,
  });

  Sale copyWith({
    int? id,
    String? timestamp,
    double? subtotal,
    double? discountAmount,
    DiscountType? discountType,
    double? taxRateApplied,
    double? taxAmount,
    double? total,
    PaymentMethod? paymentMethod,
    SaleStatus? status,
    int? itemCount,
  }) {
    return Sale(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      taxRateApplied: taxRateApplied ?? this.taxRateApplied,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'discount_type': discountType?.dbValue,
      'tax_rate_applied': taxRateApplied,
      'tax_amount': taxAmount,
      'total': total,
      'payment_method': paymentMethod?.dbValue,
      'status': status.dbValue,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      timestamp: map['timestamp'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      discountType:
          DiscountTypeStorage.fromDbValue(map['discount_type'] as String?),
      taxRateApplied: (map['tax_rate_applied'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      paymentMethod:
          PaymentMethodStorage.fromDbValue(map['payment_method'] as String?),
      status: SaleStatusStorage.fromDbValue(map['status'] as String),
      itemCount: (map['item_count'] as num?)?.toInt(),
    );
  }
}
