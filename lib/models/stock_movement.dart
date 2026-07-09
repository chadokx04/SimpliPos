enum MovementType { stockIn, stockOut }

extension MovementTypeStorage on MovementType {
  String get dbValue => this == MovementType.stockIn ? 'in' : 'out';

  static MovementType fromDbValue(String value) {
    return value == 'in' ? MovementType.stockIn : MovementType.stockOut;
  }
}

class StockMovement {
  final int? id;
  final int productId;
  final String? productName;
  final MovementType type;
  final int quantity;
  final String? note;
  final String timestamp;

  const StockMovement({
    this.id,
    required this.productId,
    this.productName,
    required this.type,
    required this.quantity,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'type': type.dbValue,
      'quantity': quantity,
      'note': note,
      'timestamp': timestamp,
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String?,
      type: MovementTypeStorage.fromDbValue(map['type'] as String),
      quantity: map['quantity'] as int,
      note: map['note'] as String?,
      timestamp: map['timestamp'] as String,
    );
  }
}
