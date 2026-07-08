import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../providers/product_provider.dart';
import '../../providers/stock_provider.dart';

class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({super.key, required this.productId, required this.type});

  final int productId;
  final MovementType type;

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  Product? _product;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorText;

  bool get _isStockIn => widget.type == MovementType.stockIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final product = await context.read<ProductProvider>().getProduct(widget.productId);
    if (mounted) {
      setState(() {
        _product = product;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _product == null) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final quantity = int.parse(_quantityController.text);
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    final stockProvider = context.read<StockProvider>();

    try {
      if (_isStockIn) {
        await stockProvider.stockIn(
          productId: _product!.id!,
          currentQuantity: _product!.quantity,
          quantity: quantity,
          note: note,
        );
      } else {
        await stockProvider.stockOut(
          productId: _product!.id!,
          currentQuantity: _product!.quantity,
          quantity: quantity,
          note: note,
        );
      }
      // StockProvider updates the product's quantity directly in the
      // database; refresh ProductProvider's cached list so the Products
      // screen and Dashboard reflect the new quantity immediately.
      if (mounted) {
        await context.read<ProductProvider>().loadProducts();
      }
      if (mounted) context.pop();
    } on ArgumentError catch (e) {
      setState(() {
        _errorText = e.message as String;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isStockIn ? 'Stock In' : 'Stock Out';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Product not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_product!.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Current quantity: ${_product!.quantity}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _isStockIn ? 'Quantity to add' : 'Quantity to remove',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a quantity greater than 0';
                if (!_isStockIn && n > _product!.quantity) {
                  return 'Cannot remove more than the current stock (${_product!.quantity})';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(title),
            ),
          ],
        ),
      ),
    );
  }
}
