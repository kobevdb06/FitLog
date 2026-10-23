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
