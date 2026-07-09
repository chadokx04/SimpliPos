import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/stock_movement.dart';
import '../providers/pos_provider.dart';
import '../providers/product_provider.dart';
import '../screens/about/about_screen.dart';
import '../screens/app_lock/app_lock_settings_screen.dart';
import '../screens/backup/backup_restore_screen.dart';
import '../screens/categories/categories_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/pos/held_sales_screen.dart';
import '../screens/pos/pos_browse_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/pos/receipt_screen.dart';
import '../screens/pos/settings_screen.dart';
import '../screens/products/product_detail_screen.dart';
import '../screens/products/product_form_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/reports/inventory_stock_report_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/sales_receipts_screen.dart';
import '../screens/reports/sales_report_screen.dart';
import '../screens/scanner/scanner_screen.dart';
import '../screens/stock/stock_movement_screen.dart';
import '../widgets/quantity_dialog.dart';
import 'main_scaffold.dart';
import 'root_navigator_key.dart';

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/pos',
            builder: (context, state) => const PosScreen(),
          ),
        ]),
      ],
    ),
    GoRoute(
      path: '/about',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/app-lock',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AppLockSettingsScreen(),
    ),
    GoRoute(
      path: '/backup-restore',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const BackupRestoreScreen(),
    ),
    GoRoute(
      path: '/products/scan',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/pos/browse',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PosBrowseScreen(),
    ),
    GoRoute(
      path: '/pos/scan',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => ScannerScreen(
        onBarcodeDetected: (scanContext, barcode) async {
          final product =
              await scanContext.read<ProductProvider>().findByBarcode(barcode);
          if (!scanContext.mounted) return '';
          if (product == null) {
            return 'No product found for "$barcode"';
          }
          if (product.sellingPrice <= 0 || product.quantity <= 0) {
            return '${product.name} is not available for sale';
          }

          // Cap at stock minus what the cart already holds, so repeated
          // scans of the same product can never exceed what's available.
          final remaining = product.quantity -
              scanContext.read<PosProvider>().quantityInCart(product.id!);
          if (remaining <= 0) {
            return 'All ${product.quantity} in stock of ${product.name} '
                'are already in the cart';
          }

          final quantity = await showDialog<int>(
            context: scanContext,
            builder: (_) => QuantityDialog(
              productName: product.name,
              maxQuantity: remaining,
            ),
          );
          if (!scanContext.mounted) return '';
          if (quantity == null) {
            return 'Cancelled';
          }

          scanContext
              .read<PosProvider>()
              .addOrIncrementProduct(product, quantity: quantity);
          scanContext.go('/pos');
          return 'Added $quantity x ${product.name}';
        },
      ),
    ),
    GoRoute(
      path: '/reports/sales',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SalesReportScreen(),
    ),
    GoRoute(
      path: '/reports/receipts',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SalesReceiptsScreen(),
    ),
    GoRoute(
      path: '/reports/inventory-stock',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const InventoryStockReportScreen(),
    ),
    GoRoute(
      path: '/pos/held',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const HeldSalesScreen(),
    ),
    GoRoute(
      path: '/pos/settings',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/pos/receipt/:saleId',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final saleId = int.parse(state.pathParameters['saleId']!);
        final extras = state.extra as ({double? amountTendered, double? changeDue})?;
        return ReceiptScreen(
          saleId: saleId,
          amountTendered: extras?.amountTendered,
          changeDue: extras?.changeDue,
        );
      },
    ),
    GoRoute(
      path: '/scan/pick',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ScannerScreen(returnResult: true),
    ),
    GoRoute(
      path: '/products/add',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final prefillBarcode = state.extra as String?;
        return ProductFormScreen(prefillBarcode: prefillBarcode);
      },
    ),
    GoRoute(
      path: '/products/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ProductDetailScreen(productId: id);
      },
    ),
    GoRoute(
      path: '/products/:id/edit',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ProductFormScreen(productId: id);
      },
    ),
    GoRoute(
      path: '/products/:id/stock-in',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return StockMovementScreen(productId: id, type: MovementType.stockIn);
      },
    ),
    GoRoute(
      path: '/products/:id/stock-out',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return StockMovementScreen(productId: id, type: MovementType.stockOut);
      },
    ),
  ],
);
