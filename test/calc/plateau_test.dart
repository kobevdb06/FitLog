import 'package:fitlog/core/calc/plateau.dart';
import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sunday 4 October 2026, in the evening.
  final now = DateTime(2026, 10, 4, 21);

  /// One session a week, [weeksAgo] weeks before [now], at 18:00.
  DateTime week(int weeksAgo) =>
      DateTime(2026, 10, 4, 18).subtract(Duration(days: 7 * weeksAgo));

  ProgressPoint point(DateTime at, double value) =>
      ProgressPoint(at: at, workoutId: '$at', value: value);

  Plateau? detect(List<ProgressPoint> points) =>
      detectPlateau(points, measure: ProgressMeasure.oneRm, now: now);

  group('stilstand', () {
    test('wie elke week iets beter doet, staat niet stil', () {
      expect(
        detect([
          for (var w = 8; w >= 0; w--) point(week(w), 100 + (8 - w) * 2.5),
        ]),
        isNull,
      );
    });

    test('vijf weken niets beter: stil sinds de laatste stap vooruit', () {
      final plateau = detect([
        point(week(8), 100),
        point(week(7), 103),
        point(week(6), 106),
        point(week(5), 105),
        point(week(4), 106),
        point(week(3), 104),
        point(week(2), 106.5),
        point(week(1), 105),
        point(week(0), 102),
      ])!;

      expect(plateau.since, week(6));
      expect(plateau.weeksAt(now), 6);
      expect(plateau.sessionsSince, 6);
      expect(plateau.best, 106.5);
      expect(plateau.latest, 102);
      expect(plateau.lastAt, week(0));
    });

    test('een half procent hoger is geen stap vooruit', () {
      // 97,5 kg voor zes tegen 100 voor vijf: een andere set, geen vooruitgang.
      final plateau = detect([
        point(week(5), 116.67),
        point(week(4), 117),
        point(week(3), 116.67),
        point(week(2), 117),
        point(week(1), 116.67),
        point(week(0), 117),
      ]);

      expect(plateau, isNotNull);
      expect(plateau!.since, week(5));
    });

    test('kleine stapjes die samen een procent maken, tellen wel', () {
      expect(
        detect([
          for (var w = 6; w >= 0; w--)
            point(week(w), 100 * (1 + (6 - w) / 200)),
        ]),
        isNull,
      );
    });

    test('vier weken, maar te weinig keren: nog geen oordeel', () {
      expect(
        detect([point(week(5), 100), point(week(2), 99), point(week(0), 100)]),
        isNull,
      );
    });

    test('drie weken niets beter is nog geen stilstand', () {
      expect(
        detect([
          point(week(6), 100),
          point(week(3), 110),
          point(week(2), 108),
          point(week(1), 109),
          point(week(0), 110),
        ]),
        isNull,
      );
    });

    test('een oefening die je niet meer doet, staat niet stil', () {
      expect(
        detect([for (var w = 12; w >= 3; w--) point(week(w), 100)]),
        isNull,
      );
    });

    test('na een pauze telt alleen wat erna kwam', () {
      // Voor de zomer 120, na vier weken niets opnieuw opgebouwd.
      final rebuilding = [
        point(week(14), 120),
        point(week(13), 120),
        point(week(8), 90),
        point(week(7), 95),
        point(week(6), 100),
        point(week(5), 104),
        point(week(4), 108),
        point(week(3), 111),
        point(week(2), 114),
        point(week(1), 117),
        point(week(0), 119),
      ];
      expect(detect(rebuilding), isNull);

      final stuck = detectPlateau(
        [
          point(week(14), 120),
          point(week(8), 90),
          point(week(7), 100),
          point(week(6), 101),
          point(week(5), 100),
          point(week(4), 99),
          point(week(3), 100),
          point(week(2), 101),
          point(week(1), 100),
          point(week(0), 100),
        ],
        measure: ProgressMeasure.oneRm,
        now: now,
      )!;
      expect(stuck.since, week(6));
      expect(stuck.runStart, week(8));
      expect(stuck.best, 101);
    });
  });

  group('wat er per keer telt', () {
    ProgressSet set(
      String workout,
      DateTime at, {
      double? weight,
      int? reps,
      int? seconds,
      String? side,
      ExerciseCategory category = ExerciseCategory.dumbbell,
    }) => ProgressSet(
      workoutId: workout,
      startedAt: at,
      exerciseId: 'curl',
      primaryMuscle: 'biceps',
      category: category,
      weightKg: weight,
      reps: reps,
      durationSeconds: seconds,
      side: side,
    );

    test('de beste set, als geschatte 1RM', () {
      final points = progressPoints([
        set('a', week(1), weight: 20, reps: 10),
        set('a', week(1), weight: 22, reps: 6),
        set('b', week(0), weight: 20, reps: 12),
      ], ProgressMeasure.oneRm);

      expect(points.map((p) => p.value), [
        closeTo(26.67, 0.01),
        closeTo(28, 0.01),
      ]);
    });

    test('met één arm telt niet mee naast twee armen', () {
      final points = progressPoints([
        set('a', week(2), weight: 15, reps: 8, side: 'left'),
        set('a', week(2), weight: 15, reps: 8, side: 'right'),
        set('b', week(1), weight: 30, reps: 8),
        set('c', week(0), weight: 30, reps: 9),
        set('c', week(0), weight: 15, reps: 12, side: 'left'),
      ], ProgressMeasure.oneRm);

      expect(points.map((p) => p.workoutId), ['b', 'c']);
      expect(points.last.value, 30 * (1 + 9 / 30));
    });

    test('wie het altijd met één arm doet, krijgt die', () {
      final points = progressPoints([
        set('a', week(1), weight: 15, reps: 8, side: 'left'),
        set('b', week(0), weight: 16, reps: 8, side: 'right'),
      ], ProgressMeasure.oneRm);

      expect(points, hasLength(2));
      expect(points.every((p) => p.sided), isTrue);
    });

    test('zonder gewicht de meeste herhalingen, bij tijd de langste', () {
      expect(
        progressPoints([
          set('a', week(0), reps: 12),
          set('a', week(0), reps: 15),
        ], ProgressMeasure.reps).single.value,
        15,
      );
      expect(
        progressPoints([
          set('a', week(0), seconds: 45),
          set('a', week(0), seconds: 70),
        ], ProgressMeasure.hold).single.value,
        70,
      );
    });

    test('geassisteerd en cardio krijgen geen oordeel', () {
      expect(
        ProgressMeasure.of(ExerciseCategory.barbell),
        ProgressMeasure.oneRm,
      );
      expect(
        ProgressMeasure.of(ExerciseCategory.bodyweight),
        ProgressMeasure.reps,
      );
      expect(
        ProgressMeasure.of(ExerciseCategory.duration),
        ProgressMeasure.hold,
      );
      expect(ProgressMeasure.of(ExerciseCategory.assistedBodyweight), isNull);
      expect(ProgressMeasure.of(ExerciseCategory.cardio), isNull);
    });
  });

  group('wat er rond de stilstand gebeurde', () {
    // Vooruit tot vier weken geleden, sindsdien niets.
    final plateau = Plateau(
      measure: ProgressMeasure.oneRm,
      since: week(4),
      runStart: week(12),
      best: 110,
      latest: 108,
      lastAt: week(0),
      sessionsSince: 4,
    );

    ProgressSet set(String exercise, String muscle, DateTime at, int reps) =>
        ProgressSet(
          workoutId: 'w$at',
          startedAt: at,
          exerciseId: exercise,
          primaryMuscle: muscle,
          category: ExerciseCategory.barbell,
          weightKg: 100,
          reps: reps,
        );

    final sets = [
      // Ervoor: bench twee keer per week, met nog een borstoefening erbij.
      for (var w = 8; w >= 4; w--) ...[
        for (var i = 0; i < 3; i++) set('bench', 'borst', week(w), 8),
        for (var i = 0; i < 3; i++) set('fly', 'borst', week(w), 12),
        for (var i = 0; i < 3; i++)
          set('bench', 'borst', week(w).subtract(const Duration(days: 3)), 8),
      ],
      // Sindsdien: één keer per week, drie sets, en verder niets voor de borst.
      for (var w = 3; w >= 0; w--) ...[
        set('bench', 'borst', week(w), 5),
        set('bench', 'borst', week(w), 6),
        set('bench', 'borst', week(w), 6),
      ],
      // Een ander spiergroep telt niet mee.
      for (var w = 3; w >= 0; w--) set('squat', 'benen', week(w), 5),
    ];

    PlateauContext context({
      Iterable<SleepNight> nights = const [],
      Iterable<RecoveryEstimate> history = const [],
    }) => plateauContext(
      plateau: plateau,
      exerciseId: 'bench',
      primaryMuscle: 'borst',
      sets: sets,
      now: now,
      nights: nights,
      history: history,
    );

    test('hoe vaak, hoeveel en hoe zwaar', () {
      final facts = context();

      expect(facts.sessions, 4);
      // Vier keer in vier weken en drie uur.
      expect(facts.sessionsPerWeek, closeTo(4 / (28.125 / 7), 0.01));
      expect(facts.setsPerSession, 3);
      expect(facts.typicalReps, 6);
    });

    test('sets voor de spiergroep per week, ook ervoor', () {
      final facts = context();

      expect(facts.muscleSetsPerWeek, closeTo(12 / (28.125 / 7), 0.01));
      // Even lang ervoor, de dag van de laatste stap vooruit erbij: vijf
      // keer bench en fly samen, en vier van de sessies drie dagen eerder -
      // de vijfde valt net buiten.
      expect(
        facts.muscleSetsPerWeekBefore,
        closeTo((5 * 6 + 4 * 3) / (28.125 / 7), 0.01),
      );
    });

    test('je nachten, nu en ervoor', () {
      SleepNight night(DateTime wokeAt, int hours) => SleepNight(
        wokeAt: wokeAt,
        duration: Duration(hours: hours),
      );
      final facts = context(
        nights: [
          for (var d = 1; d <= 20; d++)
            night(now.subtract(Duration(days: d, hours: 13)), 6),
          for (var d = 30; d <= 50; d++)
            night(now.subtract(Duration(days: d, hours: 13)), 8),
        ],
      );

      expect(facts.averageSleep, const Duration(hours: 6));
      expect(facts.averageSleepBefore, const Duration(hours: 8));
    });

    test('hoe vaak de spier nog niet hersteld was', () {
      RecoveryEstimate estimate(DateTime at, Duration carried) =>
          RecoveryEstimate(
            muscle: 'borst',
            workoutId: 'w$at',
            trainedAt: at,
            recovery: const Duration(hours: 48),
            loadRatio: 1,
            provisional: false,
            carryover: carried,
          );

      final facts = context(
        history: [
          // Ervoor telt niet.
          estimate(week(5), const Duration(hours: 6)),
          estimate(week(3), const Duration(hours: 4)),
          estimate(week(2), Duration.zero),
          estimate(week(1), const Duration(hours: 2)),
          estimate(week(0), Duration.zero),
        ],
      );

      expect(facts.unrecovered, 2);
    });

    test('zonder stuk ervoor ook niets om mee te vergelijken', () {
      final facts = plateauContext(
        plateau: Plateau(
          measure: ProgressMeasure.oneRm,
          since: week(4),
          runStart: week(4),
          best: 110,
          latest: 108,
          lastAt: week(0),
          sessionsSince: 4,
        ),
        exerciseId: 'bench',
        primaryMuscle: 'borst',
        sets: sets,
        now: now,
      );

      expect(facts.muscleSetsPerWeekBefore, isNull);
      expect(facts.averageSleepBefore, isNull);
    });

    test('een houding heeft geen herhalingen', () {
      final facts = plateauContext(
        plateau: Plateau(
          measure: ProgressMeasure.hold,
          since: week(4),
          runStart: week(8),
          best: 90,
          latest: 85,
          lastAt: week(0),
          sessionsSince: 4,
        ),
        exerciseId: 'bench',
        primaryMuscle: 'borst',
        sets: sets,
        now: now,
      );

      expect(facts.typicalReps, isNull);
    });
  });
}
