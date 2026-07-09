import 'package:flutter/material.dart';

import 'numeric_keypad.dart';

/// Bottom sheet for editing a cart line's quantity or overriding its price.
/// Pops the entered [double] on Confirm, or null if dismissed without one.
class CartLineEditSheet extends StatefulWidget {
  const CartLineEditSheet({
    super.key,
    required this.title,
    required this.initialValue,
    this.allowDecimal = false,
    this.maxValue,
  });

  final String title;
  final double initialValue;
  final bool allowDecimal;

  /// Upper bound for the entered value (e.g. available stock when editing
  /// a quantity). `null` means no limit.
  final double? maxValue;

  @override
  State<CartLineEditSheet> createState() => _CartLineEditSheetState();
}

class _CartLineEditSheetState extends State<CartLineEditSheet> {
  late String _buffer;

  @override
  void initState() {
    super.initState();
    _buffer = widget.allowDecimal
        ? widget.initialValue.toStringAsFixed(2)
        : widget.initialValue.toStringAsFixed(0);
  }

  void _appendDigit(String digit) {
    setState(() => _buffer = _buffer == '0' ? digit : _buffer + digit);
  }

  void _appendDecimal() {
    if (!_buffer.contains('.')) setState(() => _buffer += '.');
  }

  void _backspace() {
    setState(() {
      _buffer = _buffer.isEmpty ? '' : _buffer.substring(0, _buffer.length - 1);
    });
  }

  double? get _parsedValue => double.tryParse(_buffer);

  @override
  Widget build(BuildContext context) {
    final value = _parsedValue;
    final max = widget.maxValue;
    final exceedsMax = value != null && max != null && value > max;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _buffer.isEmpty ? '0' : _buffer,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (max != null) ...[
              const SizedBox(height: 4),
              Text(
                exceedsMax
                    ? 'Only ${max.toStringAsFixed(0)} available'
                    : '${max.toStringAsFixed(0)} available',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: exceedsMax
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            NumericKeypad(
              onDigit: _appendDigit,
              onBackspace: _backspace,
              onDecimal: widget.allowDecimal ? _appendDecimal : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: value != null && value > 0 && !exceedsMax
                    ? () => Navigator.of(context).pop(value)
                    : null,
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
