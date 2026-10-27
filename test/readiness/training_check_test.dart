import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/readiness/domain/training_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// The check before a session: what counts as a sign, and what the signs
/// together say.
void main() {
  final now = DateTime(2026, 3, 3, 8);

  RecoveryEstimate estimate(String muscle, {required int hoursLeft}) =>
      RecoveryEstimate(
        muscle: muscle,
        workoutId: 'w',
        trainedAt: now.subtract(const Duration(hours: 30)),
        recovery: Duration(hours: 30 + hoursLeft),
        loadRatio: 1,
        provisional: false,
      );

  TrainingCheck check(
    Map<String, int> sets, {
    List<RecoveryEstimate> estimates = const [],
    CheckBody body = const CheckBody(),
    String name = 'Legs',
  }) => checkSession(
    routineId: name,
    routineName: name,
    muscleSets: sets,
    estimates: estimates,
    body: body,
    now: now,
  );

  SleepEntryRow night(DateTime asleep, DateTime woke) => SleepEntryRow(
    id: '${woke.millisecondsSinceEpoch}',
    fellAsleepAt: asleep.millisecondsSinceEpoch,
    wokeAt: woke.millisecondsSinceEpoch,
  );

  group('spieren', () {
    test('een spier met drie werksets die nog ruim een halve dag nodig '
        'heeft, is een sein', () {
      final legs = check(
        {'quadriceps': 9, 'hamstrings': 6},
        estimates: [estimate('quadriceps', hoursLeft: 14)],
      );
      expect(legs.signs, {CheckSign.muscles});
      expect(legs.verdict, CheckVerdict.note);
      expect(legs.reasons, ['quadriceps nog 14 u']);
      expect(legs.muscles.map((m) => m.muscle), ['quadriceps', 'hamstrings']);
    });

    test('minder dan twaalf uur, of een spier met twee sets: geen sein', () {
      final legs = check(
        {'quadriceps': 9, 'kuiten': 2},
        estimates: [
          estimate('quadriceps', hoursLeft: 10),
          estimate('kuiten', hoursLeft: 40),
        ],
      );
      expect(legs.signs, isEmpty);
      expect(legs.verdict, CheckVerdict.ready);
      expect(legs.muscles.map((m) => m.muscle), ['quadriceps']);
      expect(legs.line, 'Klaar: je spieren zijn bijna hersteld');
    });

    test('drie spieren die wachten zijn samen één sein', () {
      final legs = check(
        {'quadriceps': 9, 'hamstrings': 6, 'bilspieren': 3},
        estimates: [
          estimate('quadriceps', hoursLeft: 30),
          estimate('hamstrings', hoursLeft: 20),
          estimate('bilspieren', hoursLeft: 15),
        ],
      );
      expect(legs.signs, {CheckSign.muscles});
      expect(legs.verdict, CheckVerdict.note);
    });
  });

  group('jij', () {
    test('korter dan zes uur, of een score onder 60, is een sein', () {
      expect(
        const CheckBody(slept: Duration(hours: 5, minutes: 10)).shortNight,
        isTrue,
      );
      expect(
        const CheckBody(slept: Duration(hours: 7), score: 58).shortNight,
        isTrue,
      );
      expect(
        const CheckBody(slept: Duration(hours: 7), score: 75).shortNight,
        isFalse,
      );
    });

    test('HRV of rusthartslag voorbij de lijn van de herstelschatting is één '
        'sein', () {
      expect(
        const CheckBody(hrvMs: 49, usualHrvMs: 52).heartOff,
        isFalse,
        reason: '6% onder je gewone telt nog niet',
      );
      const both = CheckBody(
        hrvMs: 40,
        usualHrvMs: 50,
        restingHr: 60,
        usualRestingHr: 54,
      );
      expect(both.heartOff, isTrue);
      final legs = check({'quadriceps': 9}, body: both);
      expect(legs.signs, {CheckSign.heart});
      expect(legs.reasons, [
        'HRV 20% onder je gewone',
        'rusthartslag 6 hoger dan gewoonlijk',
      ]);
    });

    test('de nacht van vandaag, en je gewone uit de vier weken ervoor', () {
      final body = checkBody(
        now: now,
        nights: [
          for (var d = 1; d <= 7; d++)
            night(
              DateTime(2026, 3, 3 - d - 1, 23),
              DateTime(2026, 3, 3 - d, 6, d * 10),
            ),
          night(DateTime(2026, 3, 3, 1, 30), DateTime(2026, 3, 3, 6, 40)),
        ],
        vitals: [
          for (var d = 1; d <= 7; d++)
            VitalsDay(day: DateTime(2026, 3, 3 - d), hrvMs: 50, restingHr: 54),
          VitalsDay(day: DateTime(2026, 3, 3), hrvMs: 40, restingHr: 55),
        ],
      );
      expect(body.slept, const Duration(hours: 5, minutes: 10));
      expect(body.usualSleep, const Duration(hours: 7, minutes: 40));
      expect(body.hrvMs, 40);
      expect(body.usualHrvMs, closeTo(50, 0.001));
      expect(body.restingHr, 55);
      expect(body.usualRestingHr, closeTo(54, 0.001));
      expect(body.hrvDrop, closeTo(0.2, 0.001));
      expect(body.shortNight, isTrue);
      expect(body.heartOff, isTrue);
    });

    test('zonder nacht en zonder horloge weet de check niets over jou', () {
      final body = checkBody(now: now, nights: const [], vitals: const []);
      expect(body.known, isFalse);
      final legs = check({'quadriceps': 9}, body: body);
      expect(legs.informed, isFalse);
      expect(legs.verdict, CheckVerdict.ready);
    });
  });

  group('samen', () {
    const poorNight = CheckBody(
      slept: Duration(hours: 5, minutes: 10),
      score: 58,
    );

    test('twee seinen: beter wachten, met wat er tegen spreekt', () {
      final legs = check(
        {'quadriceps': 9},
        estimates: [estimate('quadriceps', hoursLeft: 14)],
        body: poorNight,
      );
      expect(legs.verdict, CheckVerdict.wait);
      expect(legs.line, 'Quadriceps nog 14 u · 5 u 10 geslapen, score 58');
    });

    test('dan de sessie van deze week die het meest klaar is', () {
      final estimates = [
        estimate('quadriceps', hoursLeft: 14),
        estimate('borst', hoursLeft: 20),
        estimate('lats', hoursLeft: 5),
      ];
      final legs = check(
        {'quadriceps': 9},
        estimates: estimates,
        body: poorNight,
      );
      final push = check(
        {'borst': 9},
        estimates: estimates,
        body: poorNight,
        name: 'Push',
      );
      final pull = check(
        {'lats': 9},
        estimates: estimates,
        body: poorNight,
        name: 'Pull',
      );
      final today = weighToday(legs, [push, pull]);
      expect(today.instead?.routineName, 'Pull');
      expect(today.start.routineName, 'Pull');
      expect(today.noneReady, isFalse);
    });

    test('bij een gelijke stand: wat het minst nog nodig heeft', () {
      final estimates = [
        estimate('quadriceps', hoursLeft: 30),
        estimate('borst', hoursLeft: 8),
        estimate('lats', hoursLeft: 2),
      ];
      TrainingCheck of(String muscle, String name) =>
          check({muscle: 9}, estimates: estimates, name: name);
      final legs = check(
        {'quadriceps': 9},
        estimates: estimates,
        body: poorNight,
      );
      expect(legs.verdict, CheckVerdict.wait);
      expect(
        weighToday(legs, [
          of('borst', 'Push'),
          of('lats', 'Pull'),
        ]).instead?.routineName,
        'Pull',
      );
    });

    test('is niets klaar, dan rust of lichter', () {
      const off = CheckBody(
        slept: Duration(hours: 5),
        hrvMs: 40,
        usualHrvMs: 50,
      );
      final legs = check({'quadriceps': 9}, body: off);
      final push = check({'borst': 9}, body: off, name: 'Push');
      final today = weighToday(legs, [push]);
      expect(today.instead, isNull);
      expect(today.noneReady, isTrue);
      expect(today.start.routineName, 'Legs');
    });

    test('kan de sessie gaan, dan blijft het die', () {
      final legs = check({'quadriceps': 9}, body: poorNight);
      final today = weighToday(legs, [
        check({'borst': 9}, name: 'Push'),
      ]);
      expect(legs.verdict, CheckVerdict.note);
      expect(today.instead, isNull);
      expect(today.noneReady, isFalse);
    });
  });
}
