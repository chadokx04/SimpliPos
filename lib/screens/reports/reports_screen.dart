import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/main_scaffold.dart';

/// Landing tab for report views — each report type is a list tile here.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.point_of_sale),
              title: const Text('Sales Report'),
              subtitle: const Text('Sold products for a chosen date range'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/reports/sales'),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Sales Receipts'),
              subtitle: const Text('Receipts for a chosen date range'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/reports/receipts'),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Inventory Stock'),
              subtitle: const Text('Current stock by product and category'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/reports/inventory-stock'),
            ),
          ),
        ],
      ),
    );
  }
}
