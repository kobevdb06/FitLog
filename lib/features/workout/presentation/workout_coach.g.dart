// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_coach.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutCoach)
final workoutCoachProvider = WorkoutCoachProvider._();

final class WorkoutCoachProvider
    extends $FunctionalProvider<WorkoutCoach, WorkoutCoach, WorkoutCoach>
    with $Provider<WorkoutCoach> {
  WorkoutCoachProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutCoachProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutCoachHash();

  @$internal
  @override
  $ProviderElement<WorkoutCoach> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorkoutCoach create(Ref ref) {
    return workoutCoach(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutCoach value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutCoach>(value),
    );
  }
}

String _$workoutCoachHash() => r'dc627bbdfb023843c225ff63344a9d1c0170bb4c';
