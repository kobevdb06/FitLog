/// How a set is labelled in the SET column.
///
/// Warm-ups are skipped in the numbering, so the first real set of an exercise
/// is always "1" no matter how many warm-ups sit above it. Drop and failure
/// sets are working sets: they take up a position in the sequence but show
/// their own letter instead of the number.
library;

import '../db/enums.dart';

/// The label plus how the row should be treated.
class SetLabel {
  const SetLabel({
    required this.text,
    required this.type,
    required this.workingIndex,
  });

  /// What the SET column shows: `W`, `D`, `F`, or the working set number.
  final String text;

  final SetType type;

  /// Zero-based position among the working sets, or null for a warm-up.
  ///
  /// This is what the VORIGE column matches on: working set 1 of today lines
  /// up with working set 1 of last time, never with a warm-up.
  final int? workingIndex;

  bool get isWarmup => type == SetType.warmup;

  @override
  bool operator ==(Object other) =>
      other is SetLabel &&
      other.text == text &&
      other.type == type &&
      other.workingIndex == workingIndex;

  @override
  int get hashCode => Object.hash(text, type, workingIndex);

  @override
  String toString() => 'SetLabel($text, ${type.wire}, $workingIndex)';
}

/// Labels a whole exercise at once.
///
/// Numbering is derived, never stored, so changing one set's type renumbers
/// everything below it on the next build without any bookkeeping.
List<SetLabel> labelSets(Iterable<SetType> types) {
  final labels = <SetLabel>[];
  var working = 0;

  for (final type in types) {
    if (type == SetType.warmup) {
      labels.add(
        SetLabel(text: 'W', type: type, workingIndex: null),
      );
      continue;
    }

    final index = working++;
    labels.add(
      SetLabel(
        text: type.marker ?? '${index + 1}',
        type: type,
        workingIndex: index,
      ),
    );
  }

  return labels;
}
