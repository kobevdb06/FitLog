/// String-backed enums used by the database. The wire values are English and
/// stable; the labels are Dutch and only ever used for display.
library;

enum ExerciseCategory {
  barbell('barbell', 'Barbell', hasWeight: true),
  dumbbell('dumbbell', 'Dumbbell', hasWeight: true),
  machine('machine', 'Machine', hasWeight: true),
  cable('cable', 'Kabel', hasWeight: true),
  bodyweight('bodyweight', 'Lichaamsgewicht', hasWeight: false),
  assistedBodyweight(
    'assisted_bodyweight',
    'Geassisteerd',
    hasWeight: true,
  ),
  duration('duration', 'Tijd', hasWeight: false, hasDuration: true),
  cardio('cardio', 'Cardio', hasWeight: false, hasDuration: true, hasDistance: true);

  const ExerciseCategory(
    this.wire,
    this.label, {
    required this.hasWeight,
    this.hasDuration = false,
    this.hasDistance = false,
  });

  final String wire;
  final String label;

  /// Whether a weight column makes sense for this category.
  final bool hasWeight;

  /// Whether a duration column makes sense.
  final bool hasDuration;

  /// Whether a distance column makes sense.
  final bool hasDistance;

  /// Whether a reps column makes sense.
  bool get hasReps => !hasDuration && !hasDistance;

  static ExerciseCategory fromWire(String value) => values.firstWhere(
    (e) => e.wire == value,
    orElse: () => ExerciseCategory.barbell,
  );
}

enum SetType {
  warmup('warmup', 'Warming-up', 'W'),
  normal('normal', 'Normaal', null),
  drop('drop', 'Dropset', 'D'),
  failure('failure', 'Tot falen', 'F');

  const SetType(this.wire, this.label, this.marker);

  final String wire;
  final String label;

  /// Shown instead of the set number. `null` means: show the number.
  final String? marker;

  /// Warm-up sets never count towards volume or personal records.
  bool get countsTowardsVolume => this != SetType.warmup;

  static SetType fromWire(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => SetType.normal);
}

enum PrType {
  maxWeight('max_weight', 'Zwaarste gewicht'),
  est1rm('est_1rm', 'Geschatte 1RM'),
  maxSetVolume('max_set_volume', 'Beste setvolume'),
  maxReps('max_reps', 'Meeste reps');

  const PrType(this.wire, this.label);

  final String wire;
  final String label;

  static PrType fromWire(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => PrType.maxWeight);
}

enum MeasurementType {
  weight('weight', 'Gewicht', MeasurementUnit.kg),
  bodyFat('body_fat', 'Vetpercentage', MeasurementUnit.percent),
  neck('neck', 'Nek', MeasurementUnit.cm),
  chest('chest', 'Borst', MeasurementUnit.cm),
  waist('waist', 'Taille', MeasurementUnit.cm),
  hips('hips', 'Heupen', MeasurementUnit.cm),
  leftArm('left_arm', 'Arm links', MeasurementUnit.cm),
  rightArm('right_arm', 'Arm rechts', MeasurementUnit.cm),
  leftThigh('left_thigh', 'Dij links', MeasurementUnit.cm),
  rightThigh('right_thigh', 'Dij rechts', MeasurementUnit.cm),
  leftCalf('left_calf', 'Kuit links', MeasurementUnit.cm),
  rightCalf('right_calf', 'Kuit rechts', MeasurementUnit.cm);

  const MeasurementType(this.wire, this.label, this.unit);

  final String wire;
  final String label;
  final MeasurementUnit unit;

  static MeasurementType fromWire(String value) => values.firstWhere(
    (e) => e.wire == value,
    orElse: () => MeasurementType.weight,
  );
}

enum MeasurementUnit { kg, cm, percent }

enum PhotoPose {
  front('front', 'Voorkant'),
  side('side', 'Zijkant'),
  back('back', 'Achterkant');

  const PhotoPose(this.wire, this.label);

  final String wire;
  final String label;

  static PhotoPose fromWire(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => PhotoPose.front);
}

enum Sex {
  male('male', 'Man'),
  female('female', 'Vrouw'),
  other('other', 'Anders'),
  undisclosed('undisclosed', 'Liever niet zeggen');

  const Sex(this.wire, this.label);

  final String wire;
  final String label;

  static Sex? fromWire(String? value) {
    if (value == null) return null;
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

enum WeightUnit {
  kg('kg', 'kg'),
  lb('lb', 'lb');

  const WeightUnit(this.wire, this.label);

  final String wire;
  final String label;

  static WeightUnit fromWire(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => WeightUnit.kg);
}

enum LengthUnit {
  cm('cm', 'cm'),
  inch('in', 'in');

  const LengthUnit(this.wire, this.label);

  final String wire;
  final String label;

  static LengthUnit fromWire(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => LengthUnit.cm);
}

enum DistanceUnit {
  km('km', 'km'),
  mi('mi', 'mi');

  const DistanceUnit(this.wire, this.label);

  final String wire;
  final String label;

  static DistanceUnit fromWire(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => DistanceUnit.km);
}


/// How a one-rep-max attempt ended.
enum PrAttemptResult {
  success('success', 'Gelukt'),
  failed('failed', 'Niet gelukt'),
  abandoned('abandoned', 'Afgebroken');

  const PrAttemptResult(this.wire, this.label);

  final String wire;
  final String label;

  static PrAttemptResult? fromWire(String? value) {
    if (value == null) return null;
    for (final r in values) {
      if (r.wire == value) return r;
    }
    return null;
  }
}
