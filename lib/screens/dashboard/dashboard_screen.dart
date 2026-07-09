import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/stock_movement.dart';
import '../../navigation/main_scaffold.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/stock_provider.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;
  late Future<List<StockMovement>> _movementsFuture;
  ProductProvider? _productProvider;
  StockProvider? _stockProvider;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _movementsFuture = _loadMovements();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The dashboard lives inside an IndexedStack tab, so initState only
    // runs once. Listen directly to the providers so aggregates refresh
    // whenever a product or stock movement changes elsewhere in the app,
    // even while this tab isn't the one being rebuilt by Provider.
    final productProvider = context.read<ProductProvider>();
    final stockProvider = context.read<StockProvider>();
    if (!identical(_productProvider, productProvider)) {
      _productProvider?.removeListener(_onDataChanged);
      _productProvider = productProvider..addListener(_onDataChanged);
    }
    if (!identical(_stockProvider, stockProvider)) {
      _stockProvider?.removeListener(_onDataChanged);
      _stockProvider = stockProvider..addListener(_onDataChanged);
    }
  }

  @override
  void dispose() {
    _productProvider?.removeListener(_onDataChanged);
    _stockProvider?.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {
      _future = _loadData();
      _movementsFuture = _loadMovements();
    });
  }

  Future<_DashboardData> _loadData() async {
    final productProvider = context.read<ProductProvider>();
    final stockProvider = context.read<StockProvider>();
    final posProvider = context.read<PosProvider>();

    final results = await Future.wait([
      productProvider.getTotalProductCount(),
      productProvider.getTotalStockValue(),
      productProvider.getLowStockCount(kLowStockThreshold),
      stockProvider.getTodayStockInCount(),
      stockProvider.getTodayStockOutCount(),
      posProvider.getTodaySalesTotal(),
      posProvider.getMonthSalesTotal(),
    ]);

    return _DashboardData(
      totalProducts: results[0] as int,
      totalStockValue: results[1] as double,
      lowStockCount: results[2] as int,
      todayStockIn: results[3] as int,
      todayStockOut: results[4] as int,
      todaySalesTotal: results[5] as double,
      monthSalesTotal: results[6] as double,
    );
  }

  Future<List<StockMovement>> _loadMovements() {
    return context.read<StockProvider>().getRecentMovements();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
      _movementsFuture = _loadMovements();
    });
    await Future.wait([_future, _movementsFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: [
                          SummaryCard(
                            label: 'Total Products',
                            value: '${data.totalProducts}',
                            icon: Icons.inventory_2_outlined,
                          ),
                          SummaryCard(
                            label: 'Total Stock Value',
                            value: formatCurrency(data.totalStockValue),
                            icon: Icons.currency_exchange,
                            color: Colors.green,
                          ),
                          SummaryCard(
                            label: 'Low Stock Items',
                            value: '${data.lowStockCount}',
                            icon: Icons.warning_amber_outlined,
                            color: data.lowStockCount > 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                          SummaryCard(
                            label: 'Today In / Out',
                            value:
                                '${data.todayStockIn} / ${data.todayStockOut}',
                            icon: Icons.swap_vert,
                          ),
                          SummaryCard(
                            label: 'Total Sales Today',
                            value: formatCurrency(data.todaySalesTotal),
                            icon: Icons.point_of_sale,
                            color: Colors.green,
                          ),
                          SummaryCard(
                            label: 'Total Sales This Month',
                            value: formatCurrency(data.monthSalesTotal),
                            icon: Icons.calendar_month,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Stock Movements',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
                          child: Text('No movement recorded yet'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: movements.length,
                        itemBuilder: (context, index) =>
                            _MovementTile(movement: movements[index]),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardData {
  final int totalProducts;
  final double totalStockValue;
  final int lowStockCount;
  final int todayStockIn;
  final int todayStockOut;
  final double todaySalesTotal;
  final double monthSalesTotal;

  _DashboardData({
    required this.totalProducts,
    required this.totalStockValue,
    required this.lowStockCount,
    required this.todayStockIn,
    required this.todayStockOut,
    required this.todaySalesTotal,
    required this.monthSalesTotal,
  });
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isIn = movement.type == MovementType.stockIn;
    final scheme = Theme.of(context).colorScheme;
    final formattedDate = DateFormat.yMMMd().add_jm().format(
      DateTime.parse(movement.timestamp),
    );
    final label = movement.note?.isNotEmpty == true
        ? movement.note!
        : (isIn ? 'Stock In' : 'Stock Out');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isIn ? scheme.primaryContainer : scheme.errorContainer,
        child: Icon(
          isIn ? Icons.add : Icons.remove,
          color: isIn ? scheme.onPrimaryContainer : scheme.onErrorContainer,
        ),
      ),
      title: Text(movement.productName ?? 'Unknown product'),
      subtitle: Text(
        '$label · ${isIn ? '+' : '-'}${movement.quantity} · $formattedDate',
      ),
    );
  }
}
