import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/inventory_stock_export_service.dart';
import '../../widgets/product_tile.dart';

class InventoryStockReportScreen extends StatefulWidget {
  const InventoryStockReportScreen({super.key});

  @override
  State<InventoryStockReportScreen> createState() =>
      _InventoryStockReportScreenState();
}

class _InventoryStockReportScreenState
    extends State<InventoryStockReportScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedCategoryId;
  bool _isExporting = false;

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

  /// Filtered by search text (name/SKU/barcode) and the category dropdown,
  /// then ordered by category, then product name — matching the report's
  /// fixed display/export order (there's no user-facing sort control here).
  List<Product> _filteredSorted(List<Product> products) {
    var result = products;
    if (_selectedCategoryId != null) {
      result =
          result.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query) ||
            (p.barcode?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    final sorted = List.of(result);
    sorted.sort((a, b) {
      final categoryCompare = (a.categoryName ?? 'Uncategorized')
          .toLowerCase()
          .compareTo((b.categoryName ?? 'Uncategorized').toLowerCase());
      if (categoryCompare != 0) return categoryCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  Future<void> _shareReport(List<Product> products) async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products to export')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final file = await InventoryStockExportService.generateExcel(products);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Inventory Stock'),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportReport(List<Product> products) async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products to export')),
      );
      return;
    }
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await InventoryStockExportService.generateExcel(products);
      await FileSaver.instance.saveAs(
        name: p.basenameWithoutExtension(file.path),
        filePath: file.path,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        final products = _filteredSorted(provider.products);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Inventory Stock'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
                onPressed:
                    _isExporting ? null : () => _shareReport(products),
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Export',
                onPressed:
                    _isExporting ? null : () => _exportReport(products),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    TextField(
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
                                  setState(() => _searchQuery = '');
                                },
                              ),
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: 8),
                    Consumer<CategoryProvider>(
                      builder: (context, categoryProvider, _) {
                        return DropdownButtonFormField<int?>(
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Category'),
                            ),
                            ...categoryProvider.categories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedCategoryId = value),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: provider.isLoading && provider.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                  ? Center(
                      child: Text(
                        provider.products.isEmpty
                            ? 'No products yet.'
                            : 'No products match your search.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductTile(
                          product: product,
                          showPrice: false,
                          onTap: () =>
                              context.push('/products/${product.id}'),
                        );
                      },
                    ),
        );
      },
    );
  }
}
