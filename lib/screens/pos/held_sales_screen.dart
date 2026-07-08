import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/sale.dart';
import '../../providers/pos_provider.dart';
import '../../utils/currency_formatter.dart';

class HeldSalesScreen extends StatefulWidget {
  const HeldSalesScreen({super.key});

  @override
  State<HeldSalesScreen> createState() => _HeldSalesScreenState();
}

class _HeldSalesScreenState extends State<HeldSalesScreen> {
  late Future<List<Sale>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<PosProvider>().getHeldSales();
  }

  Future<void> _resume(Sale sale) async {
    await context.read<PosProvider>().resume(sale.id!);
    if (mounted) context.pop();
  }

  Future<void> _confirmDelete(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete held sale?'),
        content: Text(
          'This will permanently delete this held sale '
          '(${formatCurrency(sale.total)}). This cannot be undone.',
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

    if (confirmed != true || !mounted) return;
    await context.read<PosProvider>().deleteHeldSale(sale.id!);
    if (mounted) {
      setState(() {
        _future = context.read<PosProvider>().getHeldSales();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Held Sales')),
      body: FutureBuilder<List<Sale>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sales = snapshot.data!;
          if (sales.isEmpty) {
            return const Center(child: Text('No held sales'));
          }
          return ListView.builder(
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];
              final formattedDate = DateFormat.yMMMd()
                  .add_jm()
                  .format(DateTime.parse(sale.timestamp));
              final itemCount = sale.itemCount ?? 0;
              return ListTile(
                title: Text(formatCurrency(sale.total)),
                subtitle: Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'} • $formattedDate',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: () => _resume(sale),
                      child: const Text('Resume'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(sale),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
