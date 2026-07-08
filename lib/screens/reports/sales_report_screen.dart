import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/sales_report_entry.dart';
import '../../providers/pos_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/sales_report_export_service.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

typedef _SalesSummary = ({
  double subtotal,
  double discount,
  double tax,
  double total
});

class _SalesReportScreenState extends State<SalesReportScreen> {
  late DateTime _from;
  late DateTime _to;
  late Future<(List<SalesReportEntry>, _SalesSummary)> _future;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = _to.subtract(const Duration(days: 6));
    _future = _load();
  }

  Future<(List<SalesReportEntry>, _SalesSummary)> _load() async {
    final posProvider = context.read<PosProvider>();
    final entries = await posProvider.getSalesReport(from: _from, to: _to);
    final summary =
        await posProvider.getSalesSummaryForRange(from: _from, to: _to);
    return (entries, summary);
  }

  /// Generates the .xlsx for whatever range/data is currently loaded —
  /// shared by [_shareReport] and [_exportReport] so both always act on
  /// the same up-to-date report rather than something stale.
  Future<File?> _generateExcel() async {
    final (entries, summary) = await _future;
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sales in this date range to export')),
        );
      }
      return null;
    }
    return SalesReportExportService.generateExcel(
      entries: entries,
      summary: summary,
      from: _from,
      to: _to,
    );
  }

  Future<void> _shareReport() async {
    setState(() => _isExporting = true);
    try {
      final file = await _generateExcel();
      if (file == null) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Sales Report'),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Opens the OS's native "Save As" document picker, same mechanism as
  /// Backup & Restore's "Save to device" — a real file write via Storage
  /// Access Framework, not a share action.
  Future<void> _exportReport() async {
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await _generateExcel();
      if (file == null) return;
      await FileSaver.instance.saveAs(
        name: p.basenameWithoutExtension(file.path),
        filePath: file.path,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: _to,
    );
    if (picked == null) return;
    setState(() {
      _from = picked;
      _future = _load();
    });
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _to = picked;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _isExporting ? null : _shareReport,
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export',
            onPressed: _isExporting ? null : _exportReport,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('From: ${dateFormat.format(_from)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('To: ${dateFormat.format(_to)}'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<(List<SalesReportEntry>, _SalesSummary)>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final (entries, summary) = snapshot.data!;
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('No sales in this date range'),
                  );
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          _SummaryRow(
                              label: 'Sub Total', value: summary.subtotal),
                          _SummaryRow(
                              label: 'Discount', value: -summary.discount),
                          _SummaryRow(label: 'Tax', value: summary.tax),
                          const Divider(height: 16),
                          _SummaryRow(
                            label: 'Total Amount',
                            value: summary.total,
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final formattedDate = DateFormat.yMMMd()
                              .add_jm()
                              .format(DateTime.parse(entry.timestamp));
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${entry.productName ?? 'Unknown product'} x${entry.quantity}',
                            ),
                            subtitle:
                                Text('$formattedDate · Sale #${entry.saleId}'),
                            trailing: Text(
                              formatCurrency(entry.lineTotal),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          // Normalize -0.0 (e.g. no discount) so it doesn't render as "-0.00".
          Text(formatCurrency(value == 0 ? 0 : value), style: style),
        ],
      ),
    );
  }
}
