import 'package:flutter/material.dart';

/// Prompts for a positive integer quantity, returning it via
/// `Navigator.pop` (or `null` if cancelled/dismissed). Used by the POS
/// product grid and barcode scanner to ask how many units to add.
class QuantityDialog extends StatefulWidget {
  const QuantityDialog({super.key, required this.productName});

  final String productName;

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  late final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _quantity => int.tryParse(_controller.text);

  void _confirm() {
    final quantity = _quantity;
    if (quantity == null || quantity <= 0) return;
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.productName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Quantity',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _quantity != null && _quantity! > 0 ? _confirm : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
