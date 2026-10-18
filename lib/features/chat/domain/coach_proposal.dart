/// What the coach offers to add, and the one thing it does itself.
///
/// The lookups are read-only on purpose - it is your logbook, and a model
/// that may write in it can also quietly spoil it: an exercise with the wrong
/// muscle, a duplicate of something you already had, found back months later
/// in your own statistics.
///
/// So for an exercise the coach describes instead. A proposal is stored with
/// the answer it came with, drawn as a card, and nothing exists until you tap
/// the button on it. The same goes for a change to one of your own
/// exercises: the card says what would change, and nothing does until you
/// tap Toepassen.
///
/// A routine in the coach's folder is the exception: those it makes and
/// changes itself, because you asked for one or put one there knowing it
/// could. The card then says what it did, after the fact, and every earlier
/// version is kept (see `RoutinesDao.keepVersion`).
///
/// A deload is proposed like an exercise: the card has Starten, and
/// Aanpassen for the start sheet with the coach's numbers in it.
library;

import 'dart:convert';

import '../../../core/calc/deload.dart';

/// What is being offered.
enum ProposalKind {
  exercise('exercise'),

  /// A routine offered with a button. What the coach did before it could
  /// make routines itself; still drawn in the conversations of then.
  routine('routine'),

  /// A routine the coach made or changed in its own folder.
  coachRoutine('coach_routine'),

  /// A change to one of the user's own exercises, offered with a button.
  exerciseChange('exercise_change'),

  /// A deload, offered with a button.
  deload('deload');

  const ProposalKind(this.wire);

  final String wire;

  static ProposalKind? fromWire(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// One exercise the coach would make for you.
class ExerciseProposal {
  const ExerciseProposal({
    required this.name,
    required this.primaryMuscle,
    this.secondaryMuscles = const [],
    this.equipment,
    this.category = 'barbell',
    this.instructions,
    this.startImagePrompt,
    this.endImagePrompt,
    this.startPhoto,
    this.endPhoto,
  });

  final String name;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final String? equipment;

  /// The wire value of a built-in category, or the name of one of the user's
  /// own.
  final String category;

  final String? instructions;

  /// What the two pictures should show, in the coach's own words: two prompts
  /// the user pastes into Gemini for a photo of the start and of the end.
  ///
  /// It named the exercise, so it knows better than a template what the start
  /// and the end of it look like - and the difference between those two is
  /// the whole value of the pair. Older conversations hold the short English
  /// sentences it wrote for the drawing services (DECISIONS 201); those are
  /// shown as they are.
  final String? startImagePrompt;
  final String? endImagePrompt;

  /// Photos from the conversation for the start and the end, as file names
  /// in the photo directory: the user sent them, the coach said which is
  /// which. Copied onto the exercise when it is added.
  final String? startPhoto;
  final String? endPhoto;

  bool get hasPhotos => startPhoto != null || endPhoto != null;

  bool get hasFramePrompts =>
      startImagePrompt != null &&
      endImagePrompt != null &&
      startImagePrompt!.isNotEmpty &&
      endImagePrompt!.isNotEmpty;

  Map<String, Object?> toJson() => {
    'name': name,
    'primary_muscle': primaryMuscle,
    'secondary_muscles': secondaryMuscles,
    'equipment': equipment,
    'category': category,
    'instructions': instructions,
    'start_image_prompt': startImagePrompt,
    'end_image_prompt': endImagePrompt,
    'start_photo': ?startPhoto,
    'end_photo': ?endPhoto,
  };

  static ExerciseProposal fromJson(Map<String, Object?> json) =>
      ExerciseProposal(
        name: '${json['name']}',
        primaryMuscle: '${json['primary_muscle']}',
        secondaryMuscles: [
          for (final muscle in json['secondary_muscles'] as List? ?? const [])
            '$muscle',
        ],
        equipment: json['equipment'] as String?,
        category: '${json['category'] ?? 'barbell'}',
        instructions: json['instructions'] as String?,
        startImagePrompt: json['start_image_prompt'] as String?,
        endImagePrompt: json['end_image_prompt'] as String?,
        startPhoto: json['start_photo'] as String?,
        endPhoto: json['end_photo'] as String?,
      );
}

/// A change to one of the user's own exercises, as the coach would make it.
///
/// Only what changes is set; everything left null stays as it is. Never a
/// built-in exercise: those are the catalogue's, with their animation.
class ExerciseChangeProposal {
  const ExerciseChangeProposal({
    required this.exerciseId,
    required this.exerciseName,
    this.name,
    this.primaryMuscle,
    this.secondaryMuscles,
    this.equipment,
    this.instructions,
    this.startPhoto,
    this.endPhoto,
    this.reason,
  });

  final String exerciseId;

  /// What the exercise was called when the change was proposed: what the
  /// card is headed with, also once the name itself has changed.
  final String exerciseName;

  final String? name;
  final String? primaryMuscle;
  final List<String>? secondaryMuscles;
  final String? equipment;
  final String? instructions;

  /// Photos from the conversation for the start and the end, as file names
  /// in the photo directory.
  final String? startPhoto;
  final String? endPhoto;

  /// What changes and why, in one sentence of the coach's.
  final String? reason;

  bool get changesSomething =>
      name != null ||
      primaryMuscle != null ||
      secondaryMuscles != null ||
      equipment != null ||
      instructions != null ||
      startPhoto != null ||
      endPhoto != null;

  Map<String, Object?> toJson() => {
    'exercise_id': exerciseId,
    'exercise_name': exerciseName,
    'name': ?name,
    'primary_muscle': ?primaryMuscle,
    'secondary_muscles': ?secondaryMuscles,
    'equipment': ?equipment,
    'instructions': ?instructions,
    'start_photo': ?startPhoto,
    'end_photo': ?endPhoto,
    'reason': ?reason,
  };

  static ExerciseChangeProposal fromJson(Map<String, Object?> json) =>
      ExerciseChangeProposal(
        exerciseId: '${json['exercise_id']}',
        exerciseName: '${json['exercise_name']}',
        name: json['name'] as String?,
        primaryMuscle: json['primary_muscle'] as String?,
        secondaryMuscles: switch (json['secondary_muscles']) {
          final List<Object?> list => [for (final m in list) '$m'],
          _ => null,
        },
        equipment: json['equipment'] as String?,
        instructions: json['instructions'] as String?,
        startPhoto: json['start_photo'] as String?,
        endPhoto: json['end_photo'] as String?,
        reason: json['reason'] as String?,
      );
}

/// One exercise inside a proposed routine, already matched to a real one.
class ProposedRoutineExercise {
  const ProposedRoutineExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    this.targetReps,
  });

  final String exerciseId;
  final String name;
  final int sets;
  final int? targetReps;

  Map<String, Object?> toJson() => {
    'exercise_id': exerciseId,
    'name': name,
    'sets': sets,
    'target_reps': targetReps,
  };

  static ProposedRoutineExercise fromJson(Map<String, Object?> json) =>
      ProposedRoutineExercise(
        exerciseId: '${json['exercise_id']}',
        name: '${json['name']}',
        sets: json['sets'] as int? ?? 3,
        targetReps: json['target_reps'] as int?,
      );
}

/// One routine the coach would make for you.
class RoutineProposal {
  const RoutineProposal({
    required this.name,
    required this.exercises,
    this.notes,
  });

  final String name;
  final List<ProposedRoutineExercise> exercises;
  final String? notes;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets);

  Map<String, Object?> toJson() => {
    'name': name,
    'notes': notes,
    'exercises': [for (final exercise in exercises) exercise.toJson()],
  };

  static RoutineProposal fromJson(Map<String, Object?> json) => RoutineProposal(
    name: '${json['name']}',
    notes: json['notes'] as String?,
    exercises: [
      for (final exercise in json['exercises'] as List? ?? const [])
        ProposedRoutineExercise.fromJson(
          (exercise as Map).map((key, value) => MapEntry('$key', value)),
        ),
    ],
  );
}

/// A deload the coach would start: from when, how long, how light, and why.
class DeloadProposal {
  const DeloadProposal({
    required this.from,
    required this.days,
    required this.plan,
    this.reason,
  });

  /// The first day, at midnight.
  final DateTime from;
  final int days;
  final DeloadPlan plan;

  /// Why now, in one sentence of the coach's.
  final String? reason;

  /// The first day when it is started at [now]: the proposed one, or today
  /// once that has gone by - a card tapped a week later starts then, not in
  /// the past.
  DateTime startAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return from.isBefore(today) ? today : from;
  }

  Map<String, Object?> toJson() => {
    'from':
        '${from.year}-${from.month.toString().padLeft(2, '0')}-'
        '${from.day.toString().padLeft(2, '0')}',
    'days': days,
    'sets_percent': plan.setsPercent,
    'weight_percent': plan.weightPercent,
    'reps_percent': plan.repsPercent,
    'drop_hard_sets': plan.dropHardSets,
    'pr_attempts': plan.prAttempts,
    'reason': ?reason,
  };

  static DeloadProposal? fromJson(Map<String, Object?> json) {
    final from = DateTime.tryParse('${json['from']}');
    if (from == null) return null;
    const usual = DeloadPlan();
    int whole(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    return DeloadProposal(
      from: DateTime(from.year, from.month, from.day),
      days: whole('days', 7),
      plan: DeloadPlan(
        setsPercent: whole('sets_percent', usual.setsPercent),
        weightPercent: whole('weight_percent', usual.weightPercent),
        repsPercent: whole('reps_percent', usual.repsPercent),
        dropHardSets: json['drop_hard_sets'] != false,
        prAttempts: json['pr_attempts'] == true,
      ),
      reason: json['reason'] as String?,
    );
  }
}

/// A proposal as it is stored with the message, with whether it was taken up.
class CoachProposal {
  const CoachProposal({
    required this.kind,
    required this.exercise,
    required this.routine,
    this.appliedId,
    this.made = false,
    this.change,
    this.exerciseChange,
    this.deload,
  });

  CoachProposal.ofExercise(ExerciseProposal this.exercise, {this.appliedId})
    : kind = ProposalKind.exercise,
      routine = null,
      made = false,
      change = null,
      exerciseChange = null,
      deload = null;

  CoachProposal.ofRoutine(RoutineProposal this.routine, {this.appliedId})
    : kind = ProposalKind.routine,
      exercise = null,
      made = false,
      change = null,
      exerciseChange = null,
      deload = null;

  CoachProposal.ofExerciseChange(
    ExerciseChangeProposal this.exerciseChange, {
    this.appliedId,
  }) : kind = ProposalKind.exerciseChange,
       exercise = null,
       routine = null,
       made = false,
       change = null,
       deload = null;

  /// A deload; [appliedId] is the deload's id once it was started.
  CoachProposal.ofDeload(DeloadProposal this.deload, {this.appliedId})
    : kind = ProposalKind.deload,
      exercise = null,
      routine = null,
      made = false,
      change = null,
      exerciseChange = null;

  /// A routine the coach [made] - or changed, when false - in its own
  /// folder: already there, so [appliedId] is its id from the start.
  CoachProposal.ofCoachRoutine(
    RoutineProposal this.routine, {
    required String this.appliedId,
    required this.made,
    this.change,
  }) : kind = ProposalKind.coachRoutine,
       exercise = null,
       exerciseChange = null,
       deload = null;

  final ProposalKind kind;
  final ExerciseProposal? exercise;
  final RoutineProposal? routine;

  /// The id of what was created when the user tapped, or null while the offer
  /// is still just an offer.
  final String? appliedId;

  /// For a routine of the coach: whether it was new rather than changed.
  final bool made;

  /// For a routine of the coach: what it did and why, in one sentence.
  final String? change;

  final ExerciseChangeProposal? exerciseChange;
  final DeloadProposal? deload;

  bool get isApplied => appliedId != null;

  String get title => switch (kind) {
    ProposalKind.exercise => exercise!.name,
    ProposalKind.routine || ProposalKind.coachRoutine => routine!.name,
    ProposalKind.exerciseChange => exerciseChange!.exerciseName,
    ProposalKind.deload =>
      deload!.days == 7
          ? 'Deloadweek'
          : 'Deload van ${deload!.days} ${deload!.days == 1 ? 'dag' : 'dagen'}',
  };

  CoachProposal applied(String id) => CoachProposal(
    kind: kind,
    exercise: exercise,
    routine: routine,
    appliedId: id,
    made: made,
    change: change,
    exerciseChange: exerciseChange,
    deload: deload,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'applied_id': appliedId,
    if (exercise != null) 'exercise': exercise!.toJson(),
    if (routine != null) 'routine': routine!.toJson(),
    if (exerciseChange != null) 'exercise_change': exerciseChange!.toJson(),
    if (deload != null) 'deload': deload!.toJson(),
    if (kind == ProposalKind.coachRoutine) ...{'made': made, 'change': change},
  };

  static CoachProposal? fromJson(Map<String, Object?> json) {
    final kind = ProposalKind.fromWire(json['kind'] as String?);
    final applied = json['applied_id'] as String?;
    Map<String, Object?> body(String key) =>
        (json[key]! as Map).map((k, v) => MapEntry('$k', v));

    return switch (kind) {
      ProposalKind.exercise when json['exercise'] is Map =>
        CoachProposal.ofExercise(
          ExerciseProposal.fromJson(body('exercise')),
          appliedId: applied,
        ),
      ProposalKind.routine when json['routine'] is Map =>
        CoachProposal.ofRoutine(
          RoutineProposal.fromJson(body('routine')),
          appliedId: applied,
        ),
      ProposalKind.coachRoutine
          when json['routine'] is Map && applied != null =>
        CoachProposal.ofCoachRoutine(
          RoutineProposal.fromJson(body('routine')),
          appliedId: applied,
          made: json['made'] == true,
          change: json['change'] as String?,
        ),
      ProposalKind.exerciseChange when json['exercise_change'] is Map =>
        CoachProposal.ofExerciseChange(
          ExerciseChangeProposal.fromJson(body('exercise_change')),
          appliedId: applied,
        ),
      ProposalKind.deload when json['deload'] is Map =>
        switch (DeloadProposal.fromJson(body('deload'))) {
          final deload? => CoachProposal.ofDeload(deload, appliedId: applied),
          null => null,
        },
      _ => null,
    };
  }
}

/// The proposals of one message, as they are stored and read back.
///
/// Damaged or unknown entries are dropped rather than thrown: a card that
/// cannot be drawn should cost you the card, not the conversation.
List<CoachProposal> parseProposals(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map)
          ?CoachProposal.fromJson(entry.map((k, v) => MapEntry('$k', v))),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeProposals(List<CoachProposal> proposals) =>
    jsonEncode([for (final proposal in proposals) proposal.toJson()]);
