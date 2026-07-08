class Category {
  final int? id;
  final String name;
  final int productCount;

  const Category({this.id, required this.name, this.productCount = 0});

  Category copyWith({int? id, String? name, int? productCount}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      productCount: productCount ?? this.productCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      productCount: (map['product_count'] as num?)?.toInt() ?? 0,
    );
  }
}
