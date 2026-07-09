import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation/app_router.dart';
import 'providers/app_lock_provider.dart';
import 'screens/app_lock/app_lock_screen.dart';

class SimpliPosApp extends StatelessWidget {
  const SimpliPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      title: 'SimpliPos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        // Pinned to the same tone the bottom NavigationBar defaults to, so
        // the app bar and footer nav read as one continuous surface.
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surfaceContainer,
          foregroundColor: lightScheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightScheme.surfaceContainer,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surfaceContainer,
          foregroundColor: darkScheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: darkScheme.surfaceContainer,
        ),
      ),
      routerConfig: appRouter,
      // Gates the whole routed app behind AppLockScreen when App Lock is on
      // and this process hasn't been unlocked yet — see AppLockProvider's
      // doc for why this only ever asks once per cold start, not per
      // navigation. While the persisted lock state hasn't loaded yet
      // (isReady == false), show neither screen to avoid a flash of real
      // content before we know whether the lock is even on.
      builder: (context, child) {
        final appLock = context.watch<AppLockProvider>();
        if (!appLock.isReady) {
          return _standaloneScreen(
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (!appLock.shouldShowApp) {
          return _standaloneScreen(const AppLockScreen());
        }
        return child!;
      },
    );
  }

  /// Wraps [screen] in its own minimal [Navigator] rather than returning it
  /// directly. When this replaces `child` in the builder above, `child` —
  /// which is what actually contains go_router's Navigator — is gone from
  /// the tree entirely, so anything relying on an ancestor `Overlay` (text
  /// field selection handles/magnifier, autofill UI) has nowhere to go and
  /// throws "No Overlay widget found". A `Navigator` supplies its own
  /// `Overlay`, so [screen] gets one regardless.
  ///
  /// Keyed by [screen]'s type: `onGenerateRoute` is only consulted when a
  /// *new* route is pushed, not on every rebuild, so swapping which screen
  /// this wraps (e.g. the loading spinner to [AppLockScreen] once
  /// [AppLockProvider.isReady] flips true) would otherwise just update the
  /// existing Navigator in place and leave the first-ever route — whatever
  /// was generated the very first time — stuck on screen forever. A
  /// distinct key per screen type forces Flutter to treat it as a new
  /// Navigator instead.
  Widget _standaloneScreen(Widget screen) {
    return Navigator(
      key: ValueKey(screen.runtimeType),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => screen),
    );
  }
}
