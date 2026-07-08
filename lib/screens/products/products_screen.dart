import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../navigation/main_scaffold.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_tile.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode',
            onPressed: () => context.push('/products/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add product',
            onPressed: () => context.push('/products/add'),
            style: IconButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, SKU, or barcode',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                context.read<ProductProvider>().setSearchQuery('');
                                setState(() {});
                              },
                            ),
                    ),
                    onChanged: (value) {
                      context.read<ProductProvider>().setSearchQuery(value);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<ProductSortOption>(
                  tooltip: 'Sort by',
                  icon: const Icon(Icons.sort),
                  onSelected: (option) =>
                      context.read<ProductProvider>().setSortOption(option),
                  itemBuilder: (context) {
                    final current = context.read<ProductProvider>().sortOption;
                    return const [
                      MapEntry(ProductSortOption.name, 'Name'),
                      MapEntry(ProductSortOption.category, 'Category'),
                      MapEntry(ProductSortOption.quantity, 'Quantity'),
                      MapEntry(ProductSortOption.price, 'Price'),
                    ]
                        .map((entry) => CheckedPopupMenuItem(
                              value: entry.key,
                              checked: entry.key == current,
                              child: Text(entry.value),
                            ))
                        .toList();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = provider.filteredProducts;
          if (products.isEmpty) {
            return Center(
              child: Text(
                provider.products.isEmpty
                    ? 'No products yet. Tap + to add one.'
                    : 'No products match your search.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.loadProducts,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductTile(
                  product: product,
                  onTap: () => context.push('/products/${product.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
