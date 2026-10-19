import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/formatting/formatters.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/chat/presentation/coach_session.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Which conversation the Chat tab opens: a new one, unless a workout runs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late Directory home;
  final containers = <ProviderContainer>[];

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    home = await Directory.systemTemp.createTemp('fitlog_session');
  });

  tearDown(() async {
    for (final container in containers) {
      container.dispose();
    }
    containers.clear();
    await db.close();
    if (await home.exists()) await home.delete(recursive: true);
  });

  /// The app, started: a container with the session listened to, as the
  /// Chat tab does, and given the time to read what is running.
  Future<ProviderContainer> start() async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(home)),
      ],
    );
    containers.add(container);
    container.listen(coachSessionControllerProvider, (_, _) {});
    await settle(container);
    return container;
  }

  CoachSession session(ProviderContainer container) =>
      container.read(coachSessionControllerProvider);

  CoachSessionController control(ProviderContainer container) =>
      container.read(coachSessionControllerProvider.notifier);

  test('opent leeg, ook als er eerdere gesprekken zijn', () async {
    await db.chatDao.createThread('t-1', 'Hoeveel sets voor borst?');

    final app = await start();

    expect(session(app).threadId, isNull);
    expect(session(app).workoutId, isNull);
  });

  group('tijdens een workout', () {
    test('opent het gesprek van die workout, ook na een herstart', () async {
      final workout = await db.workoutsDao.startWorkout(
        name: 'Push A',
        defaultRestSeconds: 90,
      );
      final first = await start();
      final thread = await coachOf(first).workoutThread(workout);

      final again = await start();

      expect(session(again).threadId, thread);
      expect(session(again).workoutId, workout);
    });

    test('zonder gesprek nog maakt de eerste vraag het, op naam van de '
        'workout', () async {
      final workout = await db.workoutsDao.startWorkout(
        name: 'Push A',
        defaultRestSeconds: 90,
      );
      final app = await start();
      expect(session(app).threadId, isNull);
      expect(session(app).workoutId, workout);

      final thread = await control(app).threadFor('Is 80 kg goed?');

      final row = (await db.chatDao.threadForWorkout(workout))!;
      expect(row.id, thread);
      expect(row.title, 'Push A · ${Formatters.dayMonth(DateTime.now())}');
      expect(session(app).threadId, thread);
    });

    test('een workout die start, neemt het tabblad mee', () async {
      await db.chatDao.createThread('t-1', 'Wat train ik vandaag?');
      final app = await start();
      control(app).show('t-1');

      final workout = await db.workoutsDao.startWorkout(
        name: 'Push A',
        defaultRestSeconds: 90,
      );
      await settle(app);

      expect(session(app).workoutId, workout);
      expect(session(app).threadId, isNull);
    });

    test('Nieuw gesprek staat los van de workout', () async {
      final workout = await db.workoutsDao.startWorkout(
        name: 'Push A',
        defaultRestSeconds: 90,
      );
      final app = await start();

      control(app).startNew();
      final thread = await control(app).threadFor('Iets anders');

      expect(await db.chatDao.threadForWorkout(workout), isNull);
      expect(session(app).threadId, thread);
      expect(session(app).workoutId, isNull);
    });
  });

  group('weg uit de app', () {
    test('een half uur of langer: weer leeg', () async {
      await db.chatDao.createThread('t-1', 'Wat train ik vandaag?');
      final app = await start();
      control(app).show('t-1');

      final at = DateTime(2026, 10, 19, 8);
      control(app).left(at);
      await control(app).back(at.add(const Duration(minutes: 29)));
      expect(session(app).threadId, 't-1');

      control(app).left(at);
      await control(app).back(at.add(kCoachFreshAfter));
      expect(session(app).threadId, isNull);
    });

    test('maar tijdens een workout terug naar die workout', () async {
      final workout = await db.workoutsDao.startWorkout(
        name: 'Push A',
        defaultRestSeconds: 90,
      );
      await db.chatDao.createThread('t-1', 'Iets anders');
      final app = await start();
      control(app).show('t-1');

      final at = DateTime(2026, 10, 19, 8);
      control(app).left(at);
      await control(app).back(at.add(const Duration(hours: 1)));

      expect(session(app).workoutId, workout);
    });
  });

  test('een gewist gesprek: de volgende vraag maakt een nieuw', () async {
    await db.chatDao.createThread('t-1', 'Weg');
    final app = await start();
    control(app).show('t-1');
    await db.chatDao.deleteAllThreads();

    final thread = await control(app).threadFor('Opnieuw');

    expect(thread, isNot('t-1'));
    expect(await db.chatDao.threadExists(thread), isTrue);
  });
}

CoachController coachOf(ProviderContainer app) =>
    app.read(coachControllerProvider.notifier);

/// Lets the running workout's stream deliver, and what follows from it.
Future<void> settle(ProviderContainer container) async {
  await container.read(activeWorkoutProvider.future);
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
