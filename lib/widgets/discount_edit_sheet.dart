import 'package:flutter/material.dart';

import '../models/sale.dart';
import 'numeric_keypad.dart';

/// Bottom sheet for entering a fixed-amount or percentage discount, reused
/// for both per-line and whole-sale discounts. Pops a `(DiscountType,
/// double)` record on Confirm, or null if dismissed without one — clearing
/// an existing discount is a separate affordance on the discount chip
/// itself, not handled here, so dismissing this sheet never looks like an
/// accidental clear.
class DiscountEditSheet extends StatefulWidget {
  const DiscountEditSheet({super.key, this.initialType, this.initialValue});

  final DiscountType? initialType;
  final double? initialValue;

  @override
  State<DiscountEditSheet> createState() => _DiscountEditSheetState();
}

class _DiscountEditSheetState extends State<DiscountEditSheet> {
  late DiscountType _type;
  late String _buffer;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? DiscountType.fixed;
    _buffer =
        widget.initialValue != null ? widget.initialValue!.toStringAsFixed(2) : '';
  }

  void _appendDigit(String digit) => setState(() => _buffer += digit);

  void _appendDecimal() {
    if (!_buffer.contains('.')) setState(() => _buffer += '.');
  }

  void _backspace() {
    setState(() {
      if (_buffer.isNotEmpty) _buffer = _buffer.substring(0, _buffer.length - 1);
    });
  }

  double? get _parsedValue => double.tryParse(_buffer);

  @override
  Widget build(BuildContext context) {
    final value = _parsedValue;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Discount', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<DiscountType>(
              segments: const [
                ButtonSegment(value: DiscountType.fixed, label: Text('Fixed (₱)')),
                ButtonSegment(value: DiscountType.percent, label: Text('Percent (%)')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 12),
            Text(
              _buffer.isEmpty ? '0' : _buffer,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            NumericKeypad(
              onDigit: _appendDigit,
              onBackspace: _backspace,
              onDecimal: _appendDecimal,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: value != null && value > 0
                    ? () => Navigator.of(context).pop((_type, value))
                    : null,
                child: const Text('Apply Discount'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
