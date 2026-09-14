import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
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
