import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/sales_report_entry.dart';

/// Sub Total/Discount/Tax/Total summary, matching the record type
/// SalesReportScreen builds from PosProvider.getSalesSummaryForRange.
typedef SalesReportSummary = ({
  double subtotal,
  double discount,
  double tax,
  double total,
});

/// Builds a .xlsx workbook for the Sales Report — used by both the Share
/// and Export actions, which each just hand the resulting file to
/// share_plus / file_saver respectively.
class SalesReportExportService {
  static Future<File> generateExcel({
    required List<SalesReportEntry> entries,
    required SalesReportSummary summary,
    required DateTime from,
    required DateTime to,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet()!;
    excel.rename(defaultSheetName, 'Sales Report');
    final sheet = excel['Sales Report'];

    final rangeFormat = DateFormat.yMMMd();
    final entryDateFormat = DateFormat.yMMMd().add_jm();

    sheet.appendRow([
      TextCellValue(
        'Sales Report: ${rangeFormat.format(from)} - ${rangeFormat.format(to)}',
      ),
    ]);
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('Product'),
      TextCellValue('Quantity'),
      TextCellValue('Date Sold'),
      TextCellValue('Sale #'),
      TextCellValue('Line Total'),
    ]);
    for (final entry in entries) {
      sheet.appendRow([
        TextCellValue(entry.productName ?? 'Unknown product'),
        IntCellValue(entry.quantity),
        TextCellValue(entryDateFormat.format(DateTime.parse(entry.timestamp))),
        IntCellValue(entry.saleId),
        DoubleCellValue(entry.lineTotal),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Sub Total'), DoubleCellValue(summary.subtotal)]);
    sheet.appendRow([TextCellValue('Discount'), DoubleCellValue(-summary.discount)]);
    sheet.appendRow([TextCellValue('Tax'), DoubleCellValue(summary.tax)]);
    sheet.appendRow([TextCellValue('Total Amount'), DoubleCellValue(summary.total)]);

    final bytes = excel.encode()!;
    final tempDir = await getTemporaryDirectory();
    final fileNameFormat = DateFormat('yyyy-MM-dd');
    final fileName = 'sales_report_${fileNameFormat.format(from)}'
        '_to_${fileNameFormat.format(to)}.xlsx';
    final file = File(p.join(tempDir.path, fileName));
    return file.writeAsBytes(bytes);
  }
}
