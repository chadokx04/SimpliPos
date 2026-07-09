import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../widgets/pin_dialog.dart';

class AppLockSettingsScreen extends StatelessWidget {
  const AppLockSettingsScreen({super.key});

  Future<String?> _askPin(
    BuildContext context,
    String title, {
    bool requireConfirmation = false,
    bool Function(String pin)? validator,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => PinDialog(
        title: title,
        requireConfirmation: requireConfirmation,
        validator: validator,
      ),
    );
  }

  Future<void> _handleToggle(BuildContext context, bool enable) async {
    final provider = context.read<AppLockProvider>();
    if (enable) {
      final pin = await _askPin(context, 'Set App Lock code', requireConfirmation: true);
      if (pin == null || !context.mounted) return;
      await provider.setPin(pin);
      return;
    }

    // validator means the dialog only ever returns once verifyPin passes —
    // "Incorrect code" is shown inline, below the input, by the dialog
    // itself, so a wrong entry just keeps the dialog open for a retry.
    final pin = await _askPin(context, 'Enter current code', validator: provider.verifyPin);
    if (pin == null || !context.mounted) return;
    await provider.disable();
  }

  Future<void> _changePin(BuildContext context) async {
    final provider = context.read<AppLockProvider>();
    final currentPin =
        await _askPin(context, 'Enter current code', validator: provider.verifyPin);
    if (currentPin == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final newPin = await _askPin(context, 'New code', requireConfirmation: true);
    if (newPin == null || !context.mounted) return;
    await provider.setPin(newPin);
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Code updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppLockProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable App Lock'),
            subtitle: const Text('Ask for a 6-digit code every time the app starts'),
            value: provider.isEnabled,
            onChanged: (enable) => _handleToggle(context, enable),
          ),
          if (provider.isEnabled)
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change code'),
              onTap: () => _changePin(context),
            ),
        ],
      ),
    );
  }
}
