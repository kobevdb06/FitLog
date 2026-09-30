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
      expect(setLoadKg(set(category: ExerciseCategory.cardio, reps: null)), 0);
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
      expect(
        hoursFor(muscle: 'biceps', failure: true).inHours,
        plain + kFailureBonusHours,
      );
      expect(
        hoursFor(muscle: 'biceps', pr: true).inHours,
        plain + kPrAttemptBonusHours,
      );
      expect(
        hoursFor(muscle: 'biceps', unaccustomed: true).inHours,
        plain + kUnaccustomedBonusHours,
      );
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
      final familiar = [...weekly(4), set(workoutId: 'today', at: monday)];
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

  group('vermoeidheid die zich opstapelt', () {
    // Vier gewone weken ervoor, zodat geen van deze sessies als nieuw telt en
    // alleen de opstapeling het verschil maakt.
    List<RecoverySet> history() => [
      for (var i = 0; i < 4; i++)
        set(
          workoutId: 'h$i',
          at: monday.subtract(Duration(days: 7 * (4 - i))),
        ),
    ];
    final wednesday = monday.add(const Duration(days: 2));

    test('een tweede sessie voor de eerste verwerkt is, duurt langer', () {
      // Maandag benen, woensdag weer. Maandag had 72 uur nodig; woensdag is
      // er daar nog 24 van over, en die verdwijnen niet omdat je opnieuw
      // traint.
      final alone = estimateRecovery(
        muscleSessions([...history(), set(workoutId: 'wed', at: wednesday)]),
      ).single;
      final stacked = estimateRecovery(
        muscleSessions([
          ...history(),
          set(workoutId: 'mon', at: monday),
          set(workoutId: 'wed', at: wednesday),
        ]),
      ).single;

      expect(stacked.workoutId, 'wed');
      expect(stacked.recovery, greaterThan(alone.recovery));
      // De helft van wat er nog openstond.
      expect(stacked.carryover, const Duration(hours: 12));
      expect(stacked.recovery - alone.recovery, stacked.carryover);
    });

    test('sessies ver genoeg uit elkaar stapelen niet', () {
      final estimate = estimateRecovery(
        muscleSessions([
          ...history(),
          set(workoutId: 'mon', at: monday),
          set(workoutId: 'next', at: monday.add(const Duration(days: 7))),
        ]),
      ).single;

      expect(estimate.carryover, Duration.zero);
    });

    test('en het plafond blijft het plafond', () {
      // Drie zware dagen na elkaar mogen de schatting rekken, niet laten
      // weglopen.
      final estimate = estimateRecovery(
        muscleSessions([
          ...history(),
          for (var d = 0; d < 3; d++)
            set(
              workoutId: 'd$d',
              at: monday.add(Duration(days: d)),
              weightKg: 200,
              type: SetType.failure,
            ),
        ]),
      ).single;

      expect(estimate.recovery, lessThanOrEqualTo(const Duration(hours: 96)));
    });
  });

  group('wat je zelf zegt over je spieren', () {
    // Vier gewone weken en dan vandaag: een schatting met een vast ijkpunt.
    List<RecoverySet> weeks() => [
      for (var i = 0; i < 4; i++)
        set(
          workoutId: 'h$i',
          at: monday.subtract(Duration(days: 7 * (4 - i))),
        ),
      set(workoutId: 'today', at: monday),
    ];

    RecoveryEstimate estimate([List<SorenessCheck> checks = const []]) =>
        estimateRecovery(muscleSessions(weeks()), checks: checks).single;

    SorenessCheck said(Duration after, SorenessLevel level, {DateTime? from}) =>
        SorenessCheck(
          muscle: 'quadriceps',
          at: (from ?? monday).add(after),
          level: level,
        );

    test('pijnlijk houdt je nog een dag tegen, wat de rekensom ook zegt', () {
      final plain = estimate();
      // Een uur na het moment dat de app "klaar" zei.
      final after = plain.recovery + const Duration(hours: 1);

      final sore = estimate([said(after, SorenessLevel.sore)]);

      expect(sore.check, SorenessLevel.sore);
      expect(sore.readyAt, monday.add(after).add(kSoreAtLeast));
      expect(sore.isReadyAt(plain.readyAt), isFalse);
    });

    test('stijf is bijna: een halve dag', () {
      final plain = estimate();
      final after = plain.recovery;

      final stiff = estimate([said(after, SorenessLevel.stiff)]);

      expect(stiff.readyAt, monday.add(after).add(kStiffAtLeast));
    });

    test('fris een dag later haalt de schatting naar nu', () {
      final fresh = estimate([
        said(const Duration(hours: 30), SorenessLevel.fresh),
      ]);

      expect(fresh.readyAt, monday.add(const Duration(hours: 30)));
    });

    test('maar fris op de avond zelf zegt nog niets', () {
      // Spierpijn komt meestal de dag erna. Wie zich twee uur na de training
      // fris voelt, weet dat nog niet.
      final plain = estimate();
      final early = estimate([
        said(const Duration(hours: 2), SorenessLevel.fresh),
      ]);

      expect(
        early.readyAt.isBefore(monday.add(kFreshMeansSomethingAfter)),
        isFalse,
      );
      expect(early.readyAt.isAfter(plain.readyAt), isFalse);
    });

    test('een antwoord van voor de laatste sessie geldt niet meer', () {
      final plain = estimate();
      final old = estimate([
        said(
          const Duration(hours: 100),
          SorenessLevel.sore,
          from: monday.subtract(const Duration(days: 7)),
        ),
      ]);

      expect(old.check, isNull);
      // Eén oud antwoord is ook te weinig om iets uit te leren.
      expect(old.personalFactor, 1);
      expect(old.recovery, plain.recovery);
    });

    group('en daar leert de app van', () {
      List<SorenessCheck> afterEachWeek(
        Duration after,
        SorenessLevel level, {
        int weeks = 4,
      }) => [
        for (var i = 0; i < weeks; i++)
          said(
            after,
            level,
            from: monday.subtract(Duration(days: 7 * (4 - i))),
          ),
      ];

      test('wie telkens nog pijn heeft, herstelt trager dan de tabel', () {
        final plain = estimate();
        final slow = estimate(
          afterEachWeek(const Duration(hours: 100), SorenessLevel.sore),
        );

        expect(slow.personalFactor, greaterThan(1));
        expect(slow.recovery, greaterThan(plain.recovery));
      });

      test('wie telkens al na een dag fris is, sneller', () {
        final plain = estimate();
        final quick = estimate(
          afterEachWeek(const Duration(hours: 30), SorenessLevel.fresh),
        );

        expect(quick.personalFactor, lessThan(1));
        expect(quick.recovery, lessThan(plain.recovery));
      });

      test('maar niet voordat er een patroon is', () {
        final twice = estimate(
          afterEachWeek(
            const Duration(hours: 100),
            SorenessLevel.sore,
            weeks: kChecksForPersonalFactor - 1,
          ),
        );

        expect(twice.personalFactor, 1);
      });

      test('en nooit buiten de grenzen', () {
        // Nog pijnlijk vlak voor de volgende week: meer dan twee keer zo
        // traag als de tabel, en toch blijft het bij de bovengrens.
        final extreme = estimate(
          afterEachWeek(const Duration(hours: 160), SorenessLevel.sore),
        );

        expect(extreme.personalFactor, kMaxPersonalFactor);
      });
    });
  });

  group('slaap', () {
    List<RecoverySet> weeks() => [
      for (var i = 0; i < 4; i++)
        set(
          workoutId: 'h$i',
          at: monday.subtract(Duration(days: 7 * (4 - i))),
        ),
      set(workoutId: 'today', at: monday),
    ];

    /// Nachten na de training van maandagavond, telkens om zeven uur op.
    List<SleepNight> nights(double hours, {int count = 3}) => [
      for (var n = 1; n <= count; n++)
        SleepNight(
          wokeAt: DateTime(monday.year, monday.month, monday.day + n, 7),
          duration: Duration(minutes: (hours * 60).round()),
        ),
    ];

    RecoveryEstimate estimate([List<SleepNight> slept = const []]) =>
        estimateRecovery(muscleSessions(weeks()), nights: slept).single;

    test('niets ingevuld verandert niets', () {
      expect(estimate().sleepFactor, 1);
      expect(estimate().averageSleep, isNull);
    });

    test('genoeg geslapen verandert ook niets', () {
      // Langer slapen dan genoeg maakt het niet korter: daar is te weinig
      // bewijs voor.
      final plain = estimate();
      final rested = estimate(nights(9));

      expect(rested.sleepFactor, 1);
      expect(rested.recovery, plain.recovery);
    });

    test('korte nachten rekken de schatting', () {
      final plain = estimate();
      final short = estimate(nights(5));

      expect(
        short.sleepFactor,
        closeTo(1 + 2 * kSleepCostPerMissingHour, 1e-9),
      );
      expect(short.recovery, greaterThan(plain.recovery));
      expect(short.averageSleep, const Duration(hours: 5));
    });

    test('maar nooit onbeperkt', () {
      expect(estimate(nights(1)).sleepFactor, kMaxSleepFactor);
    });

    test('alleen de nachten na die sessie tellen', () {
      // Een korte nacht voor de training zegt niets over het herstel ervan.
      final before = estimate([
        SleepNight(
          wokeAt: monday.subtract(const Duration(hours: 11)),
          duration: const Duration(hours: 4),
        ),
      ]);

      expect(before.sleepFactor, 1);
    });
  });

  group('alcohol', () {
    test('onder de drempel voor je gewicht verandert het niets', () {
      // Een halve gram per kilo gaf in het onderzoek geen meetbaar verschil:
      // voor 80 kg is dat vier glazen.
      expect(alcoholFactor(0, bodyWeightKg: 80), 1);
      expect(alcoholFactor(4, bodyWeightKg: 80), 1);
    });

    test('daarboven rekt het, naar de hoeveelheid', () {
      final six = alcoholFactor(6, bodyWeightKg: 80);
      final ten = alcoholFactor(10, bodyWeightKg: 80);

      expect(six, greaterThan(1));
      expect(ten, greaterThan(six));
    });

    test('tot een plafond', () {
      expect(alcoholFactor(30, bodyWeightKg: 80), kMaxAlcoholFactor);
    });

    test('en wie lichter is, zit er sneller aan', () {
      expect(
        alcoholFactor(6, bodyWeightKg: 60),
        greaterThan(alcoholFactor(6, bodyWeightKg: 90)),
      );
    });

    group('in de schatting', () {
      List<RecoverySet> weeks() => [
        for (var i = 0; i < 4; i++)
          set(
            workoutId: 'h$i',
            at: monday.subtract(Duration(days: 7 * (4 - i))),
          ),
        set(workoutId: 'today', at: monday),
      ];

      RecoveryEstimate estimate(List<DrinkDay> drinks) => estimateRecovery(
        muscleSessions(weeks()),
        drinks: drinks,
        bodyWeightKg: 80,
      ).single;

      test('telt de dag waarop je trainde', () {
        final plain = estimate(const []);
        final evening = estimate([
          DrinkDay(
            day: DateTime(monday.year, monday.month, monday.day),
            drinks: 8,
          ),
        ]);

        expect(evening.drinks, 8);
        expect(evening.alcoholFactor, greaterThan(1));
        expect(evening.recovery, greaterThan(plain.recovery));
      });

      test('en niet de dag ervoor', () {
        final dayBefore = estimate([
          DrinkDay(
            day: DateTime(monday.year, monday.month, monday.day - 1),
            drinks: 8,
          ),
        ]);

        expect(dayBefore.drinks, 0);
        expect(dayBefore.alcoholFactor, 1);
      });
    });
  });

  group('HRV en rusthartslag', () {
    List<RecoverySet> weeks() => [
      for (var i = 0; i < 4; i++)
        set(
          workoutId: 'h$i',
          at: monday.subtract(Duration(days: 7 * (4 - i))),
        ),
      set(workoutId: 'today', at: monday),
    ];

    DateTime day(int offset) =>
        DateTime(monday.year, monday.month, monday.day + offset);

    /// Vier gewone weken voor de training: HRV 50, rusthartslag 55.
    List<VitalsDay> usual({int days = 28}) => [
      for (var d = 1; d <= days; d++)
        VitalsDay(day: day(-d), hrvMs: 50, restingHr: 55),
    ];

    /// De drie ochtenden na de training.
    List<VitalsDay> after({double? hrv, double? rhr}) => [
      for (var d = 1; d <= 3; d++)
        VitalsDay(day: day(d), hrvMs: hrv, restingHr: rhr),
    ];

    RecoveryEstimate estimate(
      List<VitalsDay> vitals, {
      List<SleepNight> nights = const [],
    }) => estimateRecovery(
      muscleSessions(weeks()),
      vitals: vitals,
      nights: nights,
    ).single;

    test('zonder horloge verandert er niets', () {
      final plain = estimate(const []);

      expect(plain.vitalsFactor, 1);
      expect(plain.hrvDrop, isNull);
      expect(plain.restingHrRise, isNull);
    });

    test('een gewone ochtend ook niet', () {
      // HRV schommelt van dag tot dag met zo'n tiende, zonder dat er iets is.
      final plain = estimate(const []);
      final ordinary = estimate([...usual(), ...after(hrv: 47, rhr: 57)]);

      expect(ordinary.hrvDrop, closeTo(0.06, 1e-9));
      expect(ordinary.restingHrRise, closeTo(2, 1e-9));
      expect(ordinary.vitalsFactor, 1);
      expect(ordinary.recovery, plain.recovery);
    });

    test('een HRV ver onder je gewone rekt de schatting', () {
      final plain = estimate(const []);
      final low = estimate([...usual(), ...after(hrv: 40)]);

      // Een vijfde onder je gewone: twee derde van het volle effect.
      expect(low.hrvDrop, closeTo(0.2, 1e-9));
      expect(
        low.vitalsFactor,
        closeTo(
          1 +
              (0.2 - kHrvDropNoEffect) /
                  (kHrvDropFullEffect - kHrvDropNoEffect) *
                  (kMaxVitalsFactor - 1),
          1e-9,
        ),
      );
      expect(low.recovery, greaterThan(plain.recovery));
    });

    test('een rusthartslag ver erboven ook, tot een plafond', () {
      final high = estimate([...usual(), ...after(rhr: 70)]);

      expect(high.restingHrRise, closeTo(15, 1e-9));
      expect(high.vitalsFactor, closeTo(kMaxVitalsFactor, 1e-9));
    });

    test('maar een goede ochtend maakt het niet korter', () {
      // HRV leest het zenuwstelsel, niet de quadriceps: een hoge waarde
      // bewijst niet dat de spier hersteld is.
      final plain = estimate(const []);
      final good = estimate([...usual(), ...after(hrv: 70, rhr: 48)]);

      expect(good.hrvDrop, lessThan(0));
      expect(good.vitalsFactor, 1);
      expect(good.recovery, plain.recovery);
    });

    test('pas met een week aan metingen weet de app wat gewoon is', () {
      final few = estimate([
        ...usual(days: kVitalsForBaseline - 1),
        ...after(hrv: 30),
      ]);

      expect(few.hrvDrop, isNull);
      expect(few.vitalsFactor, 1);
    });

    test('de ochtend van de training zelf telt niet', () {
      // Die nacht ging aan de training vooraf.
      final sameDay = estimate([...usual(), VitalsDay(day: day(0), hrvMs: 30)]);

      expect(sameDay.hrvDrop, isNull);
      expect(sameDay.vitalsFactor, 1);
    });

    test('en de ochtenden na de volgende sessie horen bij die', () {
      final effect = vitalsEffect(
        monday,
        [
          ...usual(),
          VitalsDay(day: day(1), hrvMs: 50),
          VitalsDay(day: day(2), hrvMs: 30),
          VitalsDay(day: day(3), hrvMs: 30),
        ],
        // De volgende sessie, dinsdagavond.
        until: monday.add(const Duration(days: 1)),
      );

      expect(effect.hrvDrop, closeTo(0, 1e-9));
      expect(effect.factor, 1);
    });

    test('en niet bovenop korte nachten: dat is vaak hetzelfde nieuws', () {
      final short = [
        for (var n = 1; n <= 3; n++)
          SleepNight(
            wokeAt: DateTime(monday.year, monday.month, monday.day + n, 7),
            duration: const Duration(hours: 5),
          ),
      ];
      final watchOnly = estimate([...usual(), ...after(rhr: 70)]);
      final both = estimate([...usual(), ...after(rhr: 70)], nights: short);

      expect(both.sleepFactor, greaterThan(1));
      expect(both.recovery, watchOnly.recovery);
    });
  });

  group('lopen en fietsen', () {
    List<RecoverySet> weeks(String primary) => [
      for (var i = 0; i < 4; i++)
        set(
          workoutId: 'h$i',
          primary: primary,
          at: monday.subtract(Duration(days: 7 * (4 - i))),
        ),
      set(workoutId: 'today', primary: primary, at: monday),
    ];

    RecoveryEstimate estimate(
      List<CardioSession> cardio, {
      String primary = 'quadriceps',
      List<SorenessCheck> checks = const [],
    }) => estimateRecovery(
      muscleSessions(weeks(primary)),
      cardio: cardio,
      checks: checks,
    ).single;

    CardioSession run(
      DateTime start, {
      int minutes = 45,
      CardioKind kind = CardioKind.running,
    }) => CardioSession(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      kind: kind,
    );

    // Twee dagen na de legday, 's avonds.
    final wednesday = DateTime(monday.year, monday.month, monday.day + 2, 20);

    test('een loop na je legday houdt je benen minstens een dag tegen', () {
      final plain = estimate(const []);
      final ran = estimate([run(wednesday)]);
      final floor = wednesday.add(const Duration(minutes: 45, hours: 24));

      expect(plain.readyAt.isBefore(floor), isTrue);
      expect(ran.readyAt, floor);
      expect(ran.cardio?.kind, CardioKind.running);
    });

    test('een lange loop langer', () {
      final long = estimate([run(wednesday, minutes: 90)]);

      expect(
        long.readyAt,
        wednesday.add(const Duration(minutes: 90, hours: 36)),
      );
    });

    test('een korte loop maakt een legday niet korter', () {
      final plain = estimate(const []);
      final jog = estimate([
        run(DateTime(monday.year, monday.month, monday.day + 1, 7)),
      ]);

      expect(jog.recovery, plain.recovery);
      expect(jog.cardio, isNull);
    });

    test('fietsen raakt je quadriceps', () {
      final rode = estimate([
        run(wednesday, minutes: 120, kind: CardioKind.cycling),
      ]);

      expect(
        rode.readyAt,
        wednesday.add(const Duration(minutes: 120, hours: 24)),
      );
    });

    test('maar niet je hamstrings', () {
      final plain = estimate(const [], primary: 'hamstrings');
      final rode = estimate([
        run(wednesday, minutes: 120, kind: CardioKind.cycling),
      ], primary: 'hamstrings');

      expect(rode.recovery, plain.recovery);
    });

    test('fris gezegd na de loop: dan ben je fris', () {
      // Wat je zegt, gaat voor de rekensom - ook voor die van de loop.
      final thursday = DateTime(monday.year, monday.month, monday.day + 3, 9);
      final fresh = estimate(
        [run(wednesday)],
        checks: [
          SorenessCheck(
            muscle: 'quadriceps',
            at: thursday,
            level: SorenessLevel.fresh,
          ),
        ],
      );

      expect(fresh.readyAt, thursday);
    });

    test('maar een loop na dat antwoord telt weer', () {
      final tuesday = DateTime(monday.year, monday.month, monday.day + 1, 20);
      final ranAfter = estimate(
        [run(wednesday)],
        checks: [
          SorenessCheck(
            muscle: 'quadriceps',
            at: tuesday,
            level: SorenessLevel.fresh,
          ),
        ],
      );

      expect(ranAfter.check, SorenessLevel.fresh);
      expect(
        ranAfter.readyAt,
        wednesday.add(const Duration(minutes: 45, hours: 24)),
      );
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
