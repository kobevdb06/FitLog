import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/health/data/health_importer.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// What the coach can find out about you when it asks.
///
/// Every one of these is data leaving the device, so the shape of it is worth
/// pinning down: what goes, how much of it, and what the user is told was
/// looked at.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CoachTools tools;

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    tools = CoachTools(db);

    for (final (id, name, muscle) in [
      ('ex-bench', 'Bench Press', 'borst'),
      ('ex-squat', 'Back Squat', 'quadriceps'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
              primaryMuscle: muscle,
              equipment: const Value('barbell'),
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  /// One finished session with one set.
  Future<void> logSet({
    required String exerciseId,
    required DateTime on,
    double weight = 80,
    int reps = 5,
  }) async {
    final at = on.millisecondsSinceEpoch;
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-$at',
            name: 'Push',
            startedAt: at,
            endedAt: Value(at + 3600000),
            durationSeconds: const Value(3600),
            totalVolumeKg: Value(weight * reps),
            totalSets: const Value(1),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-$at',
            workoutId: 'w-$at',
            exerciseId: exerciseId,
            sortOrder: 0,
          ),
        );
    await db
        .into(db.workoutSetsTable)
        .insert(
          WorkoutSetsTableCompanion.insert(
            id: 'ws-$at',
            workoutExerciseId: 'we-$at',
            sortOrder: 0,
            setType: const Value('normal'),
            weightKg: Value(weight),
            reps: Value(reps),
            isCompleted: const Value(true),
            completedAt: Value(at),
          ),
        );
  }

  group('de catalogus', () {
    test('zoeken geeft de oefening met haar spier en materiaal', () async {
      final lookup = await tools.run('search_exercises', {'query': 'bench'});

      final json = decode(lookup);
      final found = (json['exercises']! as List).single as Map<String, Object?>;
      expect(found['name'], 'Bench Press');
      expect(found['primary_muscle'], 'borst');
      expect(found['equipment'], 'barbell');
      expect(found['category'], 'Barbell');
      expect(lookup.summary, 'oefeningen die passen bij "bench"');
    });

    test('en filteren op spiergroep werkt ook', () async {
      final lookup = await tools.run('search_exercises', {'muscle': 'borst'});

      expect((decode(lookup)['exercises']! as List), hasLength(1));
      expect(lookup.summary, 'oefeningen voor borst');
    });

    test('een limiet boven het plafond wordt teruggebracht', () async {
      final lookup = await tools.run('search_exercises', {'limit': 5000});

      expect(decode(lookup)['shown'], lessThanOrEqualTo(kCoachRowCap));
    });
  });

  group('je sessies', () {
    test('komen nieuwste eerst, met wat erin zat', () async {
      await logSet(exerciseId: 'ex-bench', on: DateTime(2026, 2, 20));
      await logSet(exerciseId: 'ex-squat', on: DateTime(2026, 2, 27));

      final lookup = await tools.run('recent_workouts', {'limit': 5});

      final workouts = decode(lookup)['workouts']! as List;
      expect(workouts, hasLength(2));
      final newest = workouts.first as Map<String, Object?>;
      expect(newest['date'], '2026-02-27');
      expect(newest['minutes'], 60);
      expect('${newest['exercises']}', contains('Back Squat'));
      expect(lookup.summary, 'je laatste 2 sessies');
    });

    test('met wat je erbij schreef', () async {
      final on = DateTime(2026, 2, 20);
      await logSet(exerciseId: 'ex-bench', on: on);
      final at = on.millisecondsSinceEpoch;
      await db.customStatement(
        "UPDATE workouts SET notes = 'Slecht geslapen' WHERE id = 'w-$at'",
      );
      await db.customStatement(
        "UPDATE workout_exercises SET notes = 'Smalle grip' "
        "WHERE id = 'we-$at'",
      );

      final lookup = await tools.run('recent_workouts', const {});

      final workout =
          (decode(lookup)['workouts']! as List).single as Map<String, Object?>;
      expect(workout['notes'], 'Slecht geslapen');
      final exercise = (workout['exercises']! as List).single as Map;
      expect(exercise['notes'], 'Smalle grip');
    });

    test('en een dag gaat mee zonder het uur', () async {
      await logSet(exerciseId: 'ex-bench', on: DateTime(2026, 2, 20, 19, 45));

      final lookup = await tools.run('recent_workouts', const {});

      expect(lookup.json, contains('2026-02-20'));
      expect(lookup.json, isNot(contains('19:45')));
    });
  });

  group('één oefening', () {
    test('geeft set per set terug wat je deed', () async {
      await logSet(exerciseId: 'ex-bench', on: DateTime(2026, 2, 20));

      final lookup = await tools.run('exercise_history', {'exercise': 'bench'});

      final json = decode(lookup);
      expect(json['exercise'], 'Bench Press');
      final session =
          (json['sessions']! as List).single as Map<String, Object?>;
      expect(session['date'], '2026-02-20');
      final set = (session['sets']! as List).single as Map<String, Object?>;
      expect(set['weight_kg'], 80);
      expect(set['reps'], 5);
      expect(lookup.summary, 'je laatste 1 keer Bench Press');
    });

    test('met je RPE, de kant, je notitie en een PR-poging', () async {
      final on = DateTime(2026, 2, 20);
      await logSet(exerciseId: 'ex-bench', on: on, weight: 100, reps: 3);
      final at = on.millisecondsSinceEpoch;
      await db.customStatement(
        "UPDATE workout_sets SET rpe = 9.5, side = 'left' WHERE id = 'ws-$at'",
      );
      await db.customStatement(
        "UPDATE workout_exercises SET notes = 'Schouder trok wat', "
        "is_pr_attempt = 1, pr_target_weight_kg = 100, pr_result = 'success' "
        "WHERE id = 'we-$at'",
      );

      final lookup = await tools.run('exercise_history', {'exercise': 'bench'});

      final session =
          (decode(lookup)['sessions']! as List).single as Map<String, Object?>;
      expect(session['notes'], 'Schouder trok wat');
      expect(session['pr_attempt'], {'target_kg': 100, 'result': 'success'});
      final set = (session['sets']! as List).single as Map<String, Object?>;
      expect(set['rpe'], 9.5);
      expect(set['side'], 'left');
    });

    test('twee keer op één dag zijn twee keer', () async {
      await logSet(exerciseId: 'ex-bench', on: DateTime(2026, 2, 20, 9));
      await logSet(exerciseId: 'ex-bench', on: DateTime(2026, 2, 20, 18));

      final lookup = await tools.run('exercise_history', {'exercise': 'bench'});

      expect(decode(lookup)['sessions'], hasLength(2));
      // Zonder RPE of kant komen die er ook niet als leeg bij.
      expect(lookup.json, isNot(contains('rpe')));
      expect(lookup.json, isNot(contains('side')));
    });

    test('een oefening die niet bestaat is een antwoord, geen fout', () async {
      final lookup = await tools.run('exercise_history', {
        'exercise': 'zweefduik',
      });

      expect(decode(lookup)['found'], isFalse);
      expect(lookup.summary, contains('niet bestaat'));
    });

    test('en zonder naam vraagt het erom', () async {
      final lookup = await tools.run('exercise_history', const {});

      expect(decode(lookup)['error'], isNotNull);
    });
  });

  group('de rest', () {
    test('routines komen met hun oefeningen en hun dagen', () async {
      await db
          .into(db.routinesTable)
          .insert(
            RoutinesTableCompanion.insert(
              id: 'r-1',
              name: 'Push',
              sortOrder: 0,
              scheduledDays: const Value(5), // maandag en woensdag
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.routineExercisesTable)
          .insert(
            RoutineExercisesTableCompanion.insert(
              id: 're-1',
              routineId: 'r-1',
              exerciseId: 'ex-bench',
              sortOrder: 0,
            ),
          );

      final lookup = await tools.run('routines', const {});

      final routine =
          (decode(lookup)['routines']! as List).single as Map<String, Object?>;
      expect(routine['name'], 'Push');
      expect(routine['scheduled_days'], ['ma', 'wo']);
      expect('${routine['exercises']}', contains('Bench Press'));
      expect(lookup.summary, 'je routines');
    });

    test('weekcijfers tellen sets per spiergroep', () async {
      await logSet(
        exerciseId: 'ex-bench',
        on: DateTime.now().subtract(const Duration(days: 3)),
      );

      final lookup = await tools.run('weekly_volume', {'weeks': 4});

      final json = decode(lookup);
      expect(json['over_weeks'], 4);
      expect((json['sets_per_muscle']! as Map)['borst'], 1);
      expect(lookup.summary, 'je cijfers van de laatste 4 weken');
    });

    test('metingen gaan metrisch de deur uit', () async {
      await db.recordsDao.addMeasurement(
        type: MeasurementType.weight,
        value: 82.5,
        measuredAt: DateTime(2026, 2, 1),
      );

      final lookup = await tools.run('body_measurements', {'type': 'weight'});

      final json = decode(lookup);
      expect(json['unit'], contains('kg'));
      final row =
          (json['measurements']! as List).single as Map<String, Object?>;
      expect(row['value'], 82.5);
      expect(row['date'], '2026-02-01');
      expect(lookup.summary, 'je metingen van weight');
    });

    test('records noemen de oefening erbij', () async {
      await db
          .into(db.personalRecordsTable)
          .insert(
            PersonalRecordsTableCompanion.insert(
              id: 'pr-1',
              exerciseId: 'ex-bench',
              recordType: 'max_weight',
              value: 100,
              achievedAt: DateTime(2026, 1, 15).millisecondsSinceEpoch,
            ),
          );

      final lookup = await tools.run('personal_records', const {});

      final record =
          (decode(lookup)['records']! as List).single as Map<String, Object?>;
      expect(record['exercise'], 'Bench Press');
      expect(record['value'], 100);
      expect(lookup.summary, 'je persoonlijke records');
    });
  });

  group('wat je horloge en je herstel zeggen', () {
    test('nachten, met hun fasen, score en waar ze vandaan kwamen', () async {
      await db.recoveryDao.setSleep(
        fellAsleepAt: DateTime(2026, 3, 1, 23, 30),
        wokeAt: DateTime(2026, 3, 2, 7, 30),
      );
      await HealthImporter(db).apply(
        HealthSnapshot(
          nights: [
            ImportedNight(
              fellAsleepAt: DateTime(2026, 3, 2, 23),
              wokeAt: DateTime(2026, 3, 3, 5),
              source: 'com.example.watch',
              deepMinutes: 60,
              remMinutes: 60,
            ),
          ],
        ),
      );

      final lookup = await tools.run('sleep', const {});
      final nights = (decode(lookup)['nights']! as List)
          .cast<Map<String, Object?>>();

      expect(nights, hasLength(2));
      // De nieuwste eerst.
      expect(nights.first['morning'], '2026-03-03');
      expect(nights.first['asleep'], '23:00');
      expect(nights.first['minutes'], 360);
      expect(nights.first['deep_minutes'], 60);
      expect(nights.first['from'], 'Health Connect');
      expect(nights.first['score'], isA<int>());
      expect(nights.last['from'], 'zelf ingevuld');
      expect(nights.last.containsKey('deep_minutes'), isFalse);
      expect(nights.last['score'], 100);
      expect(lookup.summary, 'je laatste 2 nachten');
    });

    test('HRV en rusthartslag per dag, met het gewone erbij', () async {
      final today = DateTime.now();
      await HealthImporter(db).apply(
        HealthSnapshot(
          hrv: [
            for (var d = 1; d <= 3; d++)
              ImportedReading(
                at: DateTime(today.year, today.month, today.day - d, 3),
                value: 40.0 + d,
              ),
          ],
          restingHr: [
            ImportedReading(
              at: DateTime(today.year, today.month, today.day - 1, 8),
              value: 54,
            ),
          ],
        ),
      );

      final lookup = await tools.run('heart_readings', const {});
      final json = decode(lookup);
      final days = (json['days']! as List).cast<Map<String, Object?>>();

      expect(days, hasLength(3));
      expect(days.first['hrv_ms'], 41);
      expect(days.first['resting_hr'], 54);
      expect((json['usual']! as Map)['hrv_ms'], 42);
      expect(lookup.summary, 'je HRV en rusthartslag');
    });

    test('lopen en ritten, met hun duur', () async {
      await HealthImporter(db).apply(
        HealthSnapshot(
          cardio: [
            ImportedCardio(
              id: 'r1',
              start: DateTime(2026, 3, 4, 18),
              end: DateTime(2026, 3, 4, 18, 42),
              kind: CardioKind.running,
              source: 'com.strava',
            ),
          ],
        ),
      );

      final lookup = await tools.run('cardio_sessions', const {});
      final session = (decode(lookup)['sessions']! as List).single as Map;

      expect(session['kind'], 'loop');
      expect(session['minutes'], 42);
      expect(session['date'], '2026-03-04');
    });

    test('het herstel per spiergroep, met wat het verschoof', () async {
      await logSet(
        exerciseId: 'ex-squat',
        on: DateTime.now().subtract(const Duration(hours: 20)),
        weight: 100,
      );
      await db.recoveryDao.setSoreness(
        'quadriceps',
        SorenessLevel.sore,
        at: DateTime.now(),
      );

      final lookup = await tools.run('recovery', const {});
      final muscle = (decode(lookup)['muscles']! as List).single as Map;

      expect(muscle['muscle'], 'quadriceps');
      expect(muscle['ready'], isFalse);
      expect(muscle['hours_left'], greaterThan(0));
      expect((muscle['user_said']! as Map)['feels'], 'Pijnlijk');
      expect(lookup.summary, 'je herstel per spiergroep');
    });

    test('glazen per dag', () async {
      await db.recoveryDao.setDrinks(DateTime(2026, 3, 1), 4);

      final lookup = await tools.run('drinks', const {});
      final day = (decode(lookup)['days']! as List).single as Map;

      expect(day, {'date': '2026-03-01', 'drinks': 4});
    });
  });

  group('stilstand', () {
    test(
      'welke oefening stilstaat, sinds wanneer en wat er gebeurde',
      () async {
        final now = DateTime.now();
        DateTime weeksAgo(int w) =>
            now.subtract(Duration(days: 7 * w, hours: 2));
        // Bench: drie weken vooruit, dan vijf weken niets beter.
        for (final (w, weight) in [
          (8, 80.0),
          (7, 82.5),
          (6, 85.0),
          (5, 85.0),
          (4, 82.5),
          (3, 85.0),
          (2, 85.0),
          (1, 82.5),
          (0, 85.0),
        ]) {
          await logSet(exerciseId: 'ex-bench', on: weeksAgo(w), weight: weight);
        }
        // Squat: elke week beter.
        for (var w = 8; w >= 0; w--) {
          await logSet(
            exerciseId: 'ex-squat',
            on: weeksAgo(w).add(const Duration(days: 2)),
            weight: 100 + (8 - w) * 2.5,
          );
        }

        final lookup = await tools.run('plateaus', const {});
        final stuck = (decode(lookup)['plateaus']! as List).single as Map;

        expect(stuck['exercise'], 'Bench Press');
        expect(stuck['muscle'], 'borst');
        expect(stuck['measured_in'], 'estimated_1rm_kg');
        expect(stuck['weeks'], 6);
        // 85 kg voor vijf.
        expect(stuck['best'], 99.2);
        expect(stuck['latest'], 99.2);
        expect(stuck['sessions_since'], 6);
        expect(stuck['working_sets_per_session'], 1.0);
        expect(stuck['typical_reps'], 5);
        expect((stuck['muscle_sets_per_week']! as Map)['before'], isNotNull);
        expect(stuck['started_before_recovered'], isA<int>());
        expect(lookup.summary, 'welke oefeningen stilstaan');
      },
    );

    test('en als alles vooruitgaat, een lege lijst', () async {
      for (var w = 6; w >= 0; w--) {
        await logSet(
          exerciseId: 'ex-bench',
          on: DateTime.now().subtract(Duration(days: 7 * w)),
          weight: 80 + (6 - w) * 2.5,
        );
      }

      final lookup = await tools.run('plateaus', const {});

      expect(decode(lookup)['plateaus'], isEmpty);
    });
  });

  group('de grenzen', () {
    test('een tool die niet bestaat komt terug als tekst', () async {
      final lookup = await tools.run('stuur_mijn_data_door', const {});

      expect(decode(lookup)['error'], contains('onbekende tool'));
      expect(lookup.summary, contains('bestaat'));
    });

    test('en geen enkele opzoeking verandert iets', () async {
      await logSet(exerciseId: 'ex-bench', on: DateTime(2026, 2, 20));
      final before = await db.exercisesDao.countExercises();

      for (final name in CoachTools.names) {
        await tools.run(name, {'exercise': 'bench'});
      }

      expect(await db.exercisesDao.countExercises(), before);
      expect(await db.workoutsDao.getActiveWorkoutRow(), isNull);
      final workouts = await db
          .customSelect('SELECT COUNT(*) AS n FROM workouts')
          .getSingle();
      expect(workouts.read<int>('n'), 1);
    });
  });
}
