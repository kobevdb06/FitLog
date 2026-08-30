import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The recovery estimate, without a database in sight.
void main() {
  final monday = DateTime(2026, 3, 2, 18);

  RecoverySet set({
    String workoutId = 'w1',
    DateTime? at,
    String exerciseId = 'squat',
    String primary = 'quadriceps',
    List<String> secondary = const [],
    ExerciseCategory category = ExerciseCategory.barbell,
    SetType type = SetType.normal,
    bool prAttempt = false,
    PerceivedEffort? effort,
    double? weightKg = 100,
    int? reps = 5,
  }) => RecoverySet(
    workoutId: workoutId,
    startedAt: at ?? monday,
    exerciseId: exerciseId,
    primaryMuscle: primary,
    secondaryMuscles: secondary,
    category: category,
    setType: type,
    isPrAttempt: prAttempt,
    effort: effort,
    weightKg: weightKg,
    reps: reps,
  );

  group('the load of one set', () {
    test('is weight times reps for anything you load', () {
      expect(setLoadKg(set(weightKg: 100, reps: 5)), 500);
    });

    test('uses your body weight where the log has no weight', () {
      final load = setLoadKg(
        set(category: ExerciseCategory.bodyweight, weightKg: null, reps: 10),
        bodyWeightKg: 80,
      );
      expect(load, 800);
    });

    test('adds the belt to a weighted pull-up', () {
      final load = setLoadKg(
        set(category: ExerciseCategory.bodyweight, weightKg: 20, reps: 5),
        bodyWeightKg: 80,
      );
      expect(load, 500);
    });

    test('takes the assistance off instead of adding it', () {
      final load = setLoadKg(
        set(
          category: ExerciseCategory.assistedBodyweight,
          weightKg: 30,
          reps: 10,
        ),
        bodyWeightKg: 80,
      );
      expect(load, 500);
    });

    test('never goes below zero on more assistance than you weigh', () {
      final load = setLoadKg(
        set(
          category: ExerciseCategory.assistedBodyweight,
          weightKg: 200,
          reps: 10,
        ),
        bodyWeightKg: 80,
      );
      expect(load, 0);
    });

    test('falls back to a stand-in weight when none was ever logged', () {
      final load = setLoadKg(
        set(category: ExerciseCategory.bodyweight, weightKg: null, reps: 1),
      );
      expect(load, kAssumedBodyWeightKg);
    });

    test('is nothing for work without reps', () {
      expect(
        setLoadKg(set(category: ExerciseCategory.cardio, reps: null)),
        0,
      );
    });
  });

  group('splitting a session over the muscles', () {
    test('the primary muscle takes all of it', () {
      final sessions = muscleSessions([set()]);
      expect(sessions.single.muscle, 'quadriceps');
      expect(sessions.single.loadKg, 500);
    });

    test('a secondary muscle takes its share', () {
      final sessions = muscleSessions([
        set(secondary: ['bilspieren']),
      ]);
      final glutes = sessions.firstWhere((s) => s.muscle == 'bilspieren');
      expect(glutes.loadKg, 500 * kSecondaryMuscleShare);
    });

    test('warm-ups do not count, here as everywhere else', () {
      expect(muscleSessions([set(type: SetType.warmup)]), isEmpty);
    });

    test('a muscle that got nothing measurable gets no session', () {
      expect(
        muscleSessions([set(category: ExerciseCategory.cardio, reps: null)]),
        isEmpty,
      );
    });

    test('failure sets and PR attempts carry over to the session', () {
      final sessions = muscleSessions([
        set(),
        set(type: SetType.failure),
        set(prAttempt: true),
      ]);
      expect(sessions.single.hadFailureSets, isTrue);
      expect(sessions.single.wasPrAttempt, isTrue);
      expect(sessions.single.loadKg, 1500);
    });

    test('sessions are kept apart by workout', () {
      final sessions = muscleSessions([
        set(workoutId: 'w1', at: monday),
        set(workoutId: 'w2', at: monday.add(const Duration(days: 2))),
      ]);
      expect(sessions, hasLength(2));
      expect(sessions.first.at.isBefore(sessions.last.at), isTrue);
    });
  });

  group('the recovery time', () {
    Duration hoursFor({
      String muscle = 'quadriceps',
      double load = 1000,
      double? baseline = 1000,
      bool failure = false,
      bool pr = false,
      bool unaccustomed = false,
      PerceivedEffort? effort,
    }) => recoveryDuration(
      muscle: muscle,
      loadKg: load,
      baselineLoadKg: baseline,
      hadFailureSets: failure,
      wasPrAttempt: pr,
      unaccustomed: unaccustomed,
      effort: effort,
    );

    test('an ordinary session lands on the base for that muscle', () {
      expect(hoursFor().inHours, 72);
      expect(hoursFor(muscle: 'biceps').inHours, 36);
    });

    test('a muscle the table does not know gets the default', () {
      expect(
        hoursFor(muscle: 'iets eigens').inHours,
        kDefaultBaseRecoveryHours.round(),
      );
    });

    test('a heavier session than usual stretches it', () {
      expect(hoursFor(load: 1400).inHours, greaterThan(72));
    });

    test('a lighter session shortens it', () {
      expect(hoursFor(load: 400).inHours, lessThan(72));
    });

    test('one enormous session does not run away with it', () {
      expect(
        hoursFor(load: 100000).inHours,
        hoursFor(load: 1000 * kMaxLoadRatio).inHours,
      );
    });

    test('without a baseline it is the base time', () {
      expect(hoursFor(baseline: null).inHours, 72);
      expect(hoursFor(baseline: 0).inHours, 72);
    });

    test('the rating moves it in both directions', () {
      final neutral = hoursFor(muscle: 'biceps').inMinutes;
      expect(
        hoursFor(muscle: 'biceps', effort: PerceivedEffort.allOut).inMinutes,
        greaterThan(neutral),
      );
      expect(
        hoursFor(muscle: 'biceps', effort: PerceivedEffort.veryEasy).inMinutes,
        lessThan(neutral),
      );
    });

    test('an unrated session is treated as neutral', () {
      expect(
        hoursFor(effort: null).inMinutes,
        hoursFor(effort: PerceivedEffort.normal).inMinutes,
      );
    });

    test('failure, a PR attempt and novelty each add on top', () {
      final plain = hoursFor(muscle: 'biceps').inHours;
      expect(hoursFor(muscle: 'biceps', failure: true).inHours,
          plain + kFailureBonusHours);
      expect(hoursFor(muscle: 'biceps', pr: true).inHours,
          plain + kPrAttemptBonusHours);
      expect(hoursFor(muscle: 'biceps', unaccustomed: true).inHours,
          plain + kUnaccustomedBonusHours);
    });

    test('it never leaves the sane range', () {
      final tiny = hoursFor(
        muscle: 'buik',
        load: 1,
        effort: PerceivedEffort.veryEasy,
      );
      expect(tiny.inHours, greaterThanOrEqualTo(kMinRecoveryHours.round()));

      final huge = hoursFor(
        load: 100000,
        failure: true,
        pr: true,
        unaccustomed: true,
        effort: PerceivedEffort.allOut,
      );
      expect(huge.inHours, kMaxRecoveryHours.round());
    });
  });

  group('the estimate over a history', () {
    List<RecoverySet> weekly(int count, {double weight = 100}) => [
      for (var i = 0; i < count; i++)
        set(
          workoutId: 'w$i',
          at: monday.subtract(Duration(days: 7 * (count - i))),
          weightKg: weight,
        ),
    ];

    test('one session is provisional', () {
      final estimates = estimateRecovery(muscleSessions(weekly(1)));
      expect(estimates.single.provisional, isTrue);
    });

    test('enough history makes it firm', () {
      final estimates = estimateRecovery(muscleSessions(weekly(5)));
      expect(estimates.single.provisional, isFalse);
      expect(estimates.single.loadRatio, closeTo(1, 0.001));
    });

    test('the ratio is the last session against the usual one', () {
      final sets = [
        ...weekly(4, weight: 100),
        set(workoutId: 'heavy', at: monday, weightKg: 200),
      ];
      final estimates = estimateRecovery(muscleSessions(sets));
      expect(estimates.single.loadRatio, closeTo(2, 0.001));
      expect(estimates.single.workoutId, 'heavy');
    });

    test('a new exercise counts as unaccustomed', () {
      final familiar = [
        ...weekly(4),
        set(workoutId: 'today', at: monday),
      ];
      final withNovelty = [
        ...weekly(4),
        set(workoutId: 'today', at: monday, exerciseId: 'hack squat'),
      ];

      final plain = estimateRecovery(muscleSessions(familiar)).single;
      final novel = estimateRecovery(muscleSessions(withNovelty)).single;
      expect(
        novel.recovery.inHours - plain.recovery.inHours,
        kUnaccustomedBonusHours,
      );
    });

    test('one estimate per muscle, from its own last session', () {
      final estimates = estimateRecovery(
        muscleSessions([
          set(workoutId: 'legs', at: monday, primary: 'quadriceps'),
          set(
            workoutId: 'push',
            at: monday.add(const Duration(days: 2)),
            primary: 'borst',
          ),
        ]),
      );
      expect(estimates.map((e) => e.muscle).toSet(), {'quadriceps', 'borst'});
    });

    test('ready and remaining follow from the moment it was trained', () {
      final estimate = estimateRecovery(muscleSessions(weekly(5))).single;
      final justTrained = estimate.trainedAt;

      expect(estimate.isReadyAt(justTrained), isFalse);
      expect(estimate.remainingAt(justTrained), estimate.recovery);
      expect(estimate.progressAt(justTrained), 0);

      final after = estimate.readyAt.add(const Duration(hours: 1));
      expect(estimate.isReadyAt(after), isTrue);
      expect(estimate.remainingAt(after), Duration.zero);
      expect(estimate.progressAt(after), 1);
    });
  });

  group('reading the stored muscle list', () {
    test('reads a JSON array', () {
      expect(decodeMuscleList('["borst", "triceps"]'), ['borst', 'triceps']);
    });

    test('an empty array is no muscles', () {
      expect(decodeMuscleList('[]'), isEmpty);
      expect(decodeMuscleList(''), isEmpty);
    });
  });
}
