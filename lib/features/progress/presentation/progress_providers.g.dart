// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Volume, workouts and sets per calendar week, oldest bucket first.

@ProviderFor(weeklyBuckets)
final weeklyBucketsProvider = WeeklyBucketsFamily._();

/// Volume, workouts and sets per calendar week, oldest bucket first.

final class WeeklyBucketsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrainingBucket>>,
          List<TrainingBucket>,
          Stream<List<TrainingBucket>>
        >
    with
        $FutureModifier<List<TrainingBucket>>,
        $StreamProvider<List<TrainingBucket>> {
  /// Volume, workouts and sets per calendar week, oldest bucket first.
  WeeklyBucketsProvider._({
    required WeeklyBucketsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'weeklyBucketsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$weeklyBucketsHash();

  @override
  String toString() {
    return r'weeklyBucketsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TrainingBucket>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TrainingBucket>> create(Ref ref) {
    final argument = this.argument as int;
    return weeklyBuckets(ref, weeks: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WeeklyBucketsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$weeklyBucketsHash() => r'93a2d00ae3612a144360f95e91227db518158c45';

/// Volume, workouts and sets per calendar week, oldest bucket first.

final class WeeklyBucketsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TrainingBucket>>, int> {
  WeeklyBucketsFamily._()
    : super(
        retry: null,
        name: r'weeklyBucketsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Volume, workouts and sets per calendar week, oldest bucket first.

  WeeklyBucketsProvider call({int weeks = 8}) =>
      WeeklyBucketsProvider._(argument: weeks, from: this);

  @override
  String toString() => r'weeklyBucketsProvider';
}

/// What Voortgang looks back over.
///
/// A way of looking rather than a setting: it holds while the app is open,
/// across tabs, and starts at three months - long enough for a line to mean
/// something, short enough that last winter does not flatten it.

@ProviderFor(ProgressPeriodChoice)
final progressPeriodChoiceProvider = ProgressPeriodChoiceProvider._();

/// What Voortgang looks back over.
///
/// A way of looking rather than a setting: it holds while the app is open,
/// across tabs, and starts at three months - long enough for a line to mean
/// something, short enough that last winter does not flatten it.
final class ProgressPeriodChoiceProvider
    extends $NotifierProvider<ProgressPeriodChoice, ProgressPeriod> {
  /// What Voortgang looks back over.
  ///
  /// A way of looking rather than a setting: it holds while the app is open,
  /// across tabs, and starts at three months - long enough for a line to mean
  /// something, short enough that last winter does not flatten it.
  ProgressPeriodChoiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressPeriodChoiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressPeriodChoiceHash();

  @$internal
  @override
  ProgressPeriodChoice create() => ProgressPeriodChoice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgressPeriod value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgressPeriod>(value),
    );
  }
}

String _$progressPeriodChoiceHash() =>
    r'c0045caa9e879c3c6052453dace5eda8386d25ad';

/// What Voortgang looks back over.
///
/// A way of looking rather than a setting: it holds while the app is open,
/// across tabs, and starts at three months - long enough for a line to mean
/// something, short enough that last winter does not flatten it.

abstract class _$ProgressPeriodChoice extends $Notifier<ProgressPeriod> {
  ProgressPeriod build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ProgressPeriod, ProgressPeriod>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProgressPeriod, ProgressPeriod>,
              ProgressPeriod,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Volume, workouts and sets per bar of [period], oldest first.

@ProviderFor(trainingBuckets)
final trainingBucketsProvider = TrainingBucketsFamily._();

/// Volume, workouts and sets per bar of [period], oldest first.

final class TrainingBucketsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrainingBucket>>,
          List<TrainingBucket>,
          Stream<List<TrainingBucket>>
        >
    with
        $FutureModifier<List<TrainingBucket>>,
        $StreamProvider<List<TrainingBucket>> {
  /// Volume, workouts and sets per bar of [period], oldest first.
  TrainingBucketsProvider._({
    required TrainingBucketsFamily super.from,
    required ProgressPeriod super.argument,
  }) : super(
         retry: null,
         name: r'trainingBucketsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trainingBucketsHash();

  @override
  String toString() {
    return r'trainingBucketsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TrainingBucket>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TrainingBucket>> create(Ref ref) {
    final argument = this.argument as ProgressPeriod;
    return trainingBuckets(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TrainingBucketsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trainingBucketsHash() => r'b3f6c505e232b1be57be33cf16aba06202a1b131';

/// Volume, workouts and sets per bar of [period], oldest first.

final class TrainingBucketsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<TrainingBucket>>,
          ProgressPeriod
        > {
  TrainingBucketsFamily._()
    : super(
        retry: null,
        name: r'trainingBucketsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Volume, workouts and sets per bar of [period], oldest first.

  TrainingBucketsProvider call(ProgressPeriod period) =>
      TrainingBucketsProvider._(argument: period, from: this);

  @override
  String toString() => r'trainingBucketsProvider';
}

/// The exercises you did most in [period], at most [kMainLifts].
///
/// A stream: the session you just finished is the newest point of the line.

@ProviderFor(mainLifts)
final mainLiftsProvider = MainLiftsFamily._();

/// The exercises you did most in [period], at most [kMainLifts].
///
/// A stream: the session you just finished is the newest point of the line.

final class MainLiftsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MainLift>>,
          List<MainLift>,
          Stream<List<MainLift>>
        >
    with $FutureModifier<List<MainLift>>, $StreamProvider<List<MainLift>> {
  /// The exercises you did most in [period], at most [kMainLifts].
  ///
  /// A stream: the session you just finished is the newest point of the line.
  MainLiftsProvider._({
    required MainLiftsFamily super.from,
    required ProgressPeriod super.argument,
  }) : super(
         retry: null,
         name: r'mainLiftsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mainLiftsHash();

  @override
  String toString() {
    return r'mainLiftsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<MainLift>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MainLift>> create(Ref ref) {
    final argument = this.argument as ProgressPeriod;
    return mainLifts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MainLiftsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mainLiftsHash() => r'525198c848a70a5dd13a3074514d90717fcae105';

/// The exercises you did most in [period], at most [kMainLifts].
///
/// A stream: the session you just finished is the newest point of the line.

final class MainLiftsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<MainLift>>, ProgressPeriod> {
  MainLiftsFamily._()
    : super(
        retry: null,
        name: r'mainLiftsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The exercises you did most in [period], at most [kMainLifts].
  ///
  /// A stream: the session you just finished is the newest point of the line.

  MainLiftsProvider call(ProgressPeriod period) =>
      MainLiftsProvider._(argument: period, from: this);

  @override
  String toString() => r'mainLiftsProvider';
}

/// The working sets per muscle per week of [period], against the stretch
/// as long before it.

@ProviderFor(muscleSets)
final muscleSetsProvider = MuscleSetsFamily._();

/// The working sets per muscle per week of [period], against the stretch
/// as long before it.

final class MuscleSetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MuscleSets>>,
          List<MuscleSets>,
          Stream<List<MuscleSets>>
        >
    with $FutureModifier<List<MuscleSets>>, $StreamProvider<List<MuscleSets>> {
  /// The working sets per muscle per week of [period], against the stretch
  /// as long before it.
  MuscleSetsProvider._({
    required MuscleSetsFamily super.from,
    required ProgressPeriod super.argument,
  }) : super(
         retry: null,
         name: r'muscleSetsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$muscleSetsHash();

  @override
  String toString() {
    return r'muscleSetsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<MuscleSets>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MuscleSets>> create(Ref ref) {
    final argument = this.argument as ProgressPeriod;
    return muscleSets(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MuscleSetsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$muscleSetsHash() => r'b9fe7b2ccb805eedf8e9677a71a12e6380d75d9d';

/// The working sets per muscle per week of [period], against the stretch
/// as long before it.

final class MuscleSetsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<MuscleSets>>, ProgressPeriod> {
  MuscleSetsFamily._()
    : super(
        retry: null,
        name: r'muscleSetsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The working sets per muscle per week of [period], against the stretch
  /// as long before it.

  MuscleSetsProvider call(ProgressPeriod period) =>
      MuscleSetsProvider._(argument: period, from: this);

  @override
  String toString() => r'muscleSetsProvider';
}

/// The current training streak.

@ProviderFor(streak)
final streakProvider = StreakProvider._();

/// The current training streak.

final class StreakProvider
    extends
        $FunctionalProvider<
          AsyncValue<StreakResult>,
          StreakResult,
          FutureOr<StreakResult>
        >
    with $FutureModifier<StreakResult>, $FutureProvider<StreakResult> {
  /// The current training streak.
  StreakProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakHash();

  @$internal
  @override
  $FutureProviderElement<StreakResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StreakResult> create(Ref ref) {
    return streak(ref);
  }
}

String _$streakHash() => r'a0caef91bf4cf4a1a047b02cc2c898b86a7e3b6b';

/// This calendar week in numbers.

@ProviderFor(thisWeekStats)
final thisWeekStatsProvider = ThisWeekStatsProvider._();

/// This calendar week in numbers.

final class ThisWeekStatsProvider
    extends
        $FunctionalProvider<AsyncValue<WeekStats>, WeekStats, Stream<WeekStats>>
    with $FutureModifier<WeekStats>, $StreamProvider<WeekStats> {
  /// This calendar week in numbers.
  ThisWeekStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thisWeekStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thisWeekStatsHash();

  @$internal
  @override
  $StreamProviderElement<WeekStats> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<WeekStats> create(Ref ref) {
    return thisWeekStats(ref);
  }
}

String _$thisWeekStatsHash() => r'692bd8fbdcc17590bc40d5a8b1cc6e8d77633e98';

@ProviderFor(lifetimeStats)
final lifetimeStatsProvider = LifetimeStatsProvider._();

final class LifetimeStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<LifetimeStats>,
          LifetimeStats,
          FutureOr<LifetimeStats>
        >
    with $FutureModifier<LifetimeStats>, $FutureProvider<LifetimeStats> {
  LifetimeStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lifetimeStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lifetimeStatsHash();

  @$internal
  @override
  $FutureProviderElement<LifetimeStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LifetimeStats> create(Ref ref) {
    return lifetimeStats(ref);
  }
}

String _$lifetimeStatsHash() => r'7ff0ededc3837e6f6222742aa246501c4aef546d';

/// Body weight over time, oldest first.

@ProviderFor(bodyWeightSeries)
final bodyWeightSeriesProvider = BodyWeightSeriesProvider._();

/// Body weight over time, oldest first.

final class BodyWeightSeriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChartPoint>>,
          List<ChartPoint>,
          Stream<List<ChartPoint>>
        >
    with $FutureModifier<List<ChartPoint>>, $StreamProvider<List<ChartPoint>> {
  /// Body weight over time, oldest first.
  BodyWeightSeriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bodyWeightSeriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bodyWeightSeriesHash();

  @$internal
  @override
  $StreamProviderElement<List<ChartPoint>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChartPoint>> create(Ref ref) {
    return bodyWeightSeries(ref);
  }
}

String _$bodyWeightSeriesHash() => r'7eef3c67b0a7e17902375ab5aa9c756f4a26ce34';

@ProviderFor(allRecords)
final allRecordsProvider = AllRecordsFamily._();

final class AllRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecordWithExercise>>,
          List<RecordWithExercise>,
          Stream<List<RecordWithExercise>>
        >
    with
        $FutureModifier<List<RecordWithExercise>>,
        $StreamProvider<List<RecordWithExercise>> {
  AllRecordsProvider._({
    required AllRecordsFamily super.from,
    required PrType? super.argument,
  }) : super(
         retry: null,
         name: r'allRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$allRecordsHash();

  @override
  String toString() {
    return r'allRecordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<RecordWithExercise>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RecordWithExercise>> create(Ref ref) {
    final argument = this.argument as PrType?;
    return allRecords(ref, type: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AllRecordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$allRecordsHash() => r'7f5cc7df148e16bfd6c1d54bc5514daa99c17c72';

final class AllRecordsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<RecordWithExercise>>, PrType?> {
  AllRecordsFamily._()
    : super(
        retry: null,
        name: r'allRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AllRecordsProvider call({PrType? type}) =>
      AllRecordsProvider._(argument: type, from: this);

  @override
  String toString() => r'allRecordsProvider';
}

@ProviderFor(latestRecords)
final latestRecordsProvider = LatestRecordsFamily._();

final class LatestRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecordWithExercise>>,
          List<RecordWithExercise>,
          Stream<List<RecordWithExercise>>
        >
    with
        $FutureModifier<List<RecordWithExercise>>,
        $StreamProvider<List<RecordWithExercise>> {
  LatestRecordsProvider._({
    required LatestRecordsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'latestRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$latestRecordsHash();

  @override
  String toString() {
    return r'latestRecordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<RecordWithExercise>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RecordWithExercise>> create(Ref ref) {
    final argument = this.argument as int;
    return latestRecords(ref, limit: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LatestRecordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$latestRecordsHash() => r'9384124e4ad2e99b0ca85af25e906952cb116225';

final class LatestRecordsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<RecordWithExercise>>, int> {
  LatestRecordsFamily._()
    : super(
        retry: null,
        name: r'latestRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LatestRecordsProvider call({int limit = 3}) =>
      LatestRecordsProvider._(argument: limit, from: this);

  @override
  String toString() => r'latestRecordsProvider';
}

/// The exercises that have stalled, the longest first.
///
/// A stream: finishing a workout can end a plateau as easily as start one.

@ProviderFor(plateaus)
final plateausProvider = PlateausProvider._();

/// The exercises that have stalled, the longest first.
///
/// A stream: finishing a workout can end a plateau as easily as start one.

final class PlateausProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExercisePlateau>>,
          List<ExercisePlateau>,
          Stream<List<ExercisePlateau>>
        >
    with
        $FutureModifier<List<ExercisePlateau>>,
        $StreamProvider<List<ExercisePlateau>> {
  /// The exercises that have stalled, the longest first.
  ///
  /// A stream: finishing a workout can end a plateau as easily as start one.
  PlateausProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'plateausProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$plateausHash();

  @$internal
  @override
  $StreamProviderElement<List<ExercisePlateau>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ExercisePlateau>> create(Ref ref) {
    return plateaus(ref);
  }
}

String _$plateausHash() => r'3ebaf477131992ad9e32da737ffa8927f42d078a';

/// The plateau of [exerciseId], or null while it is still going forward.

@ProviderFor(exercisePlateau)
final exercisePlateauProvider = ExercisePlateauFamily._();

/// The plateau of [exerciseId], or null while it is still going forward.

final class ExercisePlateauProvider
    extends
        $FunctionalProvider<
          ExercisePlateau?,
          ExercisePlateau?,
          ExercisePlateau?
        >
    with $Provider<ExercisePlateau?> {
  /// The plateau of [exerciseId], or null while it is still going forward.
  ExercisePlateauProvider._({
    required ExercisePlateauFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'exercisePlateauProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exercisePlateauHash();

  @override
  String toString() {
    return r'exercisePlateauProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ExercisePlateau?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExercisePlateau? create(Ref ref) {
    final argument = this.argument as String;
    return exercisePlateau(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExercisePlateau? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExercisePlateau?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExercisePlateauProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exercisePlateauHash() => r'0728218d8fb8bbff0d8785383e44f56def914788';

/// The plateau of [exerciseId], or null while it is still going forward.

final class ExercisePlateauFamily extends $Family
    with $FunctionalFamilyOverride<ExercisePlateau?, String> {
  ExercisePlateauFamily._()
    : super(
        retry: null,
        name: r'exercisePlateauProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The plateau of [exerciseId], or null while it is still going forward.

  ExercisePlateauProvider call(String exerciseId) =>
      ExercisePlateauProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'exercisePlateauProvider';
}
