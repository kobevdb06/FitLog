/// Milestones: steps toward something worth counting, and how far along
/// you are toward the next one.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

enum MilestoneKind { workouts, streak, volume, records }

/// The steps of each milestone, smallest first. Volume is in kilograms.
const Map<MilestoneKind, List<double>> kMilestoneSteps = {
  MilestoneKind.workouts: [1, 10, 25, 50, 100, 250, 500],
  MilestoneKind.streak: [4, 12, 26, 52],
  MilestoneKind.volume: [10000, 100000, 500000, 1000000],
  MilestoneKind.records: [1, 10, 25, 50, 100],
};

class Milestone {
  const Milestone({
    required this.kind,
    required this.steps,
    required this.value,
  });

  final MilestoneKind kind;

  /// Smallest first.
  final List<double> steps;
  final double value;

  /// How many steps are behind you.
  int get reached => steps.where((step) => value >= step).length;

  bool get complete => reached == steps.length;

  /// The step you are working toward, or null with all of them reached.
  double? get next => complete ? null : steps[reached];

  /// How far along you are toward [next], from nothing: 37 of 50 is 0.74.
  double get progress => switch (next) {
    null => 1,
    final target => (value / target).clamp(0, 1).toDouble(),
  };

  /// What is left to [next].
  double get remaining => switch (next) {
    null => 0,
    final target => target - value,
  };
}

List<Milestone> milestonesFor({
  required int workouts,
  required int longestStreakWeeks,
  required double volumeKg,
  required int records,
}) => [
  for (final (kind, value) in [
    (MilestoneKind.workouts, workouts.toDouble()),
    (MilestoneKind.streak, longestStreakWeeks.toDouble()),
    (MilestoneKind.volume, volumeKg),
    (MilestoneKind.records, records.toDouble()),
  ])
    Milestone(kind: kind, steps: kMilestoneSteps[kind]!, value: value),
];
