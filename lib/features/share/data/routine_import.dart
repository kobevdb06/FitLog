import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../domain/exercise_matcher.dart';
import '../domain/routine_code.dart';

const _uuid = Uuid();

/// One incoming exercise and what the app proposes to do with it.
///
/// [link] is the decision, and it can be changed: the preview screen shows
/// what was matched and lets the user reject a proposal before anything is
/// written.
class PlannedExercise {
  PlannedExercise({required this.incoming, required this.match})
    : link = match.linksByDefault;

  final SharedExercise incoming;
  final ExerciseMatch match;

  /// True to use [ExerciseMatch.existing], false to add it as a new exercise
  /// of your own.
  bool link;

  ExerciseRow? get existing => match.existing;

  bool get willAdd => !link || match.existing == null;
}

class RoutineImportPlan {
  RoutineImportPlan({required this.routine, required this.exercises});

  final SharedRoutine routine;
  final List<PlannedExercise> exercises;

  int get newExerciseCount => exercises.where((e) => e.willAdd).length;
}

/// Works out, without writing anything, which of the shared exercises the user
/// already has.
Future<RoutineImportPlan> planRoutineImport(
  AppDatabase db,
  SharedRoutine routine,
) async {
  final mine = await db.exercisesDao.getExercises();
  return RoutineImportPlan(
    routine: routine,
    exercises: [
      for (final incoming in routine.exercises)
        PlannedExercise(
          incoming: incoming,
          match: matchSharedExercise(incoming, mine),
        ),
    ],
  );
}

/// Writes the plan: first the exercises that are new, then the routine that
/// points at them.
///
/// That order matters for the same reason it does with photos: a routine
/// referring to an exercise that was never created is a hole you cannot see
/// until you open it.
Future<String> applyRoutineImport(
  AppDatabase db,
  RoutineImportPlan plan, {
  String? folderId,
}) async {
  final drafts = <RoutineExerciseDraft>[];

  for (final planned in plan.exercises) {
    final incoming = planned.incoming;

    final String exerciseId;
    if (!planned.willAdd) {
      exerciseId = planned.existing!.id;
    } else {
      exerciseId = _uuid.v4();
      await db.exercisesDao.insertExercise(
        ExercisesTableCompanion.insert(
          id: exerciseId,
          name: incoming.name,
          primaryMuscle: incoming.primaryMuscle,
          secondaryMuscles: Value(jsonEncode(incoming.secondaryMuscles)),
          equipment: Value(incoming.equipment),
          category: incoming.category.wire,
          instructions: Value(incoming.instructions),
          // Whatever it was on the other phone, here it is an exercise the
          // catalogue does not have.
          isCustom: const Value(true),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    drafts.add(
      RoutineExerciseDraft(
        exerciseId: exerciseId,
        restSeconds: incoming.restSeconds,
        supersetGroup: incoming.supersetGroup,
        notes: incoming.notes,
        sets: [
          for (final set in incoming.sets)
            RoutineSetDraft(
              setType: set.type,
              targetReps: set.reps,
              targetDurationSeconds: set.durationSeconds,
            ),
        ],
      ),
    );
  }

  return db.routinesDao.createRoutine(
    RoutineDraft(
      name: plan.routine.name,
      notes: plan.routine.notes,
      folderId: folderId,
      exercises: drafts,
    ),
  );
}

/// Turns one of the user's own routines into the payload that goes in the QR.
Future<SharedRoutine> sharedRoutineFor(AppDatabase db, String routineId) async {
  final detail = await db.routinesDao.getRoutineDetail(routineId);
  if (detail == null) throw StateError('Routine $routineId bestaat niet');

  return SharedRoutine(
    name: detail.routine.name,
    notes: detail.routine.notes,
    exercises: [
      for (final item in detail.exercises)
        SharedExercise(
          // A catalogue exercise travels as its id; one the sender made
          // themselves has no id the receiver could know, so it travels as a
          // full description instead.
          id: item.exercise.isCustom ? null : item.exercise.id,
          name: item.exercise.name,
          primaryMuscle: item.exercise.primaryMuscle,
          secondaryMuscles: decodeMuscleListForShare(
            item.exercise.secondaryMuscles,
          ),
          equipment: item.exercise.equipment,
          category: ExerciseCategory.fromWire(item.exercise.category),
          instructions: item.exercise.instructions,
          restSeconds: item.routineExercise.restSeconds,
          supersetGroup: item.routineExercise.supersetGroup,
          notes: item.routineExercise.notes,
          sets: [
            for (final set in item.sets)
              SharedSet(
                type: SetType.fromWire(set.setType),
                reps: set.targetReps,
                durationSeconds: set.targetDurationSeconds,
              ),
          ],
        ),
    ],
  );
}

/// The JSON array of muscles as stored on the row.
List<String> decodeMuscleListForShare(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  } on FormatException {
    return const [];
  }
}
