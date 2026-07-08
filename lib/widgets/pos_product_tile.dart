import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/currency_formatter.dart';

/// Compact grid tile for the POS product grid — tapping adds 1 unit to the
/// cart. A separate widget from [ProductTile] (which is a full-width
/// ListTile row, the wrong shape for a grid), though it deliberately
/// mirrors that widget's thumbnail/fallback-icon styling.
class PosProductTile extends StatelessWidget {
  const PosProductTile({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Center(child: _Thumbnail(photoPath: product.photoPath))),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                formatCurrency(product.sellingPrice),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
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
      return CircleAvatar(radius: 28, backgroundImage: FileImage(File(photoPath!)));
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}
