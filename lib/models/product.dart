class Product {
  final int? id;
  final String name;
  final String sku;
  final String? barcode;
  final int categoryId;
  final String? categoryName;
  final int quantity;
  final double unitPrice;
  final double sellingPrice;
  final String? photoPath;
  final String createdAt;

  const Product({
    this.id,
    required this.name,
    required this.sku,
    this.barcode,
    required this.categoryId,
    this.categoryName,
    required this.quantity,
    required this.unitPrice,
    required this.sellingPrice,
    this.photoPath,
    required this.createdAt,
  });

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    int? categoryId,
    String? categoryName,
    int? quantity,
    double? unitPrice,
    double? sellingPrice,
    String? photoPath,
    String? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'category_id': categoryId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'selling_price': sellingPrice,
      'photo_path': photoPath,
      'created_at': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      sku: map['sku'] as String,
      barcode: map['barcode'] as String?,
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String?,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
      photoPath: map['photo_path'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
