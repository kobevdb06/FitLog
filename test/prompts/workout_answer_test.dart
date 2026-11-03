import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/prompts/data/moment_answerer.dart';
import 'package:fitlog/features/prompts/data/workout_facts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// Na je workout: the coach is asked the user's prompt once, with the
/// workout as FitLog worked it out, and the answer stays with the workout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late List<String> sent;

  AiClient client(String apiKey, CoachProvider provider) => AiClient(
    apiKey: apiKey,
    provider: provider,
    client: MockClient((request) async {
      sent.add(request.body);
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Bankdrukken ging vooruit: 82,5 tegen 80.'},
                ],
              },
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 900,
            'candidatesTokenCount': 30,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  /// A finished session of bench presses on [day]: each set with its weight,
  /// reps and whether it was ticked off.
  Future<String> session(
    DateTime day,
    List<({double kg, int reps, bool done})> sets,
  ) async {
    final id = await db.workoutsDao.startWorkout(
      name: 'Push',
      defaultRestSeconds: 90,
    );
    final exercise = (await db.workoutsDao.addExercises(id, [
      'ex-bench',
    ], defaultRestSeconds: 90)).single;
    final first = (await db.workoutsDao.getWorkoutDetail(id))!
        .exercises
        .single
        .sets
        .single;
    final ids = [
      first.id,
      for (var i = 1; i < sets.length; i++)
        await db.workoutsDao.addSet(exercise),
    ];
    for (var i = 0; i < sets.length; i++) {
      await db.workoutsDao.updateSet(
        ids[i],
        weightKg: Value(sets[i].kg),
        reps: Value(sets[i].reps),
        isCompleted: Value(sets[i].done),
      );
    }
    await db.workoutsDao.finishWorkout(id, discardPending: false);
    await db.customStatement(
      'UPDATE workouts SET started_at = ?, avg_heart_rate = 131, '
      'max_heart_rate = 168 WHERE id = ?',
      [day.millisecondsSinceEpoch, id],
    );
    return id;
  }

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bankdrukken',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() => db.close());

  test('de feiten: elke set met haar status, en de vorige keer is die van '
      'ervoor, niet de nieuwste', () async {
    await session(DateTime(2026, 9, 1), [(kg: 80, reps: 6, done: true)]);
    final id = await session(DateTime(2026, 9, 8), [
      (kg: 82.5, reps: 6, done: true),
      (kg: 82.5, reps: 5, done: false),
    ]);
    await session(DateTime(2026, 9, 15), [(kg: 90, reps: 6, done: true)]);

    final facts = (await buildWorkoutFacts(db, id, health: false))!;
    final bench = (facts['exercises']! as List).single as Map;

    expect(facts['date'], '2026-09-08');
    expect(
      [for (final set in bench['sets'] as List) set['status']],
      ['done', 'open'],
    );
    expect(bench['last_time'], {
      'date': '2026-09-01',
      'sets': [
        {'weight_kg': 80.0, 'reps': 6},
      ],
    });
    // The watch is not the coach's to see unless that is shared.
    expect(facts.containsKey('heart_rate'), isFalse);
    expect((await buildWorkoutFacts(db, id, health: true))!['heart_rate'], {
      'average': 131,
      'highest': 168,
    });
  });

  test('zonder sleutel wordt er niets gevraagd en niets bewaard', () async {
    final id = await session(DateTime(2026, 9, 8), [
      (kg: 82.5, reps: 6, done: true),
    ]);

    expect(
      await MomentAnswerer(
        db,
        clientFactory: client,
      ).answer(CoachMoment.workout, id),
      isNull,
    );
    expect(sent, isEmpty);
    expect(await db.coachPromptsDao.answerFor(id), isNull);
  });

  group('met een sleutel', () {
    setUp(() => db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg'));

    test('de woorden van de gebruiker gaan mee onder de vaste regels, en het '
        'antwoord blijft bij de workout en telt mee', () async {
      await db.coachPromptsDao.savePrompt(
        moment: CoachMoment.workout,
        enabled: true,
        prompt: 'Wees kritisch over mijn bankdrukken.',
      );
      final id = await session(DateTime(2026, 9, 8), [
        (kg: 82.5, reps: 6, done: true),
      ]);

      final row = await MomentAnswerer(
        db,
        clientFactory: client,
      ).answer(CoachMoment.workout, id, now: DateTime(2026, 9, 8, 19));

      expect(sent, hasLength(1));
      expect(sent.single, contains('Wees kritisch over mijn bankdrukken.'));
      expect(sent.single, contains('verzin geen cijfers'));
      expect(sent.single, contains('Bankdrukken'));
      expect(row!.coachText, 'Bankdrukken ging vooruit: 82,5 tegen 80.');
      expect(row.prompt, 'Wees kritisch over mijn bankdrukken.');
      expect((await db.chatDao.usageSince(DateTime(2026, 9, 8))).requests, 1);
    });

    test(
      'aan de daglimiet wordt er niets gevraagd, en staat er waarom',
      () async {
        await db.settingsDao.updateSettings(
          const AppSettingsTableCompanion(coachDailyLimit: Value(1)),
        );
        final earlier = await session(DateTime(2026, 9, 8, 8), [
          (kg: 80, reps: 6, done: true),
        ]);
        final id = await session(DateTime(2026, 9, 8, 18), [
          (kg: 82.5, reps: 6, done: true),
        ]);
        final answerer = MomentAnswerer(db, clientFactory: client);
        await answerer.answer(
          CoachMoment.workout,
          earlier,
          now: DateTime(2026, 9, 8, 12),
        );

        final row = await answerer.answer(
          CoachMoment.workout,
          id,
          now: DateTime(2026, 9, 8, 19),
        );

        expect(sent, hasLength(1));
        expect(row!.coachText, isNull);
        expect(row.coachError, contains('daglimiet'));
      },
    );

    test('het geheugen gaat mee, tenzij het uit staat', () async {
      await db.coachNotesDao.add('Knie: geen diepe squats');
      final id = await session(DateTime(2026, 9, 8), [
        (kg: 82.5, reps: 6, done: true),
      ]);
      final answerer = MomentAnswerer(db, clientFactory: client);

      await answerer.answer(CoachMoment.workout, id);
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(coachMemory: Value(false)),
      );
      await answerer.answer(CoachMoment.workout, id);

      expect(sent.first, contains('Knie: geen diepe squats'));
      expect(sent.last, isNot(contains('Knie')));
    });

    test('een verwijderde workout neemt haar antwoord mee', () async {
      final id = await session(DateTime(2026, 9, 8), [
        (kg: 82.5, reps: 6, done: true),
      ]);
      await MomentAnswerer(
        db,
        clientFactory: client,
      ).answer(CoachMoment.workout, id);

      await db.workoutsDao.deleteWorkoutCompletely(id);

      expect(await db.coachPromptsDao.answerFor(id), isNull);
    });
  });
}
