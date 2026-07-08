import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:simplipos/app.dart';
import 'package:simplipos/providers/category_provider.dart';
import 'package:simplipos/providers/product_provider.dart';
import 'package:simplipos/providers/stock_provider.dart';

void main() {
  testWidgets('SimpliPos app loads the dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProductProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
          ChangeNotifierProvider(create: (_) => StockProvider()),
        ],
        child: const SimpliPosApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard'), findsWidgets);
  });
}
