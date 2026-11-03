// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every schema, the last changed first.

@ProviderFor(plans)
final plansProvider = PlansProvider._();

/// Every schema, the last changed first.

final class PlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrainingPlanRow>>,
          List<TrainingPlanRow>,
          Stream<List<TrainingPlanRow>>
        >
    with
        $FutureModifier<List<TrainingPlanRow>>,
        $StreamProvider<List<TrainingPlanRow>> {
  /// Every schema, the last changed first.
  PlansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'plansProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$plansHash();

  @$internal
  @override
  $StreamProviderElement<List<TrainingPlanRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TrainingPlanRow>> create(Ref ref) {
    return plans(ref);
  }
}

String _$plansHash() => r'bee87c6582efddd61e264a4e60fc569d780f50e4';

@ProviderFor(plan)
final planProvider = PlanFamily._();

final class PlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrainingPlanRow?>,
          TrainingPlanRow?,
          Stream<TrainingPlanRow?>
        >
    with $FutureModifier<TrainingPlanRow?>, $StreamProvider<TrainingPlanRow?> {
  PlanProvider._({
    required PlanFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planHash();

  @override
  String toString() {
    return r'planProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<TrainingPlanRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TrainingPlanRow?> create(Ref ref) {
    final argument = this.argument as String;
    return plan(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planHash() => r'a8809a128013af34c7b5ce6a02ebab36ac660ff3';

final class PlanFamily extends $Family
    with $FunctionalFamilyOverride<Stream<TrainingPlanRow?>, String> {
  PlanFamily._()
    : super(
        retry: null,
        name: r'planProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PlanProvider call(String id) => PlanProvider._(argument: id, from: this);

  @override
  String toString() => r'planProvider';
}

/// The schema being followed, if any.

@ProviderFor(runningPlan)
final runningPlanProvider = RunningPlanProvider._();

/// The schema being followed, if any.

final class RunningPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrainingPlanRow?>,
          TrainingPlanRow?,
          Stream<TrainingPlanRow?>
        >
    with $FutureModifier<TrainingPlanRow?>, $StreamProvider<TrainingPlanRow?> {
  /// The schema being followed, if any.
  RunningPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningPlanHash();

  @$internal
  @override
  $StreamProviderElement<TrainingPlanRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TrainingPlanRow?> create(Ref ref) {
    return runningPlan(ref);
  }
}

String _$runningPlanHash() => r'f74431517eace3d7a63cf1ca71e6002a204c7be4';

/// The sessions of a schema, in its order.

@ProviderFor(planSessions)
final planSessionsProvider = PlanSessionsFamily._();

/// The sessions of a schema, in its order.

final class PlanSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoutineRow>>,
          List<RoutineRow>,
          Stream<List<RoutineRow>>
        >
    with $FutureModifier<List<RoutineRow>>, $StreamProvider<List<RoutineRow>> {
  /// The sessions of a schema, in its order.
  PlanSessionsProvider._({
    required PlanSessionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planSessionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planSessionsHash();

  @override
  String toString() {
    return r'planSessionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<RoutineRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoutineRow>> create(Ref ref) {
    final argument = this.argument as String;
    return planSessions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanSessionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planSessionsHash() => r'76e69706a7acd99a25a9183aba42af18cd3d8330';

/// The sessions of a schema, in its order.

final class PlanSessionsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<RoutineRow>>, String> {
  PlanSessionsFamily._()
    : super(
        retry: null,
        name: r'planSessionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The sessions of a schema, in its order.

  PlanSessionsProvider call(String planId) =>
      PlanSessionsProvider._(argument: planId, from: this);

  @override
  String toString() => r'planSessionsProvider';
}

/// The conversations of the schema's, the last added to first.

@ProviderFor(planThreads)
final planThreadsProvider = PlanThreadsProvider._();

/// The conversations of the schema's, the last added to first.

final class PlanThreadsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatThreadRow>>,
          List<ChatThreadRow>,
          Stream<List<ChatThreadRow>>
        >
    with
        $FutureModifier<List<ChatThreadRow>>,
        $StreamProvider<List<ChatThreadRow>> {
  /// The conversations of the schema's, the last added to first.
  PlanThreadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planThreadsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planThreadsHash();

  @$internal
  @override
  $StreamProviderElement<List<ChatThreadRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChatThreadRow>> create(Ref ref) {
    return planThreads(ref);
  }
}

String _$planThreadsHash() => r'cd91092a255cf885ed829f40399a92875aee638e';

/// How the current week of [planId] stands: its sessions in order, and
/// which were done this week, on any day.

@ProviderFor(planThisWeek)
final planThisWeekProvider = PlanThisWeekFamily._();

/// How the current week of [planId] stands: its sessions in order, and
/// which were done this week, on any day.

final class PlanThisWeekProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlanWeekStanding>,
          PlanWeekStanding,
          Stream<PlanWeekStanding>
        >
    with $FutureModifier<PlanWeekStanding>, $StreamProvider<PlanWeekStanding> {
  /// How the current week of [planId] stands: its sessions in order, and
  /// which were done this week, on any day.
  PlanThisWeekProvider._({
    required PlanThisWeekFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planThisWeekProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planThisWeekHash();

  @override
  String toString() {
    return r'planThisWeekProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<PlanWeekStanding> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PlanWeekStanding> create(Ref ref) {
    final argument = this.argument as String;
    return planThisWeek(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanThisWeekProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planThisWeekHash() => r'227673dcb577ddf2df42ea25fefd03a7a1a289d2';

/// How the current week of [planId] stands: its sessions in order, and
/// which were done this week, on any day.

final class PlanThisWeekFamily extends $Family
    with $FunctionalFamilyOverride<Stream<PlanWeekStanding>, String> {
  PlanThisWeekFamily._()
    : super(
        retry: null,
        name: r'planThisWeekProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How the current week of [planId] stands: its sessions in order, and
  /// which were done this week, on any day.

  PlanThisWeekProvider call(String planId) =>
      PlanThisWeekProvider._(argument: planId, from: this);

  @override
  String toString() => r'planThisWeekProvider';
}

/// How [week] of [planId] stands: its sessions in order, and which were
/// done in it, on any day. Nothing done before the schema began.

@ProviderFor(planWeekStanding)
final planWeekStandingProvider = PlanWeekStandingFamily._();

/// How [week] of [planId] stands: its sessions in order, and which were
/// done in it, on any day. Nothing done before the schema began.

final class PlanWeekStandingProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlanWeekStanding>,
          PlanWeekStanding,
          Stream<PlanWeekStanding>
        >
    with $FutureModifier<PlanWeekStanding>, $StreamProvider<PlanWeekStanding> {
  /// How [week] of [planId] stands: its sessions in order, and which were
  /// done in it, on any day. Nothing done before the schema began.
  PlanWeekStandingProvider._({
    required PlanWeekStandingFamily super.from,
    required (String, int) super.argument,
  }) : super(
         retry: null,
         name: r'planWeekStandingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planWeekStandingHash();

  @override
  String toString() {
    return r'planWeekStandingProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<PlanWeekStanding> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PlanWeekStanding> create(Ref ref) {
    final argument = this.argument as (String, int);
    return planWeekStanding(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanWeekStandingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planWeekStandingHash() => r'63d2ebaf27abb94d2fcfe13d2b77bfb223b0b184';

/// How [week] of [planId] stands: its sessions in order, and which were
/// done in it, on any day. Nothing done before the schema began.

final class PlanWeekStandingFamily extends $Family
    with $FunctionalFamilyOverride<Stream<PlanWeekStanding>, (String, int)> {
  PlanWeekStandingFamily._()
    : super(
        retry: null,
        name: r'planWeekStandingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How [week] of [planId] stands: its sessions in order, and which were
  /// done in it, on any day. Nothing done before the schema began.

  PlanWeekStandingProvider call(String planId, int week) =>
      PlanWeekStandingProvider._(argument: (planId, week), from: this);

  @override
  String toString() => r'planWeekStandingProvider';
}

@ProviderFor(TrainShelfChoice)
final trainShelfChoiceProvider = TrainShelfChoiceProvider._();

final class TrainShelfChoiceProvider
    extends $NotifierProvider<TrainShelfChoice, TrainShelf> {
  TrainShelfChoiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainShelfChoiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainShelfChoiceHash();

  @$internal
  @override
  TrainShelfChoice create() => TrainShelfChoice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainShelf value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainShelf>(value),
    );
  }
}

String _$trainShelfChoiceHash() => r'6d099e610187266b207c8e35aa4112bebd0e7a93';

abstract class _$TrainShelfChoice extends $Notifier<TrainShelf> {
  TrainShelf build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TrainShelf, TrainShelf>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TrainShelf, TrainShelf>,
              TrainShelf,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The changes the coach proposed for [planId] that wait.

@ProviderFor(planWaitingChanges)
final planWaitingChangesProvider = PlanWaitingChangesFamily._();

/// The changes the coach proposed for [planId] that wait.

final class PlanWaitingChangesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WaitingPlanChange>>,
          List<WaitingPlanChange>,
          Stream<List<WaitingPlanChange>>
        >
    with
        $FutureModifier<List<WaitingPlanChange>>,
        $StreamProvider<List<WaitingPlanChange>> {
  /// The changes the coach proposed for [planId] that wait.
  PlanWaitingChangesProvider._({
    required PlanWaitingChangesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planWaitingChangesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planWaitingChangesHash();

  @override
  String toString() {
    return r'planWaitingChangesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<WaitingPlanChange>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WaitingPlanChange>> create(Ref ref) {
    final argument = this.argument as String;
    return planWaitingChanges(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanWaitingChangesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planWaitingChangesHash() =>
    r'68ee76a0694272c2097a51ad6e60456fbd8151f6';

/// The changes the coach proposed for [planId] that wait.

final class PlanWaitingChangesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<WaitingPlanChange>>, String> {
  PlanWaitingChangesFamily._()
    : super(
        retry: null,
        name: r'planWaitingChangesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The changes the coach proposed for [planId] that wait.

  PlanWaitingChangesProvider call(String planId) =>
      PlanWaitingChangesProvider._(argument: planId, from: this);

  @override
  String toString() => r'planWaitingChangesProvider';
}

/// How many changes the coach proposed for [planId] that wait for
/// Aanvaarden or Houden.

@ProviderFor(planOpenChanges)
final planOpenChangesProvider = PlanOpenChangesFamily._();

/// How many changes the coach proposed for [planId] that wait for
/// Aanvaarden or Houden.

final class PlanOpenChangesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// How many changes the coach proposed for [planId] that wait for
  /// Aanvaarden or Houden.
  PlanOpenChangesProvider._({
    required PlanOpenChangesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planOpenChangesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planOpenChangesHash();

  @override
  String toString() {
    return r'planOpenChangesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as String;
    return planOpenChanges(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanOpenChangesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planOpenChangesHash() => r'5140de1f294c28be700ddc5240d26873fc105570';

/// How many changes the coach proposed for [planId] that wait for
/// Aanvaarden or Houden.

final class PlanOpenChangesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, String> {
  PlanOpenChangesFamily._()
    : super(
        retry: null,
        name: r'planOpenChangesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How many changes the coach proposed for [planId] that wait for
  /// Aanvaarden or Houden.

  PlanOpenChangesProvider call(String planId) =>
      PlanOpenChangesProvider._(argument: planId, from: this);

  @override
  String toString() => r'planOpenChangesProvider';
}
