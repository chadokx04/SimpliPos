import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../providers/pos_provider.dart';
import '../../utils/currency_formatter.dart';

/// Post-checkout summary, re-fetched fresh from the DB by [saleId] (mirrors
/// the `/products/:id` re-fetch-by-id convention). [amountTendered]/
/// [changeDue] are only ever available via the constructor — the schema
/// has no column for them, so they're never persisted or re-derived.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({
    super.key,
    required this.saleId,
    this.amountTendered,
    this.changeDue,
  });

  final int saleId;
  final double? amountTendered;
  final double? changeDue;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late Future<_ReceiptData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReceiptData> _load() async {
    final posProvider = context.read<PosProvider>();
    final sale = await posProvider.getSale(widget.saleId);
    final items = await posProvider.getSaleItemsFor(widget.saleId);
    return _ReceiptData(sale: sale, items: items);
  }

  String _formatReceipt(_ReceiptData data) {
    final sale = data.sale!;
    final formattedDate =
        DateFormat.yMMMd().add_jm().format(DateTime.parse(sale.timestamp));
    final buffer = StringBuffer()
      ..writeln('SimpliPos Receipt #${widget.saleId}')
      ..writeln(formattedDate)
      ..writeln('---');
    for (final item in data.items) {
      final lineTotal =
          item.unitPriceAtSale * item.quantity - (item.lineDiscount ?? 0);
      buffer.writeln(
        '${item.productName ?? 'Unknown product'} x${item.quantity} '
        '@ ${formatCurrency(item.unitPriceAtSale)} = '
        '${formatCurrency(lineTotal)}',
      );
    }
    buffer
      ..writeln('---')
      ..writeln('Subtotal: ${formatCurrency(sale.subtotal)}')
      ..writeln('Discount: ${formatCurrency(-data.totalDiscount)}')
      ..writeln(
          'Tax (${sale.taxRateApplied.toStringAsFixed(2)}%): ${formatCurrency(sale.taxAmount)}')
      ..writeln('Total: ${formatCurrency(sale.total)}')
      ..writeln(
          'Payment: ${sale.paymentMethod == PaymentMethod.cash ? 'Cash' : 'Card'}');
    if (widget.amountTendered != null) {
      buffer.writeln('Tendered: ${formatCurrency(widget.amountTendered!)}');
    }
    if (widget.changeDue != null) {
      buffer.writeln('Change: ${formatCurrency(widget.changeDue!)}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Receipt #${widget.saleId}')),
      body: FutureBuilder<_ReceiptData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final sale = data.sale;
          if (sale == null) {
            return const Center(child: Text('Receipt not found'));
          }
          final formattedDate =
              DateFormat.yMMMd().add_jm().format(DateTime.parse(sale.timestamp));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(formattedDate, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final item in data.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName ?? 'Unknown product'),
                  subtitle: Text(
                    '${formatCurrency(item.unitPriceAtSale)} × ${item.quantity}'
                    '${item.lineDiscount != null ? ' (${formatCurrency(-item.lineDiscount!)})' : ''}',
                  ),
                  trailing: Text(
                    formatCurrency(item.unitPriceAtSale * item.quantity -
                        (item.lineDiscount ?? 0)),
                  ),
                ),
              const Divider(),
              _ReceiptRow(label: 'Subtotal', value: sale.subtotal),
              _ReceiptRow(label: 'Discount', value: -data.totalDiscount),
              _ReceiptRow(
                label: 'Tax (${sale.taxRateApplied.toStringAsFixed(2)}%)',
                value: sale.taxAmount,
              ),
              const Divider(),
              _ReceiptRow(label: 'Total', value: sale.total, emphasize: true),
              const SizedBox(height: 8),
              Text(
                'Payment: ${sale.paymentMethod == PaymentMethod.cash ? 'Cash' : 'Card'}',
              ),
              if (widget.amountTendered != null)
                Text('Tendered: ${formatCurrency(widget.amountTendered!)}'),
              if (widget.changeDue != null)
                Text('Change: ${formatCurrency(widget.changeDue!)}'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: _formatReceipt(data),
                    subject: 'Receipt #${widget.saleId}',
                  ),
                ),
                icon: const Icon(Icons.share),
                label: const Text('Share Receipt'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReceiptData {
  final Sale? sale;
  final List<SaleItem> items;

  _ReceiptData({required this.sale, required this.items});

  /// sale.discountAmount is the whole-sale discount only (see Sale doc) —
  /// the receipt's single "Discount" line combines it with every line's
  /// own discount, same as PosTotalsPanel does for the live cart.
  double get totalDiscount {
    final lineDiscountTotal =
        items.fold<double>(0, (sum, item) => sum + (item.lineDiscount ?? 0));
    return (sale?.discountAmount ?? 0) + lineDiscountTotal;
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          // Normalize -0.0 (e.g. -0 discount) so it doesn't render as "-0.00".
          Text(formatCurrency(value == 0 ? 0 : value), style: style),
        ],
      ),
    );
  }
}
