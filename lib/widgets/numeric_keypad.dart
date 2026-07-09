import 'package:flutter/material.dart';

/// Purely presentational 0-9/decimal/backspace grid, reused by
/// [CartLineEditSheet] (quantity/price) and [DiscountEditSheet].
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onDecimal,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onDecimal;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final digit in row)
                _KeypadButton(label: digit, onPressed: () => onDigit(digit)),
            ],
          ),
        Row(
          children: [
            _KeypadButton(
              label: '.',
              onPressed: onDecimal,
              enabled: onDecimal != null,
            ),
            _KeypadButton(label: '0', onPressed: () => onDigit('0')),
            _KeypadButton(icon: Icons.backspace_outlined, onPressed: onBackspace),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({this.label, this.icon, this.onPressed, this.enabled = true});

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AspectRatio(
          aspectRatio: 1.4,
          child: OutlinedButton(
            onPressed: enabled ? onPressed : null,
            child: icon != null
                ? Icon(icon)
                : Text(label!, style: const TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }
}
