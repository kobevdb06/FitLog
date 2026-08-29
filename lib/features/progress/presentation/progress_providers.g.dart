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
          AsyncValue<List<WeekBucket>>,
          List<WeekBucket>,
          Stream<List<WeekBucket>>
        >
    with $FutureModifier<List<WeekBucket>>, $StreamProvider<List<WeekBucket>> {
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
  $StreamProviderElement<List<WeekBucket>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WeekBucket>> create(Ref ref) {
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

String _$weeklyBucketsHash() => r'4c898d3af66b41cdfbc6631d2d1e57dc9e83f5a4';

/// Volume, workouts and sets per calendar week, oldest bucket first.

final class WeeklyBucketsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<WeekBucket>>, int> {
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
