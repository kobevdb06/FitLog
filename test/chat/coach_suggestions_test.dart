import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/local_suggester.dart';
import 'package:fitlog/features/chat/domain/coach_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The questions an empty conversation offers: about you, today.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<String> questions(SuggestionFacts facts) => [
    for (final s in suggestQuestions(facts)) s.question,
  ];

  group('welke vragen', () {
    test('midden in een workout eerst over de workout', () {
      final found = suggestQuestions(
        const SuggestionFacts(
          workout: 'Push A',
          exercise: 'Bench Press',
          plannedToday: 'Push A',
          workouts: 20,
        ),
      );

      expect(found.take(4).map((s) => s.question), [
        'Is mijn gewicht goed voor Bench Press?',
        'Bench Press voelt zwaar vandaag, wat doe ik?',
        'Waarmee vervang ik Bench Press als het toestel bezet is?',
        'Hoeveel rust neem ik tussen mijn sets?',
      ]);
      expect(found.first.why, 'Nu bezig: Push A');
      // What is planned is the workout that is running.
      expect(
        found.map((s) => s.question),
        isNot(contains('Hoe pak ik Push A vandaag aan?')),
      );
    });

    test('anders wat gepland staat, het herstel, stilstand en de deload, '
        'elk met waarom', () {
      final found = suggestQuestions(
        const SuggestionFacts(
          plannedToday: 'Push A',
          recovering: 'quadriceps',
          recoveringHours: 14,
          stalled: 'Bench Press',
          stalledWeeks: 5,
          weeksWithoutBreak: 7,
          deloadDue: true,
          workouts: 30,
        ),
      );

      expect(
        [for (final s in found.take(4)) (s.question, s.why)],
        [
          ('Hoe pak ik Push A vandaag aan?', 'Gepland voor vandaag'),
          ('Mag ik vandaag quadriceps trainen?', 'Quadriceps nog 14 u herstel'),
          (
            'Hoe kom ik voorbij mijn stilstand op Bench Press?',
            'Staat 5 weken stil',
          ),
          ('Is het tijd voor een deload?', '7 weken zonder pauze'),
        ],
      );
    });

    test('niets gepland: wat train ik vandaag', () {
      expect(
        questions(const SuggestionFacts(workouts: 12)).first,
        'Wat train ik vandaag?',
      );
    });

    test('in een deload hoe je erin traint, niet of het tijd is', () {
      final found = questions(
        const SuggestionFacts(
          deloadDay: 2,
          deloadDays: 7,
          deloadDue: true,
          workouts: 30,
        ),
      );

      expect(found, contains('Hoe train ik in deze deload?'));
      expect(found, isNot(contains('Is het tijd voor een deload?')));
    });

    test('een record, lang weg, een korte nacht', () {
      final found = questions(
        const SuggestionFacts(
          record: 'Back Squat',
          daysSinceLast: 9,
          lastNight: Duration(hours: 5, minutes: 5),
          workouts: 40,
        ),
      );

      expect(
        found,
        containsAll([
          'Ik zette een record op Back Squat. Hoe ga ik verder?',
          'Hoe pak ik het weer op na 9 dagen?',
          'Ik sliep maar 5 u 05. Hoe zwaar train ik vandaag?',
        ]),
      );
    });

    test('wie net begint, om te beginnen - en altijd genoeg voor vier', () {
      final found = suggestQuestions(const SuggestionFacts());

      expect(found.length, greaterThanOrEqualTo(kSuggestionsShown));
      expect(
        found.map((s) => s.question),
        contains('Maak een schema voor drie dagen per week.'),
      );
    });

    test('de vraag over de app wisselt per dag', () {
      String app(int day) =>
          suggestQuestions(SuggestionFacts(dayOfYear: day, workouts: 10))
              .firstWhere((s) => s.reason == SuggestionReason.app)
              .question;

      expect(app(0), isNot(app(1)));
      expect(app(0), app(kAppQuestions.length));
    });
  });

  group('uit je logboek', () {
    late AppDatabase db;
    // Noon: last night has ended by then, whenever the test runs.
    final clock = DateTime.now();
    final now = DateTime(clock.year, clock.month, clock.day, 12);
    late LocalCoachSuggester suggester;

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      suggester = LocalCoachSuggester(db, clock: () => now);
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-bench',
              name: 'Bench Press',
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
    });

    tearDown(() => db.close());

    test('de workout van nu, en de oefening waar je zit', () async {
      final workout = await db.workoutsDao.startWorkout(
        name: 'Push A',
        defaultRestSeconds: 90,
      );
      await db.workoutsDao.addExercises(workout, [
        'ex-bench',
      ], defaultRestSeconds: 90);

      final facts = await suggester.facts();

      expect(facts.workout, 'Push A');
      expect(facts.exercise, 'Bench Press');
    });

    test('wat vandaag gepland staat', () async {
      final routine = await db.routinesDao.createRoutine(
        const RoutineDraft(name: 'Push A', exercises: []),
      );
      await db.routinesDao.setScheduledDays(
        routine,
        WeekdaySet.of([trainingWeekday(now)]),
      );

      expect((await suggester.facts()).plannedToday, 'Push A');
    });

    test('een record van deze week', () async {
      await db
          .into(db.personalRecordsTable)
          .insert(
            PersonalRecordsTableCompanion.insert(
              id: 'pr-1',
              exerciseId: 'ex-bench',
              recordType: 'weight',
              value: 100,
              achievedAt: now
                  .subtract(const Duration(days: 2))
                  .millisecondsSinceEpoch,
            ),
          );

      expect((await suggester.facts()).record, 'Bench Press');
    });

    test('een korte nacht die je zelf invulde, niet een van je horloge als '
        'de coach die niet mag zien', () async {
      final woke = DateTime(now.year, now.month, now.day, 7);
      await db.recoveryDao.setSleep(
        fellAsleepAt: woke.subtract(const Duration(hours: 5)),
        wokeAt: woke,
      );
      expect((await suggester.facts()).lastNight, const Duration(hours: 5));

      await db.customStatement(
        "UPDATE sleep_entries SET source = 'health_connect'",
      );
      expect((await suggester.facts()).lastNight, isNull);

      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(coachSeesHealth: Value(true)),
      );
      expect((await suggester.facts()).lastNight, const Duration(hours: 5));
    });

    test('een leeg logboek: om te beginnen', () async {
      final found = await suggester.suggest();

      expect(found.length, greaterThanOrEqualTo(kSuggestionsShown));
      expect(found.first.reason, SuggestionReason.start);
    });
  });
}
