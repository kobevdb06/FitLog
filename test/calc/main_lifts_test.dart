import 'package:fitlog/core/calc/main_lifts.dart';
import 'package:fitlog/core/calc/plateau.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 7, 6, 18);
  DateTime week(int w) => start.add(Duration(days: 7 * w));

  /// One session of [exercise] in week [w]: a single at [kg], or [reps]
  /// repetitions without weight.
  ProgressSet session(
    String exercise,
    int w, {
    double? kg,
    int reps = 1,
    ExerciseCategory category = ExerciseCategory.barbell,
  }) => ProgressSet(
    workoutId: 'w$w-$exercise',
    startedAt: week(w),
    exerciseId: exercise,
    primaryMuscle: 'borst',
    category: category,
    weightKg: kg,
    reps: reps,
  );

  group('welke oefeningen', () {
    test('de vaakst gedane eerst', () {
      final trends = liftTrends([
        for (var w = 0; w < 3; w++) session('bench', w, kg: 100),
        for (var w = 0; w < 5; w++) session('squat', w, kg: 140),
        for (var w = 0; w < 4; w++) session('row', w, kg: 80),
      ]);

      expect([for (final t in trends) t.exerciseId], ['squat', 'row', 'bench']);
    });

    test('even vaak: de laatst gedane eerst', () {
      final trends = liftTrends([
        session('bench', 0, kg: 100),
        session('bench', 2, kg: 100),
        session('row', 1, kg: 80),
        session('row', 3, kg: 80),
      ]);

      expect([for (final t in trends) t.exerciseId], ['row', 'bench']);
    });

    test('één sessie is geen richting', () {
      final trends = liftTrends([
        session('bench', 0, kg: 100),
        session('row', 1, kg: 80),
        session('row', 2, kg: 80),
      ]);

      expect([for (final t in trends) t.exerciseId], ['row']);
    });

    test('geassisteerd en cardio tellen niet mee', () {
      final trends = liftTrends([
        for (var w = 0; w < 3; w++)
          session(
            'assisted',
            w,
            kg: 30,
            reps: 8,
            category: ExerciseCategory.assistedBodyweight,
          ),
        for (var w = 0; w < 3; w++)
          session('run', w, category: ExerciseCategory.cardio),
      ]);

      expect(trends, isEmpty);
    });

    test('zonder gewicht: de meeste herhalingen', () {
      final trends = liftTrends([
        for (var w = 0; w < 2; w++)
          session(
            'pullup',
            w,
            reps: 8 + w,
            category: ExerciseCategory.bodyweight,
          ),
      ]);

      expect(trends.single.measure, ProgressMeasure.reps);
      expect(trends.single.latest, 9);
    });
  });

  group('hoe ver ze kwam', () {
    test(
      'het beste van de laatste twee tegen het beste van de eerste twee',
      () {
        final trend = liftTrends([
          session('bench', 0, kg: 90),
          session('bench', 1, kg: 92.5),
          session('bench', 2, kg: 95),
          session('bench', 3, kg: 100),
          // A light day at the end does not undo the month.
          session('bench', 4, kg: 85),
        ]).single;

        expect(trend.earliest, 92.5);
        expect(trend.latest, 100);
        expect(trend.change, 7.5);
        expect(trend.since, week(0));
      },
    );

    test('met minder dan vier sessies valt er niets te vergelijken', () {
      final trend = liftTrends([
        session('bench', 0, kg: 90),
        session('bench', 1, kg: 95),
        session('bench', 2, kg: 100),
      ]).single;

      expect(trend.latest, 100);
      expect(trend.earliest, isNull);
      expect(trend.change, isNull);
    });
  });
}
