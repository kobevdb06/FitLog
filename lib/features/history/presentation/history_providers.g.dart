// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutHistory)
final workoutHistoryProvider = WorkoutHistoryFamily._();

final class WorkoutHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutSummary>>,
          List<WorkoutSummary>,
          Stream<List<WorkoutSummary>>
        >
    with
        $FutureModifier<List<WorkoutSummary>>,
        $StreamProvider<List<WorkoutSummary>> {
  WorkoutHistoryProvider._({
    required WorkoutHistoryFamily super.from,
    required int? super.argument,
  }) : super(
         retry: null,
         name: r'workoutHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutHistoryHash();

  @override
  String toString() {
    return r'workoutHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<WorkoutSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WorkoutSummary>> create(Ref ref) {
    final argument = this.argument as int?;
    return workoutHistory(ref, limit: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutHistoryHash() => r'8f531656932ad7d07071c3d899c50aa72c5fee59';

final class WorkoutHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<WorkoutSummary>>, int?> {
  WorkoutHistoryFamily._()
    : super(
        retry: null,
        name: r'workoutHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkoutHistoryProvider call({int? limit}) =>
      WorkoutHistoryProvider._(argument: limit, from: this);

  @override
  String toString() => r'workoutHistoryProvider';
}

@ProviderFor(workoutDetail)
final workoutDetailProvider = WorkoutDetailFamily._();

final class WorkoutDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutDetail?>,
          WorkoutDetail?,
          Stream<WorkoutDetail?>
        >
    with $FutureModifier<WorkoutDetail?>, $StreamProvider<WorkoutDetail?> {
  WorkoutDetailProvider._({
    required WorkoutDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutDetailHash();

  @override
  String toString() {
    return r'workoutDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WorkoutDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutDetail?> create(Ref ref) {
    final argument = this.argument as String;
    return workoutDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutDetailHash() => r'5be7b8d08dbc18f0ce25e5de2b2e9c07ed313bbc';

final class WorkoutDetailFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WorkoutDetail?>, String> {
  WorkoutDetailFamily._()
    : super(
        retry: null,
        name: r'workoutDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkoutDetailProvider call(String workoutId) =>
      WorkoutDetailProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutDetailProvider';
}

/// Every finished workout inside one month, for the calendar.

@ProviderFor(workoutsInMonth)
final workoutsInMonthProvider = WorkoutsInMonthFamily._();

/// Every finished workout inside one month, for the calendar.

final class WorkoutsInMonthProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutRow>>,
          List<WorkoutRow>,
          Stream<List<WorkoutRow>>
        >
    with $FutureModifier<List<WorkoutRow>>, $StreamProvider<List<WorkoutRow>> {
  /// Every finished workout inside one month, for the calendar.
  WorkoutsInMonthProvider._({
    required WorkoutsInMonthFamily super.from,
    required (int, int) super.argument,
  }) : super(
         retry: null,
         name: r'workoutsInMonthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutsInMonthHash();

  @override
  String toString() {
    return r'workoutsInMonthProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<WorkoutRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WorkoutRow>> create(Ref ref) {
    final argument = this.argument as (int, int);
    return workoutsInMonth(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutsInMonthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutsInMonthHash() => r'5895a7a4aed6c551cb4461d7c946cc8c2edcb896';

/// Every finished workout inside one month, for the calendar.

final class WorkoutsInMonthFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<WorkoutRow>>, (int, int)> {
  WorkoutsInMonthFamily._()
    : super(
        retry: null,
        name: r'workoutsInMonthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Every finished workout inside one month, for the calendar.

  WorkoutsInMonthProvider call(int year, int month) =>
      WorkoutsInMonthProvider._(argument: (year, month), from: this);

  @override
  String toString() => r'workoutsInMonthProvider';
}

/// The dates of every finished workout, used by the streak.

@ProviderFor(finishedWorkoutDates)
final finishedWorkoutDatesProvider = FinishedWorkoutDatesProvider._();

/// The dates of every finished workout, used by the streak.

final class FinishedWorkoutDatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DateTime>>,
          List<DateTime>,
          Stream<List<DateTime>>
        >
    with $FutureModifier<List<DateTime>>, $StreamProvider<List<DateTime>> {
  /// The dates of every finished workout, used by the streak.
  FinishedWorkoutDatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'finishedWorkoutDatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$finishedWorkoutDatesHash();

  @$internal
  @override
  $StreamProviderElement<List<DateTime>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DateTime>> create(Ref ref) {
    return finishedWorkoutDates(ref);
  }
}

String _$finishedWorkoutDatesHash() =>
    r'38e2813b75656a31f7d8d857e2c958aec7e3b51f';

@ProviderFor(historyActions)
final historyActionsProvider = HistoryActionsProvider._();

final class HistoryActionsProvider
    extends $FunctionalProvider<HistoryActions, HistoryActions, HistoryActions>
    with $Provider<HistoryActions> {
  HistoryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyActionsHash();

  @$internal
  @override
  $ProviderElement<HistoryActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HistoryActions create(Ref ref) {
    return historyActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HistoryActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HistoryActions>(value),
    );
  }
}

String _$historyActionsHash() => r'dbbd99f62d79d7863c453676e6c26145151268f0';

/// Workouts that are on their way out but can still be brought back.
///
/// Undo is implemented by delaying the delete, not by restoring a copy
/// afterwards: for five seconds the row is only hidden from the list, and
/// nothing has happened in the database yet.

@ProviderFor(PendingWorkoutDeletions)
final pendingWorkoutDeletionsProvider = PendingWorkoutDeletionsProvider._();

/// Workouts that are on their way out but can still be brought back.
///
/// Undo is implemented by delaying the delete, not by restoring a copy
/// afterwards: for five seconds the row is only hidden from the list, and
/// nothing has happened in the database yet.
final class PendingWorkoutDeletionsProvider
    extends $NotifierProvider<PendingWorkoutDeletions, Set<String>> {
  /// Workouts that are on their way out but can still be brought back.
  ///
  /// Undo is implemented by delaying the delete, not by restoring a copy
  /// afterwards: for five seconds the row is only hidden from the list, and
  /// nothing has happened in the database yet.
  PendingWorkoutDeletionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingWorkoutDeletionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingWorkoutDeletionsHash();

  @$internal
  @override
  PendingWorkoutDeletions create() => PendingWorkoutDeletions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$pendingWorkoutDeletionsHash() =>
    r'dac1d4f6f3103eb4e72292d03a735b77560e2457';

/// Workouts that are on their way out but can still be brought back.
///
/// Undo is implemented by delaying the delete, not by restoring a copy
/// afterwards: for five seconds the row is only hidden from the list, and
/// nothing has happened in the database yet.

abstract class _$PendingWorkoutDeletions extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
