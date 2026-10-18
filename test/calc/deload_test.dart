import 'package:fitlog/core/calc/deload.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

void main() {
  group('hoe licht', () {
    const plan = DeloadPlan(setsPercent: 50, weightPercent: 10);

    test('de helft van de sets, naar boven, en nooit geen', () {
      expect(plan.keptSets(4), 2);
      expect(plan.keptSets(3), 2);
      expect(plan.keptSets(1), 1);
      expect(const DeloadPlan(setsPercent: 80).keptSets(2), 1);
      expect(plan.keptSets(0), 0);
    });

    test('lichter, op de dichtste stap, en nooit zwaarder', () {
      expect(plan.weight(80, 2.5), 72.5);
      expect(plan.weight(100, 2.5), 90);
      expect(plan.weight(20, 2), 18);
      // A tenth of 5 kg is less than half a step: it stays.
      expect(plan.weight(5, 2.5), 5);
      expect(plan.weight(null, 2.5), isNull);
      expect(const DeloadPlan(weightPercent: 0).weight(80, 2.5), 80);
    });

    test('herhalingen en seconden', () {
      const fewer = DeloadPlan(repsPercent: 25);
      expect(fewer.reps(8), 6);
      expect(fewer.reps(1), 1);
      expect(fewer.seconds(60), 45);
      expect(plan.reps(8), 8, reason: 'zero percent changes nothing');
    });
  });

  group('een oefening', () {
    test('warming-up blijft, dropset weg, de eerste werksets lichter', () {
      final out = deloadExercise(
        const [
          DeloadInput(type: SetType.warmup, weightKg: 40, reps: 10),
          DeloadInput(type: SetType.normal, weightKg: 80, reps: 8),
          DeloadInput(type: SetType.normal, weightKg: 80, reps: 8),
          DeloadInput(type: SetType.normal, weightKg: 80, reps: 8),
          DeloadInput(type: SetType.normal, weightKg: 80, reps: 8),
          DeloadInput(type: SetType.drop, weightKg: 60, reps: 12),
        ],
        plan: const DeloadPlan(),
        stepKg: 2.5,
      );

      expect(out.map((o) => o.kept), [true, true, true, false, false, false]);
      expect(out[0].weightKg, 40);
      expect(out[1].weightKg, 72.5);
      expect(out[1].reps, 8);
    });

    test('per kant, bij één arm tegelijk', () {
      final out = deloadExercise(
        const [
          DeloadInput(type: SetType.normal, side: SetSide.left, weightKg: 20),
          DeloadInput(type: SetType.normal, side: SetSide.right, weightKg: 20),
          DeloadInput(type: SetType.normal, side: SetSide.left, weightKg: 20),
          DeloadInput(type: SetType.normal, side: SetSide.right, weightKg: 20),
        ],
        plan: const DeloadPlan(),
        stepKg: 2,
      );

      expect(out.map((o) => o.kept), [true, true, false, false]);
    });

    test('met dropsets erin, als je dat zo instelt', () {
      final out = deloadExercise(
        const [
          DeloadInput(type: SetType.normal, weightKg: 80, reps: 8),
          DeloadInput(type: SetType.drop, weightKg: 60, reps: 12),
        ],
        plan: const DeloadPlan(setsPercent: 0, dropHardSets: false),
        stepKg: 2.5,
      );

      expect(out.map((o) => o.kept), [true, true]);
    });
  });

  group('wanneer het tijd is', () {
    DateTime day(int d) => DateTime(2026, 10, d);

    test('weken op rij met training tellen, een week vrij breekt het', () {
      final sessions = [
        // A week off: 21-27 sep.
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 29),
        day(6),
        day(13),
        day(14),
      ];

      expect(
        weeksWithoutBreak(now: day(15), sessions: sessions, deloads: const []),
        3,
      );
    });

    test('deze week nog niets: dan telt ze nog niet mee', () {
      expect(
        weeksWithoutBreak(
          now: day(19),
          sessions: [day(6), day(13)],
          deloads: const [],
        ),
        2,
      );
    });

    test('een deload is een pauze', () {
      expect(
        weeksWithoutBreak(
          now: day(15),
          sessions: [DateTime(2026, 9, 29), day(6), day(13), day(14)],
          deloads: [(from: day(5), until: day(8))],
        ),
        1,
      );
    });

    test('na zoveel weken, of met zoveel oefeningen die stilstaan', () {
      expect(
        deloadDue(weeks: 6, stalled: const [], weeksLimit: 6, stalledLimit: 2),
        isNotNull,
      );
      expect(
        deloadDue(
          weeks: 2,
          stalled: const ['Bench Press', 'Back Squat'],
          weeksLimit: 6,
          stalledLimit: 2,
        )!.stalled,
        hasLength(2),
      );
      expect(
        deloadDue(
          weeks: 5,
          stalled: const ['Bench Press'],
          weeksLimit: 6,
          stalledLimit: 2,
        ),
        isNull,
      );
    });
  });

  group('in de database', () {
    late AppDatabase db;
    final now = DateTime(2026, 10, 18, 10);

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
    });

    tearDown(() => db.close());

    test('een deload loopt van de eerste dag tot en met de laatste', () async {
      await db.deloadDao.start(
        from: now,
        days: 5,
        plan: const DeloadPlan(),
        source: 'user',
        now: now,
      );

      final row = (await db.deloadDao.currentAt(now))!;
      expect(row.dayAt(now), 1);
      expect(row.lastDay, DateTime(2026, 10, 22));
      expect(await db.deloadDao.onAt(DateTime(2026, 10, 22, 23)), isNotNull);
      expect(await db.deloadDao.onAt(DateTime(2026, 10, 23, 0, 1)), isNull);
    });

    test('een geplande telt nog niet, maar is wel de huidige', () async {
      await db.deloadDao.start(
        from: DateTime(2026, 10, 19),
        days: 7,
        plan: const DeloadPlan(),
        source: 'user',
        now: now,
      );

      expect(await db.deloadDao.onAt(now), isNull);
      expect(await db.deloadDao.currentAt(now), isNotNull);
    });

    test('stoppen: een lopende eindigt, een geplande verdwijnt', () async {
      final going = await db.deloadDao.start(
        from: now,
        days: 7,
        plan: const DeloadPlan(),
        source: 'user',
        now: now,
      );
      await db.deloadDao.stop(going, at: now.add(const Duration(days: 2)));
      expect(await db.deloadDao.onAt(now.add(const Duration(days: 3))), isNull);
      expect(await db.deloadDao.all(), hasLength(1));

      final planned = await db.deloadDao.start(
        from: DateTime(2026, 11, 2),
        days: 7,
        plan: const DeloadPlan(),
        source: 'user',
        now: now,
      );
      await db.deloadDao.stop(planned, at: now);
      expect(await db.deloadDao.all(), hasLength(1));
    });

    test('er is er maar één tegelijk', () async {
      await db.deloadDao.start(
        from: now,
        days: 7,
        plan: const DeloadPlan(),
        source: 'user',
        now: now,
      );
      await db.deloadDao.start(
        from: now,
        days: 4,
        plan: const DeloadPlan(setsPercent: 30),
        source: 'coach',
        now: now,
      );

      final current = (await db.deloadDao.currentAt(now))!;
      expect(current.days, 4);
      expect(current.source, 'coach');
      expect(current.plan.setsPercent, 30);
    });
  });
}
