import 'package:flutter/material.dart';

/// Shared root Navigator key. Set as GoRouter's `navigatorKey` in
/// app_router.dart; also used directly (via `.currentContext`) anywhere
/// that needs a long-lived, always-mounted BuildContext across an `await`
/// that might outlive some other, more local context — e.g. app_drawer.dart
/// popping the drawer and then awaiting a dialog result, by which point the
/// drawer's own context has been unmounted.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
