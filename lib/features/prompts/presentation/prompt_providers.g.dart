// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every moment, as the user left it.

@ProviderFor(momentPrompts)
final momentPromptsProvider = MomentPromptsProvider._();

/// Every moment, as the user left it.

final class MomentPromptsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MomentPrompt>>,
          List<MomentPrompt>,
          Stream<List<MomentPrompt>>
        >
    with
        $FutureModifier<List<MomentPrompt>>,
        $StreamProvider<List<MomentPrompt>> {
  /// Every moment, as the user left it.
  MomentPromptsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'momentPromptsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$momentPromptsHash();

  @$internal
  @override
  $StreamProviderElement<List<MomentPrompt>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MomentPrompt>> create(Ref ref) {
    return momentPrompts(ref);
  }
}

String _$momentPromptsHash() => r'bde9eab47fc218f17b76e4fa6f38cbd8781b9f42';

/// One moment, as the user left it; null while it loads.

@ProviderFor(momentPrompt)
final momentPromptProvider = MomentPromptFamily._();

/// One moment, as the user left it; null while it loads.

final class MomentPromptProvider
    extends $FunctionalProvider<MomentPrompt?, MomentPrompt?, MomentPrompt?>
    with $Provider<MomentPrompt?> {
  /// One moment, as the user left it; null while it loads.
  MomentPromptProvider._({
    required MomentPromptFamily super.from,
    required CoachMoment super.argument,
  }) : super(
         retry: null,
         name: r'momentPromptProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$momentPromptHash();

  @override
  String toString() {
    return r'momentPromptProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<MomentPrompt?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MomentPrompt? create(Ref ref) {
    final argument = this.argument as CoachMoment;
    return momentPrompt(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MomentPrompt? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MomentPrompt?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MomentPromptProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$momentPromptHash() => r'af9cf5e9966c3a4e3d0a5daa183d4394c2fdc2f4';

/// One moment, as the user left it; null while it loads.

final class MomentPromptFamily extends $Family
    with $FunctionalFamilyOverride<MomentPrompt?, CoachMoment> {
  MomentPromptFamily._()
    : super(
        retry: null,
        name: r'momentPromptProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One moment, as the user left it; null while it loads.

  MomentPromptProvider call(CoachMoment moment) =>
      MomentPromptProvider._(argument: moment, from: this);

  @override
  String toString() => r'momentPromptProvider';
}

/// What the coach said about [workoutId], if it was asked.

@ProviderFor(workoutAnswer)
final workoutAnswerProvider = WorkoutAnswerFamily._();

/// What the coach said about [workoutId], if it was asked.

final class WorkoutAnswerProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutAnswerRow?>,
          WorkoutAnswerRow?,
          Stream<WorkoutAnswerRow?>
        >
    with
        $FutureModifier<WorkoutAnswerRow?>,
        $StreamProvider<WorkoutAnswerRow?> {
  /// What the coach said about [workoutId], if it was asked.
  WorkoutAnswerProvider._({
    required WorkoutAnswerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutAnswerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutAnswerHash();

  @override
  String toString() {
    return r'workoutAnswerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WorkoutAnswerRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutAnswerRow?> create(Ref ref) {
    final argument = this.argument as String;
    return workoutAnswer(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutAnswerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutAnswerHash() => r'b3c4d050db3a59093a7d23b466f6aadc20ccdeb1';

/// What the coach said about [workoutId], if it was asked.

final class WorkoutAnswerFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WorkoutAnswerRow?>, String> {
  WorkoutAnswerFamily._()
    : super(
        retry: null,
        name: r'workoutAnswerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What the coach said about [workoutId], if it was asked.

  WorkoutAnswerProvider call(String workoutId) =>
      WorkoutAnswerProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutAnswerProvider';
}

/// The workout finished last: the one the settings try a prompt on.

@ProviderFor(lastFinishedWorkout)
final lastFinishedWorkoutProvider = LastFinishedWorkoutProvider._();

/// The workout finished last: the one the settings try a prompt on.

final class LastFinishedWorkoutProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutRow?>,
          WorkoutRow?,
          Stream<WorkoutRow?>
        >
    with $FutureModifier<WorkoutRow?>, $StreamProvider<WorkoutRow?> {
  /// The workout finished last: the one the settings try a prompt on.
  LastFinishedWorkoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastFinishedWorkoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastFinishedWorkoutHash();

  @$internal
  @override
  $StreamProviderElement<WorkoutRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutRow?> create(Ref ref) {
    return lastFinishedWorkout(ref);
  }
}

String _$lastFinishedWorkoutHash() =>
    r'b889a3c2e0e13396cbc502b3f0b2c1036db74d41';

/// Asking the coach about one workout.
///
/// Kept while the app runs: a summary that is closed and opened again while
/// the coach is still writing must not ask a second time.

@ProviderFor(WorkoutAsk)
final workoutAskProvider = WorkoutAskFamily._();

/// Asking the coach about one workout.
///
/// Kept while the app runs: a summary that is closed and opened again while
/// the coach is still writing must not ask a second time.
final class WorkoutAskProvider extends $NotifierProvider<WorkoutAsk, AskState> {
  /// Asking the coach about one workout.
  ///
  /// Kept while the app runs: a summary that is closed and opened again while
  /// the coach is still writing must not ask a second time.
  WorkoutAskProvider._({
    required WorkoutAskFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutAskProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutAskHash();

  @override
  String toString() {
    return r'workoutAskProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkoutAsk create() => WorkoutAsk();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AskState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AskState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutAskProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutAskHash() => r'3792ae2a6f8084c354607717e6942e482f36257e';

/// Asking the coach about one workout.
///
/// Kept while the app runs: a summary that is closed and opened again while
/// the coach is still writing must not ask a second time.

final class WorkoutAskFamily extends $Family
    with
        $ClassFamilyOverride<WorkoutAsk, AskState, AskState, AskState, String> {
  WorkoutAskFamily._()
    : super(
        retry: null,
        name: r'workoutAskProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Asking the coach about one workout.
  ///
  /// Kept while the app runs: a summary that is closed and opened again while
  /// the coach is still writing must not ask a second time.

  WorkoutAskProvider call(String workoutId) =>
      WorkoutAskProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutAskProvider';
}

/// Asking the coach about one workout.
///
/// Kept while the app runs: a summary that is closed and opened again while
/// the coach is still writing must not ask a second time.

abstract class _$WorkoutAsk extends $Notifier<AskState> {
  late final _$args = ref.$arg as String;
  String get workoutId => _$args;

  AskState build(String workoutId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AskState, AskState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AskState, AskState>,
              AskState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
