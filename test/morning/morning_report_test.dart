import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/domain/coach_budget.dart';
import 'package:fitlog/features/health/data/health_importer.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:fitlog/features/morning/data/morning_reporter.dart';
import 'package:fitlog/features/morning/data/morning_run.dart';
import 'package:fitlog/features/morning/domain/morning_facts.dart';
import 'package:fitlog/features/readiness/domain/training_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The morning report: the facts the app works out, and the words the coach
/// puts around them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final morning = DateTime(2026, 3, 3, 7);

  RecoveryEstimate estimate(
    String muscle, {
    required int hoursAgo,
    int hours = 72,
  }) => RecoveryEstimate(
    muscle: muscle,
    workoutId: 'w',
    trainedAt: morning.subtract(Duration(hours: hoursAgo)),
    recovery: Duration(hours: hours),
    loadRatio: 1,
    provisional: false,
  );

  SleepEntryRow night({
    required DateTime asleep,
    required DateTime woke,
    String? source,
    int? deep,
    int? rem,
  }) => SleepEntryRow(
    id: 'n',
    fellAsleepAt: asleep.millisecondsSinceEpoch,
    wokeAt: woke.millisecondsSinceEpoch,
    deepMinutes: deep,
    remMinutes: rem,
    source: source,
  );

  group('de feiten', () {
    test('de nacht van vanochtend, met zijn score', () {
      final facts = buildMorningFacts(
        now: morning,
        nights: [
          night(
            asleep: DateTime(2026, 3, 1, 23),
            woke: DateTime(2026, 3, 2, 7),
          ),
          night(
            asleep: DateTime(2026, 3, 2, 23),
            woke: DateTime(2026, 3, 3, 6),
            source: 'com.example.watch',
          ),
        ],
        vitals: const [],
        estimates: const [],
      );

      expect(facts.night!.length, const Duration(hours: 7));
      expect(facts.night!.fromWatch, isTrue);
      expect(facts.score, 75);
    });

    test('zonder nacht van vanochtend: geen nacht en geen score', () {
      final facts = buildMorningFacts(
        now: morning,
        nights: [
          night(
            asleep: DateTime(2026, 3, 1, 23),
            woke: DateTime(2026, 3, 2, 7),
          ),
        ],
        vitals: const [],
        estimates: const [],
      );

      expect(facts.night, isNull);
      expect(facts.score, isNull);
    });

    test('wat nog herstelt, het langste eerst, en wat klaar is', () {
      final facts = buildMorningFacts(
        now: morning,
        nights: const [],
        vitals: const [],
        estimates: [
          estimate('biceps', hoursAgo: 30, hours: 36),
          estimate('quadriceps', hoursAgo: 20),
          estimate('borst', hoursAgo: 70, hours: 60),
          // Lang geleden: niet meer het vermelden waard.
          estimate('kuiten', hoursAgo: 200, hours: 36),
        ],
      );

      expect(facts.recovering.map((m) => m.muscle), ['quadriceps', 'biceps']);
      expect(facts.recovering.first.left, const Duration(hours: 52));
      expect(facts.ready, ['borst']);
    });

    test('en ze overleven de weg naar de database en terug', () {
      final facts = MorningFacts(
        day: DateTime(2026, 3, 3),
        night: MorningNight(
          fellAsleepAt: DateTime(2026, 3, 2, 23, 40),
          wokeAt: DateTime(2026, 3, 3, 6, 52),
          fromWatch: true,
          deepMinutes: 80,
        ),
        score: 78,
        hrvDrop: 0.14,
        recovering: const [
          MuscleLeft(muscle: 'quadriceps', left: Duration(hours: 20)),
        ],
        ready: const ['borst'],
      );

      final back = MorningFacts.fromJson(
        jsonDecode(jsonEncode(facts.toJson())) as Map<String, Object?>,
      );

      expect(back.night!.wokeAt, facts.night!.wokeAt);
      expect(back.night!.deepMinutes, 80);
      expect(back.night!.remMinutes, isNull);
      expect(back.score, 78);
      expect(back.hrvDrop, 0.14);
      expect(back.restingHrRise, isNull);
      expect(back.recovering.single.left, const Duration(hours: 20));
      expect(back.ready, ['borst']);
    });

    test('de check overleeft de weg naar de database en terug', () {
      final facts = MorningFacts(
        day: DateTime(2026, 3, 3),
        check: const MorningCheck(
          session: 'Legs',
          verdict: CheckVerdict.wait,
          reasons: ['quadriceps nog 14 u', '5 u 10 geslapen, score 58'],
          instead: 'Push',
        ),
      );

      final back = MorningFacts.fromJson(
        jsonDecode(jsonEncode(facts.toJson())) as Map<String, Object?>,
      ).check!;
      expect(back.session, 'Legs');
      expect(back.verdict, CheckVerdict.wait);
      expect(back.reasons, hasLength(2));
      expect(back.instead, 'Push');
      expect(back.noneReady, isFalse);
      expect(
        MorningFacts.fromJson(
          jsonDecode(jsonEncode(MorningFacts(day: facts.day).toJson()))
              as Map<String, Object?>,
        ).check,
        isNull,
        reason: 'a report from before the check has none',
      );

      final coach = facts.forCoach()['check_voor_training']! as Map;
      expect(coach['sessie'], 'Legs');
      expect(coach['oordeel'], 'beter wachten');
      expect(coach['in_de_plaats'], 'Push');
    });

    test('de coach krijgt ze leesbaar', () {
      final coach = MorningFacts(
        day: DateTime(2026, 3, 3),
        night: MorningNight(
          fellAsleepAt: DateTime(2026, 3, 2, 23, 40),
          wokeAt: DateTime(2026, 3, 3, 6, 52),
          fromWatch: false,
        ),
        score: 78,
        hrvDrop: 0.14,
        recovering: const [
          MuscleLeft(
            muscle: 'quadriceps',
            left: Duration(hours: 19, minutes: 10),
          ),
        ],
      ).forCoach();

      expect(coach['datum'], '2026-03-03');
      expect((coach['nacht']! as Map)['in_slaap'], '23:40');
      expect(coach['hrv_tegenover_gewoon_pct'], -14);
      expect(((coach['herstellen_nog']! as List).single as Map)['uren'], 20);
    });
  });

  group('in gewone zinnen', () {
    test('de nacht, het hart en de spieren', () {
      final text = morningSummary(
        MorningFacts(
          day: DateTime(2026, 3, 3),
          night: MorningNight(
            fellAsleepAt: DateTime(2026, 3, 2, 23),
            wokeAt: DateTime(2026, 3, 3, 6, 30),
            fromWatch: true,
          ),
          score: 81,
          hrvDrop: 0.2,
          restingHrRise: 1,
          recovering: const [
            MuscleLeft(muscle: 'quadriceps', left: Duration(hours: 20)),
          ],
          ready: const ['borst', 'triceps'],
        ),
      );

      expect(text, contains('Je sliep 7 u 30, slaapscore 81.'));
      expect(text, contains('Je HRV ligt 20% onder je gewone.'));
      expect(text, isNot(contains('rusthartslag')));
      expect(text, contains('Nog in herstel: quadriceps (nog 20 u).'));
      expect(text, contains('Klaar: borst, triceps.'));
    });

    test('de check voor je training, in één zin', () {
      String said(MorningCheck check) =>
          morningSummary(MorningFacts(day: DateTime(2026, 3, 3), check: check));
      const reasons = ['quadriceps nog 14 u', '5 u 10 geslapen, score 58'];

      expect(
        said(const MorningCheck(session: 'Legs', verdict: CheckVerdict.ready)),
        contains('Voor Legs: klaar.'),
      );
      expect(
        said(
          const MorningCheck(
            session: 'Legs',
            verdict: CheckVerdict.note,
            reasons: ['quadriceps nog 14 u'],
          ),
        ),
        contains('Voor Legs: één sein, quadriceps nog 14 u. Je kan gaan.'),
      );
      expect(
        said(
          const MorningCheck(
            session: 'Legs',
            verdict: CheckVerdict.wait,
            reasons: reasons,
            instead: 'Push',
          ),
        ),
        contains(
          'Legs kan beter wachten: quadriceps nog 14 u, 5 u 10 geslapen, '
          'score 58. Doe vandaag Push.',
        ),
      );
      expect(
        said(
          const MorningCheck(
            session: 'Legs',
            verdict: CheckVerdict.wait,
            reasons: reasons,
            noneReady: true,
          ),
        ),
        contains('Geen sessie van deze week is vandaag klaar'),
      );
    });

    test('zonder nacht en zonder training', () {
      final text = morningSummary(MorningFacts(day: DateTime(2026, 3, 3)));

      expect(text, contains('geen nacht bekend'));
      expect(text, contains('Geen spiergroep in herstel.'));
    });
  });

  group('opstellen en bewaren', () {
    late AppDatabase db;

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      await db.recoveryDao.setSleep(
        fellAsleepAt: DateTime(2026, 3, 2, 23),
        wokeAt: DateTime(2026, 3, 3, 6),
      );
    });
    tearDown(() => db.close());

    Future<void> withKey({int? limit}) => db.settingsDao.updateSettings(
      AppSettingsTableCompanion(
        anthropicApiKey: const Value('AIzaTestKey'),
        coachDailyLimit: limit == null ? const Value.absent() : Value(limit),
      ),
    );

    /// A Gemini that answers [text], and counts how often it was asked.
    ({ReportClientFactory factory, List<Map<String, Object?>> sent}) gemini(
      String text,
    ) {
      final sent = <Map<String, Object?>>[];
      return (
        sent: sent,
        factory: (key, provider) => AiClient(
          apiKey: key,
          provider: provider,
          client: MockClient((request) async {
            sent.add(jsonDecode(request.body) as Map<String, Object?>);
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'role': 'model',
                      'parts': [
                        {'text': text},
                      ],
                    },
                  },
                ],
                'usageMetadata': {
                  'promptTokenCount': 300,
                  'candidatesTokenCount': 40,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
    }

    /// Legs, starred: what Vandaag offers without a schedule.
    Future<void> legs() async {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-squat',
              name: 'Squat',
              primaryMuscle: 'quadriceps',
              category: 'barbell',
              createdAt: 0,
            ),
          );
      final id = await db.routinesDao.createRoutine(
        RoutineDraft(
          name: 'Legs',
          exercises: [
            RoutineExerciseDraft(
              exerciseId: 'ex-squat',
              sets: [
                for (var i = 0; i < 4; i++)
                  const RoutineSetDraft(targetWeightKg: 100, targetReps: 5),
              ],
            ),
          ],
        ),
      );
      await db.routinesDao.setFavourite(id, favourite: true);
    }

    test(
      'met de check voor de sessie van vandaag, ook voor de coach',
      () async {
        await legs();
        await db.recoveryDao.clearSleep(DateTime(2026, 3, 3));
        await db.recoveryDao.setSleep(
          fellAsleepAt: DateTime(2026, 3, 3, 1),
          wokeAt: DateTime(2026, 3, 3, 6),
        );
        await withKey();
        final coach = gemini('Korte nacht. Legs kan, rustig aan.');

        final report = await MorningReporter(
          db,
          clientFactory: coach.factory,
        ).write(now: morning);

        final check = report.facts.check!;
        expect(check.session, 'Legs');
        expect(check.verdict, CheckVerdict.note);
        expect(
          morningSummary(report.facts),
          contains('Voor Legs: één sein, 5 u geslapen, score'),
        );
        expect(jsonEncode(coach.sent.single), contains('check_voor_training'));
        final row = (await db.reportsDao.reportFor(morning))!;
        expect(
          MorningReport.fromRow(row).facts.check?.verdict,
          CheckVerdict.note,
        );
      },
    );

    test('zonder coach: de app zegt het zelf, en er gaat niets weg', () async {
      final coach = gemini('Onmogelijk');

      final report = await MorningReporter(
        db,
        clientFactory: coach.factory,
      ).write(now: morning);

      expect(coach.sent, isEmpty);
      expect(report.coachText, isNull);
      expect(report.text, contains('Je sliep 7 u, slaapscore 75.'));
      final row = (await db.reportsDao.reportFor(morning))!;
      expect(row.requests, isNull);
    });

    test('met coach: zijn woorden, en ze tellen mee in de dagbalk', () async {
      await withKey();
      final coach = gemini('Korte nacht, maar je benen zijn klaar.');

      final report = await MorningReporter(
        db,
        clientFactory: coach.factory,
      ).write(now: morning);

      expect(report.text, 'Korte nacht, maar je benen zijn klaar.');
      expect(coach.sent, hasLength(1));
      // Geen gereedschap: alles wat hij mag zeggen, zit in het bericht.
      expect(coach.sent.single.containsKey('tools'), isFalse);
      final usage = await db.chatDao.usageSince(
        coachDayStart(morning, CoachProvider.gemini),
      );
      expect(usage.requests, 1);
      expect(usage.inputTokens, 300);
    });

    group('een nacht van het horloge', () {
      setUp(() async {
        await db.recoveryDao.clearSleep(DateTime(2026, 3, 3));
        await HealthImporter(db).apply(
          HealthSnapshot(
            nights: [
              ImportedNight(
                fellAsleepAt: DateTime(2026, 3, 2, 22, 30),
                wokeAt: DateTime(2026, 3, 3, 6, 30),
                source: 'com.example.watch',
              ),
            ],
          ),
        );
        await withKey();
      });

      test(
        'gaat niet naar de coach zolang Health Connect niet gedeeld is',
        () async {
          final coach = gemini('Onmogelijk');

          final report = await MorningReporter(
            db,
            clientFactory: coach.factory,
          ).write(now: morning);

          expect(coach.sent, isEmpty);
          expect(report.coachText, isNull);
          expect(report.coachError, contains('Health Connect'));
          // The report itself is whole: it is the coach that is not told.
          expect(report.facts.night!.fromWatch, isTrue);
          expect(report.text, contains('Je sliep 8 u'));
        },
      );

      test('en gedeeld wel', () async {
        await db.settingsDao.updateSettings(
          const AppSettingsTableCompanion(coachSeesHealth: Value(true)),
        );
        final coach = gemini('Lange nacht.');

        final report = await MorningReporter(
          db,
          clientFactory: coach.factory,
        ).write(now: morning);

        expect(coach.sent, hasLength(1));
        expect(jsonEncode(coach.sent.single), contains('22:30'));
        expect(report.coachText, 'Lange nacht.');
      });
    });

    test('aan de daglimiet vraagt hij niets en zegt hij waarom', () async {
      await withKey(limit: 1);
      final coach = gemini('Eerste');
      await MorningReporter(
        db,
        clientFactory: coach.factory,
      ).write(now: morning);

      final second = await MorningReporter(
        db,
        clientFactory: coach.factory,
      ).write(now: morning.add(const Duration(minutes: 5)));

      expect(coach.sent, hasLength(1));
      expect(second.coachText, isNull);
      expect(second.coachError, contains('daglimiet'));
      // Opnieuw opstellen vervangt het rapport van die dag.
      expect(await db.select(db.morningReportsTable).get(), hasLength(1));
    });

    test('een coach die faalt, laat het rapport niet vallen', () async {
      await withKey();
      final report = await MorningReporter(
        db,
        clientFactory: (key, provider) => AiClient(
          apiKey: key,
          provider: provider,
          client: MockClient((_) async => http.Response('{}', 500)),
        ),
      ).write(now: morning);

      expect(report.coachText, isNull);
      expect(report.coachError, isNotNull);
      expect(report.text, contains('slaapscore 75'));
    });

    test('de ochtend haalt eerst op wat het horloge had', () async {
      await db.recoveryDao.clearSleep(DateTime(2026, 3, 3));
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
      final source = _Watch(
        HealthSnapshot(
          nights: [
            ImportedNight(
              fellAsleepAt: DateTime(2026, 3, 2, 22, 30),
              wokeAt: DateTime(2026, 3, 3, 6, 30),
              source: 'com.example.watch',
            ),
          ],
        ),
      );

      final report = await runMorning(db: db, source: source, now: morning);

      expect(source.reads, 1);
      expect(report.facts.night!.fromWatch, isTrue);
      expect(report.facts.score, 100);
      expect(report.importError, isNull);
    });

    test('en lukt dat niet, dan staat erbij waarom', () async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );

      final report = await runMorning(
        db: db,
        source: _Watch(const HealthSnapshot(), fails: true),
        now: morning,
      );

      expect(report.importError, contains('Health Connect'));
      // Gemaakt uit wat er al was.
      expect(report.facts.score, 75);
      expect((await db.reportsDao.reportFor(morning))!.importError, isNotNull);
    });
  });
}

class _Watch implements HealthSource {
  _Watch(this.snapshot, {this.fails = false});

  final HealthSnapshot snapshot;
  final bool fails;
  int reads = 0;

  @override
  Future<HealthSnapshot> read({
    required DateTime from,
    required DateTime to,
  }) async {
    reads++;
    if (fails) throw StateError('geen toegang op de achtergrond');
    return snapshot;
  }

  @override
  Future<HealthAvailability> availability() async =>
      HealthAvailability.available;

  @override
  Future<void> openInstall() async {}

  @override
  Future<bool> hasAccess() async => true;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<void> revokeAccess() async {}

  @override
  Future<bool> requestWriteAccess() async => true;

  @override
  Future<String?> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async => null;

  @override
  Future<void> deleteWorkout(String id) async {}

  @override
  Future<List<ImportedReading>> heartRate({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<List<ImportedReading>> oxygenSaturation({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<int?> steps({required DateTime from, required DateTime to}) async =>
      null;

  @override
  Future<List<String>> missingAccess() async => const [];

  @override
  Future<bool> requestBackgroundAccess() async => true;
}
