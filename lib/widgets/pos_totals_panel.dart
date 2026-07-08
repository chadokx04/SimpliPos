import 'package:flutter/material.dart';

import '../models/sale.dart';
import '../providers/pos_provider.dart';
import '../utils/currency_formatter.dart';
import 'discount_edit_sheet.dart';

/// Docked Subtotal/Discount/Tax/Total summary + Hold/Checkout actions.
/// The Discount row shows the combined line+whole-sale figure; the clear
/// (x) button only clears the whole-sale portion — per-line discounts are
/// cleared individually from each [CartLineTile]'s own chip.
class PosTotalsPanel extends StatelessWidget {
  const PosTotalsPanel({
    super.key,
    required this.totals,
    required this.wholeSaleDiscountType,
    required this.wholeSaleDiscountValue,
    required this.onWholeSaleDiscountChanged,
    required this.onHold,
    required this.onCheckout,
    required this.canSubmit,
  });

  final PosTotals totals;
  final DiscountType? wholeSaleDiscountType;
  final double? wholeSaleDiscountValue;
  final void Function(DiscountType? type, double? value) onWholeSaleDiscountChanged;
  final VoidCallback onHold;
  final VoidCallback onCheckout;
  final bool canSubmit;

  Future<void> _editWholeSaleDiscount(BuildContext context) async {
    final result = await showModalBottomSheet<(DiscountType, double)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DiscountEditSheet(
        initialType: wholeSaleDiscountType,
        initialValue: wholeSaleDiscountValue,
      ),
    );
    if (result != null) onWholeSaleDiscountChanged(result.$1, result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final hasWholeSaleDiscount =
        wholeSaleDiscountType != null && wholeSaleDiscountValue != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TotalsRow(label: 'Subtotal', value: totals.subtotal),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _editWholeSaleDiscount(context),
                  icon: const Icon(Icons.percent, size: 18),
                  label: Text(hasWholeSaleDiscount ? 'Discount' : 'Add discount'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatCurrency(
                        totals.discountAmount == 0 ? 0 : -totals.discountAmount)),
                    if (hasWholeSaleDiscount)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Clear whole-sale discount',
                        onPressed: () => onWholeSaleDiscountChanged(null, null),
                      ),
                  ],
                ),
              ],
            ),
            _TotalsRow(label: 'Tax', value: totals.taxAmount),
            const Divider(),
            _TotalsRow(label: 'Total', value: totals.total, emphasize: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canSubmit ? onHold : null,
                    child: const Text('Hold'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSubmit ? onCheckout : null,
                    child: const Text('Checkout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.label, required this.value, this.emphasize = false});

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
          Text(formatCurrency(value), style: style),
        ],
      ),
    );
  }
}
