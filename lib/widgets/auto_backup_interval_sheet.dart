import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'numeric_keypad.dart';

enum _IntervalUnit { seconds, minutes }

/// Bottom sheet for picking how often auto backup runs. Pops the chosen
/// interval as a total number of seconds, or null if dismissed without
/// confirming.
class AutoBackupIntervalSheet extends StatefulWidget {
  const AutoBackupIntervalSheet({super.key, required this.initialSeconds});

  final int initialSeconds;

  @override
  State<AutoBackupIntervalSheet> createState() => _AutoBackupIntervalSheetState();
}

class _AutoBackupIntervalSheetState extends State<AutoBackupIntervalSheet> {
  late String _buffer;
  late _IntervalUnit _unit;

  @override
  void initState() {
    super.initState();
    // Open in whichever unit shows the current value as a whole number, so
    // e.g. an interval of 120s opens as "2" minutes rather than "120"
    // seconds.
    if (widget.initialSeconds >= 60 && widget.initialSeconds % 60 == 0) {
      _unit = _IntervalUnit.minutes;
      _buffer = (widget.initialSeconds ~/ 60).toString();
    } else {
      _unit = _IntervalUnit.seconds;
      _buffer = widget.initialSeconds.toString();
    }
  }

  void _appendDigit(String digit) {
    setState(() => _buffer = _buffer == '0' ? digit : _buffer + digit);
  }

  void _backspace() {
    setState(() {
      _buffer = _buffer.isEmpty ? '' : _buffer.substring(0, _buffer.length - 1);
    });
  }

  int? get _enteredValue => int.tryParse(_buffer);

  int? get _totalSeconds {
    final value = _enteredValue;
    if (value == null) return null;
    return _unit == _IntervalUnit.minutes ? value * 60 : value;
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = _totalSeconds;
    final belowMin = totalSeconds != null && totalSeconds < kAutoBackupMinIntervalSeconds;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Auto Backup Interval', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _buffer.isEmpty ? '0' : _buffer,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              belowMin
                  ? 'Minimum is $kAutoBackupMinIntervalSeconds seconds'
                  : 'Runs a backup every ${_enteredValue ?? 0} '
                      '${_unit == _IntervalUnit.minutes ? 'minute(s)' : 'second(s)'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: belowMin ? scheme.error : scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_IntervalUnit>(
              segments: const [
                ButtonSegment(value: _IntervalUnit.seconds, label: Text('Seconds')),
                ButtonSegment(value: _IntervalUnit.minutes, label: Text('Minutes')),
              ],
              selected: {_unit},
              onSelectionChanged: (selection) => setState(() => _unit = selection.first),
            ),
            const SizedBox(height: 16),
            NumericKeypad(onDigit: _appendDigit, onBackspace: _backspace),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: totalSeconds != null && !belowMin
                    ? () => Navigator.of(context).pop(totalSeconds)
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
