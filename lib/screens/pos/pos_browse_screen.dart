import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/category_strip.dart';
import '../../widgets/pos_product_tile.dart';
import '../../widgets/quantity_dialog.dart';

/// Full-screen category/product picker for the POS, reached from
/// [PosScreen] via a button so the cart view can stay maximized.
/// Tapping a product adds it to the cart without leaving this screen.
class PosBrowseScreen extends StatefulWidget {
  const PosBrowseScreen({super.key});

  @override
  State<PosBrowseScreen> createState() => _PosBrowseScreenState();
}

class _PosBrowseScreenState extends State<PosBrowseScreen> {
  int? _selectedCategoryId;

  Future<void> _handleProductTap(Product product) async {
    final quantity = await showDialog<int>(
      context: context,
      builder: (_) => QuantityDialog(productName: product.name),
    );
    if (quantity == null || !mounted) return;

    context.read<PosProvider>().addOrIncrementProduct(product, quantity: quantity);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final allProducts = context.watch<ProductProvider>().products;
    // Nothing to sell (no stock) or no price set — not orderable, so keep
    // them out of the POS picker even though they still show in Products.
    final sellableProducts =
        allProducts.where((p) => p.sellingPrice > 0 && p.quantity > 0);
    final products = _selectedCategoryId == null
        ? sellableProducts.toList()
        : sellableProducts.where((p) => p.categoryId == _selectedCategoryId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Products'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CategoryStrip(
              categories: categories,
              selectedCategoryId: _selectedCategoryId,
              onSelected: (id) => setState(() => _selectedCategoryId = id),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('No products in this category'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return PosProductTile(
                        product: product,
                        onTap: () => _handleProductTap(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
