// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_summary_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(finishedWorkout)
final finishedWorkoutProvider = FinishedWorkoutFamily._();

final class FinishedWorkoutProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutDetail?>,
          WorkoutDetail?,
          FutureOr<WorkoutDetail?>
        >
    with $FutureModifier<WorkoutDetail?>, $FutureProvider<WorkoutDetail?> {
  FinishedWorkoutProvider._({
    required FinishedWorkoutFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'finishedWorkoutProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$finishedWorkoutHash();

  @override
  String toString() {
    return r'finishedWorkoutProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WorkoutDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkoutDetail?> create(Ref ref) {
    final argument = this.argument as String;
    return finishedWorkout(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FinishedWorkoutProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$finishedWorkoutHash() => r'2aefa295fb84bf89d97af80609fb7cef33f9eb81';

final class FinishedWorkoutFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WorkoutDetail?>, String> {
  FinishedWorkoutFamily._()
    : super(
        retry: null,
        name: r'finishedWorkoutProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FinishedWorkoutProvider call(String workoutId) =>
      FinishedWorkoutProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'finishedWorkoutProvider';
}
