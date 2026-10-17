import '../../../core/db/enums.dart';

/// The set the panel shows, read from what the running app sent.
class PanelSet {
  const PanelSet({
    required this.id,
    required this.exercise,
    required this.label,
    required this.marks,
    required this.hasWeight,
    required this.hasReps,
    required this.hasDuration,
    required this.stepKg,
    required this.outside,
    this.position,
    this.weightKg,
    this.reps,
    this.durationSeconds,
  });

  final String id;
  final String exercise;
  final String label;

  /// `done`, `skipped` or `open`, per working set.
  final List<String> marks;
  final int? position;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final bool hasWeight;
  final bool hasReps;
  final bool hasDuration;
  final double stepKg;

  /// False for a PR attempt or a run: those are for the app.
  final bool outside;

  static PanelSet? from(Object? raw) {
    if (raw is! Map) return null;
    return PanelSet(
      id: raw['id'] as String,
      exercise: raw['exercise'] as String,
      label: raw['label'] as String,
      marks: [for (final mark in raw['marks'] as List? ?? const []) '$mark'],
      position: (raw['position'] as num?)?.toInt(),
      weightKg: (raw['weightKg'] as num?)?.toDouble(),
      reps: (raw['reps'] as num?)?.toInt(),
      durationSeconds: (raw['durationSeconds'] as num?)?.toInt(),
      hasWeight: raw['hasWeight'] == true,
      hasReps: raw['hasReps'] == true,
      hasDuration: raw['hasDuration'] == true,
      stepKg: (raw['stepKg'] as num?)?.toDouble() ?? 2.5,
      outside: raw['outside'] == true,
    );
  }
}

/// Everything the panel needs from the app at once.
class PanelState {
  const PanelState({
    required this.closed,
    required this.unit,
    required this.theme,
    this.title,
    this.set,
  });

  /// The app is gone: there is nothing to show or write to.
  final bool closed;
  final String? title;
  final WeightUnit unit;

  /// `dark`, `light` or `system`, as the app's own setting.
  final String theme;
  final PanelSet? set;

  static PanelState from(Map<Object?, Object?> raw) => PanelState(
    closed: raw['closed'] == true,
    title: raw['title'] as String?,
    unit: WeightUnit.fromWire(raw['unit'] as String? ?? 'kg'),
    theme: raw['theme'] as String? ?? 'dark',
    set: PanelSet.from(raw['set']),
  );
}
