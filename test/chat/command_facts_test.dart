import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/command_facts.dart';
import 'package:fitlog/features/chat/domain/coach_commands.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// What /workout, /week and /maand ask the coach about.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
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

  /// A finished Push A, now, with one set of bench presses.
  Future<void> pushA() async {
    final id = await db.workoutsDao.startWorkout(
      name: 'Push A',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(id, ['ex-bench'], defaultRestSeconds: 90);
    final set = (await db.workoutsDao.getWorkoutDetail(id))!
        .exercises
        .single
        .sets
        .single;
    await db.workoutsDao.updateSet(
      set.id,
      weightKg: const Value(80),
      reps: const Value(6),
      isCompleted: const Value(true),
    );
    await db.workoutsDao.finishWorkout(id, discardPending: false);
  }

  test('without training there is nothing to ask about a workout or a '
      'month, and the week is still there', () async {
    final now = DateTime.now();
    final workout = await commandFacts(db, CoachCommand.workout, now: now);
    expect(workout.facts, isNull);
    expect(workout.none, isNotNull);
    final month = await commandFacts(db, CoachCommand.maand, now: now);
    expect(month.facts, isNull);
    expect(month.none, isNotNull);
    final week = await commandFacts(db, CoachCommand.week, now: now);
    expect(week.facts, isNotNull);
    expect(week.sent, 'je laatste zeven dagen');
  });

  test('after a workout: that workout, and this month', () async {
    await pushA();
    final now = DateTime.now();

    final workout = await commandFacts(db, CoachCommand.workout, now: now);
    expect(workout.facts!['name'], 'Push A');
    expect(workout.sent, startsWith('je laatste workout (Push A, '));

    final month = await commandFacts(db, CoachCommand.maand, now: now);
    expect(month.facts, isNotNull);
    expect(month.sent, 'je maand tot nu, naast de vorige');
  });

  test('each asks with the prompt of its own moment', () {
    expect(momentOf(CoachCommand.workout), CoachMoment.workout);
    expect(momentOf(CoachCommand.week), CoachMoment.week);
    expect(momentOf(CoachCommand.maand), CoachMoment.month);
    expect(momentOf(CoachCommand.kosten), isNull);
  });
}
