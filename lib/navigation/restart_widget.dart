import 'package:flutter/material.dart';

/// Wraps the whole app so it can be soft-restarted from anywhere below it
/// via [RestartWidget.restartApp] — used after a database reset/restore,
/// where every provider's already-loaded in-memory state needs to reload
/// from scratch rather than keep showing pre-reset/restore data.
///
/// Neither Android nor iOS exposes an API for a Flutter app to kill and
/// relaunch its own OS process, so this can't be a "true" restart. Instead,
/// changing this widget's child's key forces Flutter to dispose everything
/// below it — including every Provider, since [main.dart] wraps
/// `MultiProvider` in this widget — and rebuild it fresh, which is
/// functionally equivalent for our purposes (every screen/provider reloads
/// from the now-reset/restored data) without needing the user to manually
/// close and reopen the app.
class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restart();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restart() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
