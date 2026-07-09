import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/sale.dart';
import '../../navigation/main_scaffold.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stock_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/cart_line_tile.dart';
import '../../widgets/pos_totals_panel.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  Future<void> _handleHold() async {
    final posProvider = context.read<PosProvider>();
    final settings = context.read<SettingsProvider>();
    await posProvider.hold(settings.taxRatePercent);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sale held')));
    }
  }

  Future<void> _handleCheckout() async {
    final posProvider = context.read<PosProvider>();
    final settings = context.read<SettingsProvider>();
    final totals = posProvider.computeTotals(settings.taxRatePercent);

    final payment = await showDialog<_PaymentSelection>(
      context: context,
      builder: (_) => _PaymentDialog(total: totals.total),
    );
    if (payment == null || !mounted) return;

    final result = await posProvider.checkout(
      liveTaxRatePercent: settings.taxRatePercent,
      method: payment.method,
      amountTendered: payment.amountTendered,
    );

    if (!mounted) return;

    if (result.isShortfall) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Insufficient stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final shortfall in result.shortfalls)
                Text(
                  '${shortfall.productName}: need ${shortfall.requested}, '
                  'have ${shortfall.available}',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await context.read<ProductProvider>().loadProducts();
    if (!mounted) return;

    context.read<StockProvider>().notifyStockChanged();
    context.push(
      '/pos/receipt/${result.saleId}',
      extra: (amountTendered: result.amountTendered, changeDue: result.changeDue),
    );
  }

  /// Current stock for [productId] from the loaded product list, or `null`
  /// if the product no longer exists (checkout still validates stock then).
  int? _availableQuantity(List<Product> products, int productId) {
    for (final product in products) {
      if (product.id == productId) return product.quantity;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<PosProvider>();
    final settings = context.watch<SettingsProvider>();
    final products = context.watch<ProductProvider>().products;
    final totals = posProvider.computeTotals(settings.taxRatePercent);
    final hasStockIssue = posProvider.lines.any((line) {
      final available = _availableQuantity(products, line.productId);
      return available != null && line.quantity > available;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: 'Add Products',
            onPressed: () => context.push('/pos/browse'),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode',
            onPressed: () => context.push('/pos/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Held Sales',
            onPressed: () => context.push('/pos/held'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/pos/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (hasStockIssue)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Some items are out of stock. Restock or remove them to checkout.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: posProvider.lines.isEmpty
                ? const Center(child: Text('Cart is empty'))
                : ListView.builder(
                    itemCount: posProvider.lines.length,
                    itemBuilder: (context, index) {
                      final line = posProvider.lines[index];
                      return CartLineTile(
                        line: line,
                        availableQuantity:
                            _availableQuantity(products, line.productId),
                        onQuantityChanged: (q) =>
                            posProvider.updateLineQuantity(line.productId, q),
                        onPriceChanged: (p) =>
                            posProvider.updateLinePrice(line.productId, p),
                        onDiscountChanged: (type, value) => posProvider
                            .setLineDiscount(line.productId, type, value),
                        onRemove: () => posProvider.removeLine(line.productId),
                      );
                    },
                  ),
          ),
          PosTotalsPanel(
            totals: totals,
            wholeSaleDiscountType: posProvider.wholeSaleDiscountType,
            wholeSaleDiscountValue: posProvider.wholeSaleDiscountValue,
            onWholeSaleDiscountChanged: posProvider.setWholeSaleDiscount,
            onHold: _handleHold,
            onCheckout: _handleCheckout,
            canSubmit: posProvider.lines.isNotEmpty,
            canCheckout: !hasStockIssue,
          ),
        ],
      ),
    );
  }
}

class _PaymentSelection {
  const _PaymentSelection({required this.method, this.amountTendered});

  final PaymentMethod method;
  final double? amountTendered;
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.total});

  final double total;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  PaymentMethod _method = PaymentMethod.cash;
  final _tenderedController = TextEditingController();

  @override
  void dispose() {
    _tenderedController.dispose();
    super.dispose();
  }

  double? get _tendered => double.tryParse(_tenderedController.text);
  double? get _change => _tendered == null ? null : _tendered! - widget.total;

  bool get _canConfirm {
    if (_method == PaymentMethod.card) return true;
    return _tendered != null && _tendered! >= widget.total;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Total: ${formatCurrency(widget.total)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
              ButtonSegment(value: PaymentMethod.card, label: Text('Card')),
            ],
            selected: {_method},
            onSelectionChanged: (selection) =>
                setState(() => _method = selection.first),
          ),
          if (_method == PaymentMethod.cash) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _tenderedController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount tendered',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              _change != null && _change! >= 0
                  ? 'Change: ${formatCurrency(_change!)}'
                  : 'Enter an amount ≥ total',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(_PaymentSelection(
                    method: _method,
                    amountTendered: _method == PaymentMethod.cash ? _tendered : null,
                  ))
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
