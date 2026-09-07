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
    this.side,
  });

  /// What the SET column shows: `W`, `D`, `F`, or the working set number.
  final String text;

  final SetType type;

  /// Zero-based position among the working sets, or null for a warm-up.
  ///
  /// This is what the VORIGE column matches on: working set 1 of today lines
  /// up with working set 1 of last time, never with a warm-up. While the
  /// exercise is done one side at a time, left and right are numbered
  /// separately, so left set 1 lines up with left set 1.
  final int? workingIndex;

  /// The side this set was done with, or null for both hands at once.
  final SetSide? side;

  bool get isWarmup => type == SetType.warmup;

  @override
  bool operator ==(Object other) =>
      other is SetLabel &&
      other.text == text &&
      other.type == type &&
      other.workingIndex == workingIndex &&
      other.side == side;

  @override
  int get hashCode => Object.hash(text, type, workingIndex, side);

  @override
  String toString() =>
      'SetLabel($text, ${type.wire}, $workingIndex, ${side?.wire})';
}

/// Labels a whole exercise at once.
///
/// Numbering is derived, never stored, so changing one set's type renumbers
/// everything below it on the next build without any bookkeeping.
List<SetLabel> labelSets(Iterable<SetType> types) =>
    labelSetsWithSides([for (final type in types) (type, null)]);

/// The same, for an exercise that may be done one side at a time.
///
/// Each side gets its own count, so a left set and the right set that follows
/// it are both number one. That is what makes the previous column line up:
/// left compares with left.
List<SetLabel> labelSetsWithSides(Iterable<(SetType, SetSide?)> sets) {
  final labels = <SetLabel>[];
  final working = <SetSide?, int>{};

  for (final (type, side) in sets) {
    if (type == SetType.warmup) {
      labels.add(SetLabel(text: 'W', type: type, workingIndex: null, side: side));
      continue;
    }

    final index = working[side] ?? 0;
    working[side] = index + 1;

    final number = type.marker ?? '${index + 1}';
    labels.add(
      SetLabel(
        text: side == null ? number : '$number${side.marker}',
        type: type,
        workingIndex: index,
        side: side,
      ),
    );
  }

  return labels;
}
