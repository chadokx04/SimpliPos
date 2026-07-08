import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _taxRateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<SettingsProvider>().taxRatePercent;
    _taxRateController = TextEditingController(text: current.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final rate = double.parse(_taxRateController.text);
    await context.read<SettingsProvider>().setTaxRatePercent(rate);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tax rate saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _taxRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tax rate',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0 || n > 100) {
                  return 'Enter a rate between 0 and 100';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
