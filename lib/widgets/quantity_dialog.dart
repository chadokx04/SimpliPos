import 'package:flutter/material.dart';

/// Prompts for a positive integer quantity, returning it via
/// `Navigator.pop` (or `null` if cancelled/dismissed). Used by the POS
/// product grid and barcode scanner to ask how many units to add.
class QuantityDialog extends StatefulWidget {
  const QuantityDialog({
    super.key,
    required this.productName,
    this.maxQuantity,
  });

  final String productName;

  /// Upper bound for the entered quantity — the product's available stock
  /// minus whatever is already in the cart. `null` means no limit.
  final int? maxQuantity;

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

  bool get _exceedsMax {
    final quantity = _quantity;
    final max = widget.maxQuantity;
    return quantity != null && max != null && quantity > max;
  }

  bool get _isValid {
    final quantity = _quantity;
    return quantity != null && quantity > 0 && !_exceedsMax;
  }

  void _confirm() {
    if (!_isValid) return;
    Navigator.of(context).pop(_quantity);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.productName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Quantity',
          border: const OutlineInputBorder(),
          helperText: widget.maxQuantity != null
              ? '${widget.maxQuantity} available'
              : null,
          errorText:
              _exceedsMax ? 'Only ${widget.maxQuantity} available' : null,
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
          onPressed: _isValid ? _confirm : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
