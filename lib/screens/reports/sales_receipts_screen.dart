import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/sale.dart';
import '../../providers/pos_provider.dart';
import '../../utils/currency_formatter.dart';

/// Sales Receipts report: every completed sale in a chosen date range,
/// newest first. Tapping a sale opens the same receipt screen the POS
/// shows after checkout, from which it can be shared or downloaded.
class SalesReceiptsScreen extends StatefulWidget {
  const SalesReceiptsScreen({super.key});

  @override
  State<SalesReceiptsScreen> createState() => _SalesReceiptsScreenState();
}

class _SalesReceiptsScreenState extends State<SalesReceiptsScreen> {
  late DateTime _from;
  late DateTime _to;
  late Future<List<Sale>> _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = _to.subtract(const Duration(days: 6));
    _future = _load();
  }

  Future<List<Sale>> _load() {
    return context
        .read<PosProvider>()
        .getCompletedSalesInRange(from: _from, to: _to);
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: _to,
    );
    if (picked == null) return;
    setState(() {
      _from = picked;
      _future = _load();
    });
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _to = picked;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Receipts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('From: ${dateFormat.format(_from)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('To: ${dateFormat.format(_to)}'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sales = snapshot.data!;
                if (sales.isEmpty) {
                  return const Center(
                    child: Text('No sales in this date range'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    final formattedDate = DateFormat.yMMMd()
                        .add_jm()
                        .format(DateTime.parse(sale.timestamp));
                    final itemCount = sale.itemCount ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('Sale #${sale.id}'),
                      subtitle: Text(
                        '$formattedDate · '
                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                      ),
                      trailing: Text(
                        formatCurrency(sale.total),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      onTap: () => context.push('/pos/receipt/${sale.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
