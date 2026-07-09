import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/stock_movement.dart';

class StockProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  Future<List<StockMovement>> getMovementsForProduct(int productId) async {
    final rows = await _db.getMovementsForProduct(productId);
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<List<StockMovement>> getRecentMovements() async {
    final rows = await _db.getRecentMovements();
    return rows.map(StockMovement.fromMap).toList();
  }

  /// Adds [quantity] to the product's stock and records an 'in' movement.
  Future<void> stockIn({
    required int productId,
    required int currentQuantity,
    required int quantity,
    String? note,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    await _db.updateProductQuantity(productId, currentQuantity + quantity);
    await _db.insertStockMovement({
      'product_id': productId,
      'type': 'in',
      'quantity': quantity,
      'note': note,
      'timestamp': timestamp,
    });
    notifyListeners();
  }

  /// Subtracts [quantity] from the product's stock and records an 'out'
  /// movement. Throws [ArgumentError] if that would push stock below zero.
  Future<void> stockOut({
    required int productId,
    required int currentQuantity,
    required int quantity,
    String? note,
  }) async {
    if (quantity > currentQuantity) {
      throw ArgumentError('Cannot remove more stock than is available.');
    }
    final timestamp = DateTime.now().toIso8601String();
    await _db.updateProductQuantity(productId, currentQuantity - quantity);
    await _db.insertStockMovement({
      'product_id': productId,
      'type': 'out',
      'quantity': quantity,
      'note': note,
      'timestamp': timestamp,
    });
    notifyListeners();
  }

  Future<int> getTodayStockInCount() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _db.getMovementCountForDay(MovementTypeQuery.stockIn, today);
  }

  Future<int> getTodayStockOutCount() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _db.getMovementCountForDay(MovementTypeQuery.stockOut, today);
  }

  /// POS checkout writes stock_movements rows directly inside
  /// DatabaseHelper.checkoutSale's own transaction, bypassing stockIn/
  /// stockOut for atomicity, so nothing here fires notifyListeners on its
  /// own. PosProvider calls this after a successful checkout so screens
  /// that listen to this provider (e.g. the Dashboard) still refresh.
  void notifyStockChanged() => notifyListeners();
}
