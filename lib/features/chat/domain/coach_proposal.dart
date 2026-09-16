/// What the coach offers to add, and what it is not: a change.
///
/// The seven lookups are read-only on purpose - it is your logbook, and a
/// model that may write in it can also quietly spoil it: an exercise with the
/// wrong muscle, a duplicate of something you already had, found back months
/// later in your own statistics.
///
/// So the coach describes instead. A proposal is stored with the answer it
/// came with, drawn as a card, and nothing exists until you tap the button on
/// it. The row in your database is then something you did, with the coach's
/// words as the draft.
library;

import 'dart:convert';

/// What is being offered.
enum ProposalKind {
  exercise('exercise'),
  routine('routine');

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
  });

  final String name;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final String? equipment;

  /// The wire value of a built-in category, or the name of one of the user's
  /// own.
  final String category;

  final String? instructions;

  /// What the two pictures should show, in the coach's own words.
  ///
  /// It named the exercise, so it knows better than a template what the start
  /// and the end of it look like - and the difference between those two is
  /// the whole value of the pair.
  final String? startImagePrompt;
  final String? endImagePrompt;

  bool get canBeDrawn =>
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

/// A proposal as it is stored with the message, with whether it was taken up.
class CoachProposal {
  const CoachProposal({
    required this.kind,
    required this.exercise,
    required this.routine,
    this.appliedId,
  });

  CoachProposal.ofExercise(ExerciseProposal this.exercise, {this.appliedId})
    : kind = ProposalKind.exercise,
      routine = null;

  CoachProposal.ofRoutine(RoutineProposal this.routine, {this.appliedId})
    : kind = ProposalKind.routine,
      exercise = null;

  final ProposalKind kind;
  final ExerciseProposal? exercise;
  final RoutineProposal? routine;

  /// The id of what was created when the user tapped, or null while the offer
  /// is still just an offer.
  final String? appliedId;

  bool get isApplied => appliedId != null;

  String get title => switch (kind) {
    ProposalKind.exercise => exercise!.name,
    ProposalKind.routine => routine!.name,
  };

  CoachProposal applied(String id) => CoachProposal(
    kind: kind,
    exercise: exercise,
    routine: routine,
    appliedId: id,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'applied_id': appliedId,
    if (exercise != null) 'exercise': exercise!.toJson(),
    if (routine != null) 'routine': routine!.toJson(),
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
