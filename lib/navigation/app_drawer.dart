import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../providers/pos_provider.dart';
import '../utils/product_photo_store.dart';
import 'restart_widget.dart';
import 'root_navigator_key.dart';

/// Side navigation drawer shared by every top-level tab screen.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _handleReset(BuildContext context) async {
    Navigator.of(context).pop();

    // From here on, look up the app's root-navigator context fresh each
    // time rather than reusing this drawer's own — the drawer's closing
    // animation finishes (unmounting this context) well before the user
    // finishes typing the confirmation phrase below, and a stale context
    // silently no-ops instead of doing anything (this — the "nothing
    // happens" bug — is exactly what reusing `context` here used to
    // cause). rootNavigatorKey's context stays valid for the app's whole
    // lifetime, unlike this drawer's.
    final confirmed = await showDialog<bool>(
      context: rootNavigatorKey.currentContext!,
      builder: (_) => const _ResetConfirmDialog(),
    );
    if (confirmed != true) return;

    // Reset scope is inventory/sales data only — App Lock, tax rate, and
    // existing backups are left alone (a reset shouldn't lock you out or
    // destroy your one way to undo it).
    await DatabaseHelper.instance.resetDatabase();
    await ProductPhotoStore.deleteAll();
    rootNavigatorKey.currentContext!.read<PosProvider>().clearCart();

    await showDialog<void>(
      context: rootNavigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Data deleted'),
        content: const Text(
          'The app needs to restart so every screen reloads with the '
          'now-empty data.',
        ),
        actions: [
          FilledButton(
            onPressed: () => RestartWidget.restartApp(context),
            child: const Text('Restart Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit SimpliPos?'),
        content: const Text('This will close the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: scheme.surfaceContainer),
              child: Row(
                children: [
                  Image.asset(
                    'assets/branding/app_icon_foreground.png',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SimpliPos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final info = snapshot.data;
                          if (info == null) return const SizedBox.shrink();
                          return Text(
                            'v${info.version} (${info.buildNumber})',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/about');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('App Lock'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/app-lock');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Backup & Restore'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/backup-restore');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
                    title: Text('Reset', style: TextStyle(color: scheme.error)),
                    onTap: () => _handleReset(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Exit'),
              onTap: () => _confirmExit(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Requires typing an exact confirmation phrase before "Delete All Data"
/// enables — a much higher bar than a plain Cancel/Confirm dialog, since
/// there's no undo (aside from restoring a prior backup, which this dialog
/// reminds the user of).
class _ResetConfirmDialog extends StatefulWidget {
  const _ResetConfirmDialog();

  @override
  State<_ResetConfirmDialog> createState() => _ResetConfirmDialogState();
}

class _ResetConfirmDialogState extends State<_ResetConfirmDialog> {
  static const _confirmPhrase = 'delete all data';
  final _controller = TextEditingController();
  bool _isMatch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete all data?'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes every product, category, stock '
            'movement, and sale — and all product photos. Existing backups '
            'are not affected. This cannot be undone.',
          ),
          const SizedBox(height: 16),
          Text(
            'Type "$_confirmPhrase" to continue:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (value) => setState(
              () => _isMatch = value.trim().toLowerCase() == _confirmPhrase,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isMatch ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete All Data'),
        ),
      ],
    );
  }
}
