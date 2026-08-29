import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'keypad_value.dart';
import 'numeric_keypad.dart';

/// Opens the custom keypad as a bottom sheet and returns the value.
///
/// Used everywhere a single number is edited outside the active workout
/// screen - routine targets, measurements, the bar weight in settings - so the
/// system keyboard never appears for a number anywhere in the app.
///
/// Returns `null` when the sheet is dismissed, and a [KeypadValue] otherwise;
/// an empty value means "clear this field".
Future<KeypadValue?> showKeypadSheet({
  required BuildContext context,
  required KeypadFieldKind kind,
  KeypadValue initialValue = const KeypadValue.empty(),
  String? unitLabel,
  String? title,
  List<double>? steps,
}) {
  return showModalBottomSheet<KeypadValue>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => _KeypadSheet(
      kind: kind,
      initialValue: initialValue,
      unitLabel: unitLabel,
      title: title,
      steps: steps,
    ),
  );
}

class _KeypadSheet extends StatefulWidget {
  const _KeypadSheet({
    required this.kind,
    required this.initialValue,
    this.unitLabel,
    this.title,
    this.steps,
  });

  final KeypadFieldKind kind;
  final KeypadValue initialValue;
  final String? unitLabel;
  final String? title;
  final List<double>? steps;

  @override
  State<_KeypadSheet> createState() => _KeypadSheetState();
}

class _KeypadSheetState extends State<_KeypadSheet> {
  late KeypadValue _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: NumericKeypad(
        value: _value,
        kind: widget.kind,
        unitLabel: widget.unitLabel,
        title: widget.title,
        steps: widget.steps,
        onChanged: (next) => setState(() => _value = next),
        onDone: () => Navigator.of(context).pop(_value),
      ),
    );
  }
}
