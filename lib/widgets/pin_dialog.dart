import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prompts for a 6-digit code, returning it via `Navigator.pop` (or `null`
/// if cancelled/dismissed). With [requireConfirmation], the dialog asks
/// twice and only returns once both entries match — used when setting or
/// changing the code; a mismatch resets back to the first entry rather
/// than erroring out, since this is meant to be quick to retry.
///
/// Pass [validator] (e.g. [AppLockProvider.verifyPin]) when the caller
/// needs the entry checked against something — used for "enter current
/// code" flows. A failing entry shows "Incorrect code" inline, right below
/// the input, the same way an incomplete entry does, and lets the user
/// retry instead of closing the dialog and reporting the error elsewhere.
class PinDialog extends StatefulWidget {
  const PinDialog({
    super.key,
    required this.title,
    this.requireConfirmation = false,
    this.validator,
  });

  final String title;
  final bool requireConfirmation;
  final bool Function(String pin)? validator;

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _controller = TextEditingController();
  String? _firstEntry;
  String? _errorText;

  bool get _isConfirmStage => widget.requireConfirmation && _firstEntry != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value.length != 6) {
      setState(() => _errorText = 'Enter a 6-digit code');
      return;
    }

    // Only meaningful for the first entry — the confirmation stage checks
    // against that first entry instead, further down.
    if (!_isConfirmStage && widget.validator != null && !widget.validator!(value)) {
      setState(() {
        _errorText = 'Incorrect code';
        _controller.clear();
      });
      return;
    }

    if (!widget.requireConfirmation) {
      Navigator.of(context).pop(value);
      return;
    }

    if (_firstEntry == null) {
      setState(() {
        _firstEntry = value;
        _controller.clear();
        _errorText = null;
      });
      return;
    }

    if (value == _firstEntry) {
      Navigator.of(context).pop(value);
    } else {
      setState(() {
        _firstEntry = null;
        _controller.clear();
        _errorText = 'Codes did not match — try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isConfirmStage ? 'Confirm ${widget.title}' : widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        // Without this, obscureText:true makes Flutter default
        // autofillHints to [AutofillHints.password], so the OS/keyboard
        // treats this like a real password field and can auto-fill a
        // previously seen value the instant you type after clearing it.
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
