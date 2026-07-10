import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../utils/product_photo_store.dart';

enum ProductSortOption { name, category, quantity, price }

class ProductProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  ProductSortOption _sortOption = ProductSortOption.name;
  int? _categoryFilter;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  ProductSortOption get sortOption => _sortOption;
  int? get categoryFilter => _categoryFilter;

  List<Product> get products => _products;

  List<Product> get filteredProducts {
    var result = _products;
    if (_categoryFilter != null) {
      result = result.where((p) => p.categoryId == _categoryFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query) ||
            (p.barcode?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    final sorted = List.of(result);
    switch (_sortOption) {
      case ProductSortOption.name:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case ProductSortOption.category:
        sorted.sort((a, b) => (a.categoryName ?? '')
            .toLowerCase()
            .compareTo((b.categoryName ?? '').toLowerCase()));
      case ProductSortOption.quantity:
        sorted.sort((a, b) => a.quantity.compareTo(b.quantity));
      case ProductSortOption.price:
        sorted.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
    }
    return sorted;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortOption(ProductSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setCategoryFilter(int? categoryId) {
    _categoryFilter = categoryId;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    final rows = await _db.getProducts();
    _products = rows.map(Product.fromMap).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<Product?> getProduct(int id) async {
    final row = await _db.getProductById(id);
    return row == null ? null : Product.fromMap(row);
  }

  Future<Product?> findByBarcode(String barcode) async {
    final row = await _db.getProductByBarcode(barcode);
    return row == null ? null : Product.fromMap(row);
  }

  Future<Product?> findByName(String name) async {
    final row = await _db.getProductByName(name);
    return row == null ? null : Product.fromMap(row);
  }

  Future<String> getNextProductSku() => _db.getNextProductSku();

  Future<void> addProduct(Product product) async {
    await _db.insertProduct(product.toMap());
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    await _db.updateProduct(product.id!, product.toMap());
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    Product? product;
    for (final p in _products) {
      if (p.id == id) {
        product = p;
        break;
      }
    }
    await _db.deleteProduct(id);
    await ProductPhotoStore.delete(product?.photoPath);
    await loadProducts();
  }

  Future<int> getTotalProductCount() => _db.getTotalProductCount();

  Future<double> getTotalStockValue() => _db.getTotalStockValue();

  Future<int> getLowStockCount(int threshold) => _db.getLowStockCount(threshold);
}
