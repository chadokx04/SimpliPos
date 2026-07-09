import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_drawer.dart';

/// Opens the drawer owned by [MainScaffold]'s own Scaffold. Each tab screen
/// lives in its own nested Scaffold (for its own AppBar), so `Scaffold.of
/// (context)` from inside one of them resolves to that inner Scaffold, not
/// this outer one — hence a shared key instead of the usual `drawer:` +
/// automatic hamburger-icon pattern. Putting the drawer here rather than on
/// each inner Scaffold also ensures it renders above the bottom
/// NavigationBar, which belongs to this same outer Scaffold.
final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();

/// Bottom-nav shell hosting the five top-level tabs: Dashboard, Products,
/// Categories, Reports, POS. Each tab keeps its own navigation state via
/// [StatefulShellRoute.indexedStack].
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: mainScaffoldKey,
      // No text input lives directly on this outer shell — only the tab
      // screens' own (inner) Scaffolds do, and each of those already
      // decides its own keyboard-resize behavior. Without this, a keyboard
      // opened by an overlay dialog (e.g. the drawer's Reset confirmation)
      // still shrinks this Scaffold's body height, overflowing whichever
      // tab is visible behind the dialog.
      resizeToAvoidBottomInset: false,
      drawer: const AppDrawer(),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
        ],
      ),
    );
  }
}
