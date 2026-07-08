import 'package:flutter/foundation.dart' hide Category;

import '../db/database_helper.dart';
import '../models/category.dart';

class CategoryProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Category> _categories = [];
  bool _isLoading = false;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();
    final rows = await _db.getCategories();
    _categories = rows.map(Category.fromMap).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    await _db.insertCategory({'name': name});
    await loadCategories();
  }

  Future<void> updateCategory(Category category) async {
    await _db.updateCategory(category.id!, {'name': category.name});
    await loadCategories();
  }

  /// Returns null on success, or an error message if the category could
  /// not be deleted because products still reference it.
  Future<String?> deleteCategory(Category category) async {
    final productCount = await _db.countProductsInCategory(category.id!);
    if (productCount > 0) {
      return 'Cannot delete "${category.name}" — $productCount product(s) '
          'still use this category.';
    }
    await _db.deleteCategory(category.id!);
    await loadCategories();
    return null;
  }
}
