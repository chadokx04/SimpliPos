import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.showPrice = true,
  });

  final Product product;
  final VoidCallback onTap;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.quantity <= kLowStockThreshold;
    final scheme = Theme.of(context).colorScheme;
    final qtyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isLowStock ? scheme.error : scheme.onSurfaceVariant,
          fontWeight: isLowStock ? FontWeight.bold : null,
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: _Thumbnail(photoPath: product.photoPath),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${product.sku} • ${product.categoryName ?? 'Uncategorized'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: showPrice
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatCurrency(product.unitPrice)} | '
                    '${formatCurrency(product.sellingPrice)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('Qty: ${product.quantity}', style: qtyStyle),
                ],
              )
            : Text('Qty: ${product.quantity}', style: qtyStyle),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    if (photoPath != null && File(photoPath!).existsSync()) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: FileImage(File(photoPath!)),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}
