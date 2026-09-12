import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:fitlog/core/widgets/numeric_keypad.dart';
import 'package:fitlog/features/workout/domain/set_columns.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeping an RPE per set, and what it is worth.
///
/// Off unless you ask for it: it is one more number per set, and most people
/// do not want to score everything they do. Turned on, it is the most specific
/// thing the app knows about how hard a muscle worked.
void main() {
  SetValues set({double? rpe, double? weightKg, int? reps}) => (
    weightKg: weightKg,
    reps: reps,
    durationSeconds: null,
    distanceM: null,
    rpe: rpe,
  );

  group('the column', () {
    test('is not there unless you ask for it', () {
      expect(
        setColumnsFor(ExerciseCategory.barbell, [set()]),
        isNot(contains(KeypadFieldKind.rpe)),
      );
    });

    test('appears when you do, after the numbers that make the set', () {
      expect(setColumnsFor(ExerciseCategory.barbell, [set()], trackRpe: true), [
        KeypadFieldKind.weight,
        KeypadFieldKind.reps,
        KeypadFieldKind.rpe,
      ]);
    });

    test('and stays for a set that already carries one', () {
      // Turned off again after scoring a few: hiding the column would leave
      // the number stored where nobody can see or correct it.
      expect(
        setColumnsFor(ExerciseCategory.barbell, [set(rpe: 8)]),
        contains(KeypadFieldKind.rpe),
      );
    });

    test('a plank can be scored too', () {
      expect(
        setColumnsFor(ExerciseCategory.duration, [set()], trackRpe: true),
        [KeypadFieldKind.duration, KeypadFieldKind.rpe],
      );
    });
  });

  group('the chart it unlocks', () {
    ExerciseSession session(List<WorkoutSetRow> sets) => ExerciseSession(
      workout: WorkoutRow(
        id: 'w',
        name: 'Push',
        startedAt: DateTime(2026, 3, 1).millisecondsSinceEpoch,
        totalVolumeKg: 0,
        totalSets: 0,
        durationSeconds: 0,
      ),
      workoutExercise: WorkoutExerciseRow(
        id: 'we',
        workoutId: 'w',
        exerciseId: 'ex',
        sortOrder: 0,
        restSeconds: 90,
        isUnilateral: false,
        isPrAttempt: false,
      ),
      sets: sets,
    );

    WorkoutSetRow scored({
      double? weightKg = 100,
      int? reps = 5,
      double? rpe,
      String? side,
      String setType = 'normal',
    }) => WorkoutSetRow(
      id: 's',
      workoutExerciseId: 'we',
      sortOrder: 0,
      setType: setType,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      side: side,
      isCompleted: true,
      isSkipped: false,
    );

    test('is not offered before anything has been scored', () {
      expect(
        ExerciseMetric.forSessions(ExerciseCategory.barbell, [
          session([scored()]),
        ]),
        isNot(contains(ExerciseMetric.rpeOneRm)),
      );
    });

    test('appears once a usable set exists', () {
      expect(
        ExerciseMetric.forSessions(ExerciseCategory.barbell, [
          session([scored(rpe: 8)]),
        ]),
        contains(ExerciseMetric.rpeOneRm),
      );
    });

    test('never for a hold, which has no maximum to read', () {
      expect(
        ExerciseMetric.forSessions(ExerciseCategory.duration, [
          session([scored(rpe: 8)]),
        ]),
        isNot(contains(ExerciseMetric.rpeOneRm)),
      );
    });

    test('nor for body weight, which has no absolute load', () {
      expect(
        ExerciseMetric.forSessions(ExerciseCategory.bodyweight, [
          session([scored(rpe: 8)]),
        ]),
        isNot(contains(ExerciseMetric.rpeOneRm)),
      );
    });

    test('a one-armed set does not count towards it', () {
      expect(
        ExerciseMetric.forSessions(ExerciseCategory.barbell, [
          session([scored(rpe: 8, side: 'left')]),
        ]),
        isNot(contains(ExerciseMetric.rpeOneRm)),
      );
    });

    test('the line reads the estimate off the scored sets', () {
      final points = buildExerciseSeries(
        sessions: [
          session([scored(rpe: 8)]),
        ],
        metric: ExerciseMetric.rpeOneRm,
        range: ChartRange.year,
        now: DateTime(2026, 3, 2),
      );

      expect(points.single.value, closeTo(123.3, 0.1));
    });

    test('a warm-up is left out of it', () {
      final points = buildExerciseSeries(
        sessions: [
          session([scored(rpe: 8, setType: 'warmup')]),
        ],
        metric: ExerciseMetric.rpeOneRm,
        range: ChartRange.year,
        now: DateTime(2026, 3, 2),
      );

      expect(points, isEmpty);
    });
  });

  group('what a muscle takes from it', () {
    RecoverySet lift({
      required String muscle,
      double weightKg = 100,
      int reps = 5,
      double? rpe,
    }) => RecoverySet(
      workoutId: 'w1',
      startedAt: DateTime(2026, 1, 1),
      exerciseId: 'ex',
      primaryMuscle: muscle,
      secondaryMuscles: const [],
      category: ExerciseCategory.barbell,
      setType: SetType.normal,
      isPrAttempt: false,
      effort: null,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
    );

    test('no score, no average', () {
      final session = muscleSessions([lift(muscle: 'borst')]).single;
      expect(session.averageRpe, isNull);
    });

    test('the heavier set weighs more in the average', () {
      final session = muscleSessions([
        lift(muscle: 'borst', weightKg: 100, reps: 5, rpe: 10),
        lift(muscle: 'borst', weightKg: 20, reps: 5, rpe: 5),
      ]).single;

      // A flat average would be 7,5; the heavy set is five times the load.
      expect(session.averageRpe, closeTo(9.17, 0.01));
    });

    test('sets you did not score are left out, not counted as zero', () {
      final session = muscleSessions([
        lift(muscle: 'borst', rpe: 9),
        lift(muscle: 'borst'),
      ]).single;

      expect(session.averageRpe, 9);
    });
  });

  group('what it does to the estimate', () {
    Duration estimate({double? rpe, PerceivedEffort? effort}) =>
        recoveryDuration(
          muscle: 'borst',
          loadKg: 1000,
          baselineLoadKg: 1000,
          hadFailureSets: false,
          wasPrAttempt: false,
          unaccustomed: false,
          effort: effort,
          averageRpe: rpe,
        );

    test('an ordinary hard session changes nothing', () {
      expect(estimate(rpe: kNeutralRpe), estimate());
    });

    test('everything at ten stretches it, but not by much', () {
      final normal = estimate().inMinutes;
      final allOut = estimate(rpe: 10).inMinutes;

      expect(allOut, greaterThan(normal));
      expect(allOut / normal, closeTo(1.10, 0.01));
    });

    test('an easy session shortens it', () {
      expect(estimate(rpe: 6).inMinutes, lessThan(estimate().inMinutes));
    });

    test('it replaces the rating you gave the session, rather than stacking', () {
      // Both answer "how hard was that". Multiplying them would count the same
      // impression twice; the per-set number is the more specific of the two.
      final withBoth = estimate(rpe: 10, effort: PerceivedEffort.allOut);
      final withRpeOnly = estimate(rpe: 10);

      expect(withBoth, withRpeOnly);
    });

    test('without a score the session rating still counts', () {
      expect(
        estimate(effort: PerceivedEffort.allOut).inMinutes,
        greaterThan(estimate().inMinutes),
      );
    });
  });
}
