import 'package:fitlog/core/calc/progression.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<HintSet> sets(double kg, List<int> reps, {double? rpe}) => [
    for (final r in reps) HintSet(weightKg: kg, reps: r, rpe: rpe),
  ];

  ProgressionHint? hint(
    List<HintSet> last, {
    ExerciseCategory category = ExerciseCategory.barbell,
    int? target,
    double step = 2.5,
  }) => progressionHint(
    category: category,
    last: last,
    targetReps: target,
    step: step,
  );

  group('met gewicht', () {
    test('alles gehaald: een stap zwaarder, zelfde doel', () {
      final h = hint(sets(80, [8, 8, 8], rpe: 8), target: 8)!;

      expect(h.kind, HintKind.heavier);
      expect(h.weightKg, 82.5);
      expect(h.reps, 8);
      expect(h.lastWeightKg, 80);
      expect(h.lastRpe, 8);
    });

    test('zonder RPE telt gehaald als gehaald', () {
      expect(hint(sets(80, [8, 8, 8]), target: 8)!.kind, HintKind.heavier);
    });

    test('niet alles gehaald: zelfde gewicht, mik op het doel', () {
      final h = hint(sets(15, [12, 11, 10]), target: 12)!;

      expect(h.kind, HintKind.sameWeight);
      expect(h.weightKg, 15);
      expect(h.reps, 12);
    });

    test('gehaald, maar het was alles wat je had: nog eens', () {
      final h = hint(sets(100, [5, 5, 5], rpe: 9), target: 5)!;

      expect(h.kind, HintKind.repeat);
      expect(h.weightKg, 100);
      expect(h.reps, 5);
    });

    test('RPE 8,5 is nog ruimte genoeg', () {
      expect(
        hint(sets(100, [5, 5, 5], rpe: 8.5), target: 5)!.kind,
        HintKind.heavier,
      );
    });

    test('zonder doel in de routine is het beste van vorige keer het doel', () {
      expect(hint(sets(80, [10, 10, 10]))!.reps, 10);
      // 10, 9, 8: het doel is 10, en dat haalden niet alle sets.
      expect(hint(sets(80, [10, 9, 8]))!.kind, HintKind.sameWeight);
    });

    test(
      'gemeten aan het zwaarste gewicht, niet aan een lichtere set erna',
      () {
        final h = hint([
          ...sets(100, [5, 5]),
          const HintSet(weightKg: 80, reps: 10),
        ], target: 5)!;

        expect(h.kind, HintKind.heavier);
        expect(h.weightKg, 102.5);
      },
    );

    test('de stap van de oefening zelf', () {
      expect(
        hint(
          sets(20, [12, 12, 12]),
          category: ExerciseCategory.dumbbell,
          step: 2,
        )!.weightKg,
        22,
      );
    });
  });

  group('zonder gewicht', () {
    test('alle sets even goed: één herhaling meer', () {
      final h = hint([
        for (var i = 0; i < 3; i++) const HintSet(reps: 12),
      ], category: ExerciseCategory.bodyweight)!;

      expect(h.kind, HintKind.moreReps);
      expect(h.reps, 13);
      expect(h.weightKg, isNull);
    });

    test('ongelijk: eerst alle sets naar de beste', () {
      final h = hint(const [
        HintSet(reps: 12),
        HintSet(reps: 10),
        HintSet(reps: 9),
      ], category: ExerciseCategory.bodyweight)!;

      expect(h.kind, HintKind.evenReps);
      expect(h.reps, 12);
    });
  });

  test('een plank: vijf seconden langer dan de langste', () {
    final h = hint(const [
      HintSet(durationSeconds: 60),
      HintSet(durationSeconds: 75),
    ], category: ExerciseCategory.duration)!;

    expect(h.kind, HintKind.longer);
    expect(h.seconds, 80);
  });

  test('geen hint zonder vorige keer, bij geassisteerd en bij cardio', () {
    expect(hint(const []), isNull);
    expect(
      hint(sets(30, [8, 8]), category: ExerciseCategory.assistedBodyweight),
      isNull,
    );
    expect(
      hint(const [
        HintSet(durationSeconds: 1800),
      ], category: ExerciseCategory.cardio),
      isNull,
    );
  });

  group('de stap', () {
    test('de kleinste stap tussen de gewichten die je gebruikte', () {
      expect(learnedWeightStep([60, 62.5, 65, 70, 70]), 2.5);
      expect(learnedWeightStep([20, 22, 24]), 2);
    });

    test('met minder dan drie gewichten nog geen gewoonte', () {
      expect(learnedWeightStep([60, 70]), isNull);
    });

    test('een verschil van een kwart kilo is afronding, geen stap', () {
      expect(learnedWeightStep([60, 60.25, 62.5, 65]), 2.5);
      // En dan zijn het er maar twee.
      expect(learnedWeightStep([60, 60.25, 65]), isNull);
    });

    test('anders: twee keer je kleinste schijf, of een vaste stap', () {
      expect(
        defaultWeightStep(ExerciseCategory.barbell, platesKg: [20, 10, 1.25]),
        2.5,
      );
      expect(
        defaultWeightStep(ExerciseCategory.barbell, platesKg: [20, 10, 0.5]),
        1,
      );
      expect(defaultWeightStep(ExerciseCategory.dumbbell), 2);
      expect(defaultWeightStep(ExerciseCategory.machine), 2.5);
      expect(defaultWeightStep(ExerciseCategory.cable), 2.5);
    });
  });
}
