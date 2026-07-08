import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';

/// Shown in place of the whole app (see app.dart's MaterialApp.router
/// `builder`) whenever App Lock is on and this process hasn't been
/// unlocked yet. Not a route — it deliberately bypasses go_router so it
/// can't be navigated away from by a back gesture or deep link.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = context.read<AppLockProvider>();
    if (provider.verifyPin(_controller.text)) {
      provider.unlock();
      return;
    }
    setState(() {
      _errorText = 'Incorrect code';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('SimpliPos is locked', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Enter your 6-digit code to continue',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  // Without this, obscureText:true makes Flutter default
                  // autofillHints to [AutofillHints.password], so the
                  // OS/keyboard treats this like a real password field and
                  // can auto-fill a previously seen value the instant you
                  // type after clearing it.
                  autofillHints: const [],
                  enableSuggestions: false,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: '',
                    errorText: _errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _submit, child: const Text('Unlock')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
