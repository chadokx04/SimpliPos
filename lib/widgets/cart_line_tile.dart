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
  });

  final CartLine line;
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

    return ListTile(
      onTap: () => _editQuantity(context),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.secondaryContainer,
        backgroundImage: hasPhoto ? FileImage(File(line.photoPath!)) : null,
        child: hasPhoto
            ? null
            : Icon(Icons.inventory_2_outlined, color: scheme.onSecondaryContainer),
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
