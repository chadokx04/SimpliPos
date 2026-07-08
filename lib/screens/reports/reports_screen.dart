import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/main_scaffold.dart';

/// Landing tab for report views. Only Sales Report exists for now; more
/// report types are expected to be added here as more list tiles.
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
        ],
      ),
    );
  }
}
