import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.quantity <= kLowStockThreshold;
    final scheme = Theme.of(context).colorScheme;

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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(product.unitPrice),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Qty: ${product.quantity}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLowStock ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: isLowStock ? FontWeight.bold : null,
                  ),
            ),
          ],
        ),
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
