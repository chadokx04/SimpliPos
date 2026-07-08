import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton wrapper around the app's single SQLite database.
///
/// Schema policy (documented since it isn't obvious from the code alone):
/// - Deleting a product is a HARD delete. Its stock_movements rows are
///   removed via ON DELETE CASCADE, so movement history does not outlive
///   the product it describes.
/// - Deleting a category is BLOCKED (at the call site, see
///   CategoryProvider) while any product still references it, so products
///   never end up with a dangling/null category.
/// - `sale_items.product_id` deliberately has no FOREIGN KEY constraint.
///   Unlike categories, there is no guard against deleting a product that
///   appears in past sales, and enforcing the FK would make that throw.
///   sale_items keeps `product_id`/quantity/price as a historical snapshot
///   instead, same idea as `stock_movements.note` freezing context in text.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'stockflow.db';
  static const _dbVersion = 4;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// The database file's path on disk, without opening it — used by
  /// BackupService to locate the file to zip/overwrite directly.
  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  /// Closes the current connection, if open, so the underlying file is
  /// safe to copy/overwrite (e.g. for backup/restore). The next call to
  /// [database] transparently reopens it — nothing else needs to know this
  /// happened.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Deletes the database file entirely (used by the drawer's "Reset").
  /// The next call to [database] recreates it from scratch via [_onCreate]
  /// — same schema and seeded "Uncategorized" category as a fresh install.
  Future<void> resetDatabase() async {
    await close();
    final file = File(await getDatabaseFilePath());
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT NOT NULL UNIQUE,
        barcode TEXT,
        category_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        unit_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        photo_path TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Unique index rather than a column-level UNIQUE constraint because
    // barcode is optional — SQLite treats each NULL as distinct under a
    // unique index, so any number of barcode-less products is still fine.
    await db.execute(
      'CREATE UNIQUE INDEX idx_products_barcode ON products (barcode)',
    );

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('in', 'out')),
        quantity INTEGER NOT NULL,
        note TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0,
        discount_type TEXT CHECK (discount_type IN ('fixed', 'percent')),
        tax_rate_applied REAL NOT NULL,
        tax_amount REAL NOT NULL,
        total REAL NOT NULL,
        payment_method TEXT CHECK (payment_method IN ('cash', 'card')),
        status TEXT NOT NULL CHECK (status IN ('held', 'completed'))
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price_at_sale REAL NOT NULL,
        line_discount REAL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.insert('categories', {'name': 'Uncategorized'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN selling_price REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          subtotal REAL NOT NULL,
          discount_amount REAL NOT NULL DEFAULT 0,
          discount_type TEXT CHECK (discount_type IN ('fixed', 'percent')),
          tax_rate_applied REAL NOT NULL,
          tax_amount REAL NOT NULL,
          total REAL NOT NULL,
          payment_method TEXT CHECK (payment_method IN ('cash', 'card')),
          status TEXT NOT NULL CHECK (status IN ('held', 'completed'))
        )
      ''');
      await db.execute('''
        CREATE TABLE sale_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price_at_sale REAL NOT NULL,
          line_discount REAL,
          FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 4) {
      // Null out all but the first occurrence of any duplicated barcode so
      // the new unique index below doesn't fail on pre-existing data.
      await db.execute('''
        UPDATE products SET barcode = NULL
        WHERE barcode IS NOT NULL AND id NOT IN (
          SELECT MIN(id) FROM products WHERE barcode IS NOT NULL GROUP BY barcode
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX idx_products_barcode ON products (barcode)',
      );
    }
  }

  // ---------------- Categories ----------------

  Future<int> insertCategory(Map<String, dynamic> row) async {
    final db = await database;
    return db.insert('categories', row);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.rawQuery('''
      SELECT c.*, COUNT(p.id) AS product_count
      FROM categories c
      LEFT JOIN products p ON p.category_id = c.id
      GROUP BY c.id
      ORDER BY c.name ASC
    ''');
  }

  Future<int> updateCategory(int id, Map<String, dynamic> row) async {
    final db = await database;
    return db.update('categories', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countProductsInCategory(int categoryId) async {
    final db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM products WHERE category_id = ?',
      [categoryId],
    ));
    return result ?? 0;
  }

  // ---------------- Products ----------------

  /// SKU is always auto-assigned from the new row's id (zero-padded to at
  /// least 6 digits, e.g. "000001") rather than whatever's in [row] — the
  /// row is inserted with a placeholder first since `sku` is NOT NULL, then
  /// patched in the same transaction once the real id is known. Because it
  /// derives from AUTOINCREMENT, which SQLite never reuses, it's guaranteed
  /// unique without a manual check.
  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('products', {...row, 'sku': ''});
      final sku = id.toString().padLeft(6, '0');
      await txn.update('products', {'sku': sku}, where: 'id = ?', whereArgs: [id]);
      return id;
    });
  }

  /// Previews the SKU [insertProduct] will assign to the next new product,
  /// so the add-product form can display it ahead of saving. Reads
  /// `sqlite_sequence` (SQLite's own AUTOINCREMENT high-water mark, which
  /// persists across deletes) rather than `MAX(id)` so the preview is still
  /// correct on an empty table after products have been deleted.
  Future<String> getNextProductSku() async {
    final db = await database;
    final rows = await db.query(
      'sqlite_sequence',
      columns: ['seq'],
      where: 'name = ?',
      whereArgs: ['products'],
    );
    final seq = rows.isEmpty ? 0 : rows.first['seq'] as int;
    return (seq + 1).toString().padLeft(6, '0');
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      ORDER BY p.name ASC
    ''');
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.id = ?
    ''', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.barcode = ?
    ''', [barcode]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateProduct(int id, Map<String, dynamic> row) async {
    final db = await database;
    return db.update('products', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateProductQuantity(int id, int quantity) async {
    final db = await database;
    return db.update('products', {'quantity': quantity},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Stock Movements ----------------

  Future<int> insertStockMovement(Map<String, dynamic> row) async {
    final db = await database;
    return db.insert('stock_movements', row);
  }

  Future<List<Map<String, dynamic>>> getMovementsForProduct(
      int productId) async {
    final db = await database;
    return db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getRecentMovements() async {
    final db = await database;
    return db.rawQuery('''
      SELECT m.*, p.name AS product_name
      FROM stock_movements m
      LEFT JOIN products p ON p.id = m.product_id
      ORDER BY m.timestamp DESC
    ''');
  }

  // ---------------- Sales (POS) ----------------

  /// Inserts a held sale (`status: 'held'`, `payment_method: null`) plus its
  /// line items in one transaction. Returns the new sale id.
  Future<int> holdSale(
    Map<String, dynamic> saleRow,
    List<Map<String, dynamic>> itemRows,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      final saleId = await txn.insert('sales', saleRow);
      for (final item in itemRows) {
        await txn.insert('sale_items', {...item, 'sale_id': saleId});
      }
      return saleId;
    });
  }

  /// Inserts a completed sale plus its line items, decrements each line's
  /// product quantity, and writes one 'out' stock_movements row per line —
  /// all in one transaction so the sale, the stock levels, and the movement
  /// history never diverge. Throws [StateError] if a line's requested
  /// quantity exceeds the product's current stock (PosProvider validates
  /// this ahead of time; this is a last-resort guard against a race).
  Future<int> checkoutSale(
    Map<String, dynamic> saleRow,
    List<Map<String, dynamic>> itemRows,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      final saleId = await txn.insert('sales', saleRow);
      final timestamp = DateTime.now().toIso8601String();

      for (final item in itemRows) {
        await txn.insert('sale_items', {...item, 'sale_id': saleId});

        final productId = item['product_id'] as int;
        final requestedQuantity = item['quantity'] as int;
        final productRows = await txn.query(
          'products',
          columns: ['quantity'],
          where: 'id = ?',
          whereArgs: [productId],
        );
        final availableQuantity = productRows.isEmpty
            ? 0
            : productRows.first['quantity'] as int;
        if (requestedQuantity > availableQuantity) {
          throw StateError(
            'Insufficient stock for product $productId: '
            'requested $requestedQuantity, available $availableQuantity',
          );
        }

        await txn.update(
          'products',
          {'quantity': availableQuantity - requestedQuantity},
          where: 'id = ?',
          whereArgs: [productId],
        );
        await txn.insert('stock_movements', {
          'product_id': productId,
          'type': 'out',
          'quantity': requestedQuantity,
          'note': 'POS sale #$saleId',
          'timestamp': timestamp,
        });
      }

      return saleId;
    });
  }

  Future<int> deleteSale(int id) async {
    final db = await database;
    return db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getHeldSales() async {
    final db = await database;
    return db.rawQuery('''
      SELECT s.*, (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id) AS item_count
      FROM sales s
      WHERE s.status = 'held'
      ORDER BY s.timestamp DESC
    ''');
  }

  Future<Map<String, dynamic>?> getSaleById(int id) async {
    final db = await database;
    final rows = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT si.*, p.name AS product_name, p.photo_path AS product_photo_path
      FROM sale_items si
      LEFT JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
    ''', [saleId]);
  }

  /// Sold line items for the Sales Report, scoped to completed sales whose
  /// timestamp falls in `[from, toExclusive)` — both plain `yyyy-MM-dd`
  /// strings. A bare date sorts lexicographically before any timestamp on
  /// that same day (`'2026-07-08' < '2026-07-08T10:00:00'`), so [from] is
  /// naturally inclusive of its whole day and passing the day *after* the
  /// desired end date as [toExclusive] makes that day inclusive too.
  Future<List<Map<String, dynamic>>> getSaleItemsInRange(
    String from,
    String toExclusive,
  ) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        si.sale_id AS sale_id,
        si.product_id AS product_id,
        si.quantity AS quantity,
        si.unit_price_at_sale AS unit_price_at_sale,
        si.line_discount AS line_discount,
        s.timestamp AS timestamp,
        p.name AS product_name
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      LEFT JOIN products p ON p.id = si.product_id
      WHERE s.status = 'completed' AND s.timestamp >= ? AND s.timestamp < ?
      ORDER BY s.timestamp DESC
    ''', [from, toExclusive]);
  }

  // ---------------- Dashboard aggregates ----------------

  Future<int> getTotalProductCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products'));
    return result ?? 0;
  }

  Future<double> getTotalStockValue() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT SUM(quantity * unit_price) AS total FROM products');
    final value = result.first['total'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getLowStockCount(int threshold) async {
    final db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM products WHERE quantity <= ?',
      [threshold],
    ));
    return result ?? 0;
  }

  Future<int> getMovementCountForDay(MovementTypeQuery type, String dayPrefix) async {
    final db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery(
      '''SELECT COUNT(*) FROM stock_movements
         WHERE type = ? AND timestamp LIKE ?''',
      [type.value, '$dayPrefix%'],
    ));
    return result ?? 0;
  }

  /// Sums completed sales whose `timestamp` starts with [prefix] — pass a
  /// `yyyy-MM-dd` day or `yyyy-MM` month string. Held (not yet checked out)
  /// sales are excluded since they aren't revenue yet.
  Future<double> getTotalSalesSince(String prefix) async {
    final db = await database;
    final result = await db.rawQuery(
      '''SELECT SUM(total) AS total FROM sales
         WHERE status = 'completed' AND timestamp LIKE ?''',
      ['$prefix%'],
    );
    final value = result.first['total'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  /// Sales Report summary for an arbitrary `[from, toExclusive)` range —
  /// see [getSaleItemsInRange]'s doc for why a bare date string works as a
  /// range bound. `total` sums `sales.total` directly (the real, already
  /// tax-and-discount-inclusive amount) rather than re-deriving it from
  /// `sale_items`, so it always agrees with the dashboard's day/month
  /// totals for the same sales. `discount` combines each sale's whole-sale
  /// discount with the sum of its line-level discounts, mirroring how the
  /// receipt screen's single-sale "Discount" row is built. With `tax`
  /// included, `subtotal - discount + tax == total` for the range.
  Future<({double subtotal, double discount, double tax, double total})>
      getSalesSummaryInRange(String from, String toExclusive) async {
    final db = await database;
    final salesResult = await db.rawQuery(
      '''SELECT
           COALESCE(SUM(subtotal), 0) AS subtotal,
           COALESCE(SUM(discount_amount), 0) AS wholesale_discount,
           COALESCE(SUM(tax_amount), 0) AS tax,
           COALESCE(SUM(total), 0) AS total
         FROM sales
         WHERE status = 'completed' AND timestamp >= ? AND timestamp < ?''',
      [from, toExclusive],
    );
    final lineDiscountResult = await db.rawQuery(
      '''SELECT COALESCE(SUM(si.line_discount), 0) AS line_discount
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id
         WHERE s.status = 'completed' AND s.timestamp >= ? AND s.timestamp < ?''',
      [from, toExclusive],
    );

    final row = salesResult.first;
    final subtotal = (row['subtotal'] as num).toDouble();
    final wholesaleDiscount = (row['wholesale_discount'] as num).toDouble();
    final tax = (row['tax'] as num).toDouble();
    final total = (row['total'] as num).toDouble();
    final lineDiscount =
        (lineDiscountResult.first['line_discount'] as num).toDouble();

    return (
      subtotal: subtotal,
      discount: wholesaleDiscount + lineDiscount,
      tax: tax,
      total: total,
    );
  }

}

enum MovementTypeQuery { stockIn, stockOut }

extension on MovementTypeQuery {
  String get value => this == MovementTypeQuery.stockIn ? 'in' : 'out';
}
