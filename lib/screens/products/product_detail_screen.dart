import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../providers/product_provider.dart';
import '../../providers/stock_provider.dart';
import '../../utils/currency_formatter.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Product?> _future;
  late Future<List<StockMovement>> _movementsFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _movementsFuture = _loadMovements();
  }

  Future<Product?> _load() {
    return context.read<ProductProvider>().getProduct(widget.productId);
  }

  Future<List<StockMovement>> _loadMovements() {
    return context.read<StockProvider>().getMovementsForProduct(widget.productId);
  }

  void _refresh() {
    setState(() {
      _future = _load();
      _movementsFuture = _loadMovements();
    });
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'This will permanently delete "${product.name}" and its stock movement history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ProductProvider>().deleteProduct(product.id!);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Product?>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final product = snapshot.data;
        if (product == null) {
          return const Scaffold(body: Center(child: Text('Product not found')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await context.push('/products/${product.id}/edit');
                  _refresh();
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(product),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    Center(
                      child: Builder(builder: (context) {
                        final hasPhoto = product.photoPath != null &&
                            File(product.photoPath!).existsSync();
                        final heroTag = 'product-photo-${product.id}';
                        return GestureDetector(
                          onTap: hasPhoto
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _PhotoViewerScreen(
                                        photoPath: product.photoPath!,
                                        heroTag: heroTag,
                                      ),
                                    ),
                                  )
                              : null,
                          child: Hero(
                            tag: heroTag,
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondaryContainer,
                              backgroundImage: hasPhoto
                                  ? FileImage(File(product.photoPath!))
                                  : null,
                              child: hasPhoto
                                  ? null
                                  : const Icon(Icons.inventory_2_outlined, size: 32),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    _InfoRow(label: 'SKU', value: product.sku),
                    _InfoRow(label: 'Barcode', value: product.barcode ?? '—'),
                    _InfoRow(label: 'Category', value: product.categoryName ?? 'Uncategorized'),
                    _InfoRow(label: 'Quantity', value: '${product.quantity}'),
                    _InfoRow(label: 'Unit Price', value: formatCurrency(product.unitPrice)),
                    _InfoRow(label: 'Selling Price', value: formatCurrency(product.sellingPrice)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await context.push('/products/${product.id}/stock-in');
                              _refresh();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Stock In'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              await context.push('/products/${product.id}/stock-out');
                              _refresh();
                            },
                            icon: const Icon(Icons.remove),
                            label: const Text('Stock Out'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Movement History', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<StockMovement>>(
                  future: _movementsFuture,
                  builder: (context, movementsSnapshot) {
                    if (!movementsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final movements = movementsSnapshot.data!;
                    if (movements.isEmpty) {
                      return const Center(
                        child: Text('No stock movements recorded yet.'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: movements.length,
                      itemBuilder: (context, index) =>
                          _MovementTile(movement: movements[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoViewerScreen extends StatelessWidget {
  const _PhotoViewerScreen({required this.photoPath, required this.heroTag});

  final String photoPath;
  final Object heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            maxScale: 4,
            child: Image.file(File(photoPath)),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isIn = movement.type == MovementType.stockIn;
    final scheme = Theme.of(context).colorScheme;
    final formattedDate =
        DateFormat.yMMMd().add_jm().format(DateTime.parse(movement.timestamp));

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isIn
            ? scheme.primaryContainer
            : scheme.errorContainer,
        child: Icon(
          isIn ? Icons.add : Icons.remove,
          color: isIn ? scheme.onPrimaryContainer : scheme.onErrorContainer,
        ),
      ),
      title: Text('${isIn ? '+' : '-'}${movement.quantity}'),
      subtitle: Text(movement.note?.isNotEmpty == true ? movement.note! : formattedDate),
      trailing: movement.note?.isNotEmpty == true
          ? Text(formattedDate, style: Theme.of(context).textTheme.bodySmall)
          : null,
    );
  }
}
