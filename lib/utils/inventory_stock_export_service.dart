import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/product.dart';

/// Builds a .xlsx workbook for the Inventory Stock report — used by both
/// the Share and Export actions, mirroring SalesReportExportService.
class InventoryStockExportService {
  static Future<File> generateExcel(List<Product> products) async {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet()!;
    excel.rename(defaultSheetName, 'Inventory Stock');
    final sheet = excel['Inventory Stock'];

    sheet.appendRow([
      TextCellValue('Product'),
      TextCellValue('SKU'),
      TextCellValue('Barcode'),
      TextCellValue('Category'),
      TextCellValue('Quantity'),
    ]);
    for (final product in products) {
      sheet.appendRow([
        TextCellValue(product.name),
        TextCellValue(product.sku),
        TextCellValue(product.barcode ?? ''),
        TextCellValue(product.categoryName ?? 'Uncategorized'),
        IntCellValue(product.quantity),
      ]);
    }

    final bytes = excel.encode()!;
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'inventory_stock_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
    final file = File(p.join(tempDir.path, fileName));
    return file.writeAsBytes(bytes);
  }
}
