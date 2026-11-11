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

/// What the coach said at [moment] about [subject], if it was asked.

@ProviderFor(momentAnswer)
final momentAnswerProvider = MomentAnswerFamily._();

/// What the coach said at [moment] about [subject], if it was asked.

final class MomentAnswerProvider
    extends
        $FunctionalProvider<
          AsyncValue<MomentAnswerView?>,
          MomentAnswerView?,
          Stream<MomentAnswerView?>
        >
    with
        $FutureModifier<MomentAnswerView?>,
        $StreamProvider<MomentAnswerView?> {
  /// What the coach said at [moment] about [subject], if it was asked.
  MomentAnswerProvider._({
    required MomentAnswerFamily super.from,
    required (CoachMoment, String) super.argument,
  }) : super(
         retry: null,
         name: r'momentAnswerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$momentAnswerHash();

  @override
  String toString() {
    return r'momentAnswerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<MomentAnswerView?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MomentAnswerView?> create(Ref ref) {
    final argument = this.argument as (CoachMoment, String);
    return momentAnswer(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is MomentAnswerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$momentAnswerHash() => r'711495bf7b5b18bcf358c3f430d4713a9969c953';

/// What the coach said at [moment] about [subject], if it was asked.

final class MomentAnswerFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<MomentAnswerView?>,
          (CoachMoment, String)
        > {
  MomentAnswerFamily._()
    : super(
        retry: null,
        name: r'momentAnswerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What the coach said at [moment] about [subject], if it was asked.

  MomentAnswerProvider call(CoachMoment moment, String subject) =>
      MomentAnswerProvider._(argument: (moment, subject), from: this);

  @override
  String toString() => r'momentAnswerProvider';
}

/// The newest answer at [moment], whatever it was about: the milestone on
/// Profiel.

@ProviderFor(latestMomentAnswer)
final latestMomentAnswerProvider = LatestMomentAnswerFamily._();

/// The newest answer at [moment], whatever it was about: the milestone on
/// Profiel.

final class LatestMomentAnswerProvider
    extends
        $FunctionalProvider<
          AsyncValue<MomentAnswerRow?>,
          MomentAnswerRow?,
          Stream<MomentAnswerRow?>
        >
    with $FutureModifier<MomentAnswerRow?>, $StreamProvider<MomentAnswerRow?> {
  /// The newest answer at [moment], whatever it was about: the milestone on
  /// Profiel.
  LatestMomentAnswerProvider._({
    required LatestMomentAnswerFamily super.from,
    required CoachMoment super.argument,
  }) : super(
         retry: null,
         name: r'latestMomentAnswerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$latestMomentAnswerHash();

  @override
  String toString() {
    return r'latestMomentAnswerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<MomentAnswerRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MomentAnswerRow?> create(Ref ref) {
    final argument = this.argument as CoachMoment;
    return latestMomentAnswer(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LatestMomentAnswerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$latestMomentAnswerHash() =>
    r'06840266d61b07a9a9934d936d442540ae5ce8c2';

/// The newest answer at [moment], whatever it was about: the milestone on
/// Profiel.

final class LatestMomentAnswerFamily extends $Family
    with $FunctionalFamilyOverride<Stream<MomentAnswerRow?>, CoachMoment> {
  LatestMomentAnswerFamily._()
    : super(
        retry: null,
        name: r'latestMomentAnswerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The newest answer at [moment], whatever it was about: the milestone on
  /// Profiel.

  LatestMomentAnswerProvider call(CoachMoment moment) =>
      LatestMomentAnswerProvider._(argument: moment, from: this);

  @override
  String toString() => r'latestMomentAnswerProvider';
}

/// The milestone [workoutId] reached, as a subject; null for an ordinary
/// workout.

@ProviderFor(milestoneReached)
final milestoneReachedProvider = MilestoneReachedFamily._();

/// The milestone [workoutId] reached, as a subject; null for an ordinary
/// workout.

final class MilestoneReachedProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The milestone [workoutId] reached, as a subject; null for an ordinary
  /// workout.
  MilestoneReachedProvider._({
    required MilestoneReachedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'milestoneReachedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$milestoneReachedHash();

  @override
  String toString() {
    return r'milestoneReachedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return milestoneReached(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MilestoneReachedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$milestoneReachedHash() => r'317d2f5c99051a0f022aefe7903135317f502eb3';

/// The milestone [workoutId] reached, as a subject; null for an ordinary
/// workout.

final class MilestoneReachedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  MilestoneReachedFamily._()
    : super(
        retry: null,
        name: r'milestoneReachedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The milestone [workoutId] reached, as a subject; null for an ordinary
  /// workout.

  MilestoneReachedProvider call(String workoutId) =>
      MilestoneReachedProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'milestoneReachedProvider';
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

/// The user's own questions, as buttons in the coach.

@ProviderFor(quickQuestions)
final quickQuestionsProvider = QuickQuestionsProvider._();

/// The user's own questions, as buttons in the coach.

final class QuickQuestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<QuickQuestionRow>>,
          List<QuickQuestionRow>,
          Stream<List<QuickQuestionRow>>
        >
    with
        $FutureModifier<List<QuickQuestionRow>>,
        $StreamProvider<List<QuickQuestionRow>> {
  /// The user's own questions, as buttons in the coach.
  QuickQuestionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quickQuestionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quickQuestionsHash();

  @$internal
  @override
  $StreamProviderElement<List<QuickQuestionRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<QuickQuestionRow>> create(Ref ref) {
    return quickQuestions(ref);
  }
}

String _$quickQuestionsHash() => r'8b5794ec270bf7f5bb734c90f34f353cfa404f72';

/// Asking the coach at one moment about one thing.
///
/// Kept while the app runs: a screen that is closed and opened again while
/// the coach is still writing must not ask a second time.

@ProviderFor(MomentAsk)
final momentAskProvider = MomentAskFamily._();

/// Asking the coach at one moment about one thing.
///
/// Kept while the app runs: a screen that is closed and opened again while
/// the coach is still writing must not ask a second time.
final class MomentAskProvider extends $NotifierProvider<MomentAsk, AskState> {
  /// Asking the coach at one moment about one thing.
  ///
  /// Kept while the app runs: a screen that is closed and opened again while
  /// the coach is still writing must not ask a second time.
  MomentAskProvider._({
    required MomentAskFamily super.from,
    required (CoachMoment, String) super.argument,
  }) : super(
         retry: null,
         name: r'momentAskProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$momentAskHash();

  @override
  String toString() {
    return r'momentAskProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  MomentAsk create() => MomentAsk();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AskState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AskState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MomentAskProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$momentAskHash() => r'6ccf3d6eb1b56fc0a8210d8599ecbc77166dc34c';

/// Asking the coach at one moment about one thing.
///
/// Kept while the app runs: a screen that is closed and opened again while
/// the coach is still writing must not ask a second time.

final class MomentAskFamily extends $Family
    with
        $ClassFamilyOverride<
          MomentAsk,
          AskState,
          AskState,
          AskState,
          (CoachMoment, String)
        > {
  MomentAskFamily._()
    : super(
        retry: null,
        name: r'momentAskProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Asking the coach at one moment about one thing.
  ///
  /// Kept while the app runs: a screen that is closed and opened again while
  /// the coach is still writing must not ask a second time.

  MomentAskProvider call(CoachMoment moment, String subject) =>
      MomentAskProvider._(argument: (moment, subject), from: this);

  @override
  String toString() => r'momentAskProvider';
}

/// Asking the coach at one moment about one thing.
///
/// Kept while the app runs: a screen that is closed and opened again while
/// the coach is still writing must not ask a second time.

abstract class _$MomentAsk extends $Notifier<AskState> {
  late final _$args = ref.$arg as (CoachMoment, String);
  CoachMoment get moment => _$args.$1;
  String get subject => _$args.$2;

  AskState build(CoachMoment moment, String subject);
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
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
