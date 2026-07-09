import 'dart:io';

import 'package:flutter/material.dart';

import '../models/cart_line.dart';
import '../models/sale.dart';
import '../utils/currency_formatter.dart';
import 'cart_line_edit_sheet.dart';
import 'discount_edit_sheet.dart';

class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.line,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onDiscountChanged,
    required this.onRemove,
    this.availableQuantity,
  });

  final CartLine line;

  /// The product's current stock, used to cap quantity edits. `null` (e.g.
  /// product since deleted) leaves the edit uncapped — checkout still
  /// validates stock as the final backstop.
  final int? availableQuantity;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<double> onPriceChanged;
  final void Function(DiscountType? type, double? value) onDiscountChanged;
  final VoidCallback onRemove;

  Future<void> _editQuantity(BuildContext context) async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CartLineEditSheet(
        title: 'Quantity — ${line.productName}',
        initialValue: line.quantity.toDouble(),
        maxValue: availableQuantity?.toDouble(),
      ),
    );
    if (result != null) onQuantityChanged(result.round());
  }

  Future<void> _editPrice(BuildContext context) async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CartLineEditSheet(
        title: 'Price — ${line.productName}',
        initialValue: line.unitPrice,
        allowDecimal: true,
      ),
    );
    if (result != null) onPriceChanged(result);
  }

  Future<void> _editDiscount(BuildContext context) async {
    final result = await showModalBottomSheet<(DiscountType, double)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DiscountEditSheet(
        initialType: line.discountType,
        initialValue: line.discountValue,
      ),
    );
    if (result != null) onDiscountChanged(result.$1, result.$2);
  }

  /// True when this line asks for more than the product currently has in
  /// stock (including exactly 0 available) — surfaced so a resumed held
  /// sale can't be checked out against stock that ran out while it sat on
  /// hold. `null` [availableQuantity] (e.g. product since deleted) is left
  /// unflagged here; checkout still validates it as the final backstop.
  bool get _insufficientStock =>
      availableQuantity != null && line.quantity > availableQuantity!;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = line.discountType != null && line.discountValue != null;
    final discountLabel = hasDiscount
        ? (line.discountType == DiscountType.percent
            ? '${line.discountValue!.toStringAsFixed(0)}% off'
            : '${formatCurrency(line.discountValue!)} off')
        : null;
    final hasPhoto = line.photoPath != null && File(line.photoPath!).existsSync();
    final scheme = Theme.of(context).colorScheme;
    final insufficientStock = _insufficientStock;

    return ListTile(
      onTap: () => _editQuantity(context),
      tileColor: insufficientStock ? scheme.errorContainer.withValues(alpha: 0.4) : null,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor:
            insufficientStock ? scheme.errorContainer : scheme.secondaryContainer,
        backgroundImage: hasPhoto ? FileImage(File(line.photoPath!)) : null,
        child: hasPhoto
            ? null
            : Icon(
                insufficientStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                color: insufficientStock ? scheme.onErrorContainer : scheme.onSecondaryContainer,
              ),
      ),
      title: Text(line.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${formatCurrency(line.unitPrice)} × ${line.quantity}'),
          if (discountLabel != null)
            InputChip(
              visualDensity: VisualDensity.compact,
              label: Text(discountLabel),
              onDeleted: () => onDiscountChanged(null, null),
            ),
          if (insufficientStock)
            Text(
              availableQuantity == 0
                  ? 'Out of stock'
                  : 'Only $availableQuantity in stock',
              style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(line.lineTotal),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          PopupMenuButton<String>(
            onSelected: (choice) {
              switch (choice) {
                case 'price':
                  _editPrice(context);
                case 'discount':
                  _editDiscount(context);
                case 'remove':
                  onRemove();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'price', child: Text('Override price')),
              PopupMenuItem(value: 'discount', child: Text('Discount')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}
