import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:fitlog/features/health/presentation/health_connect_screen.dart';
import 'package:fitlog/features/health/presentation/health_providers.dart';
import 'package:fitlog/features/history/presentation/history_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Health Connect as the user meets it: missing, not yet connected,
/// connected - the import behind the button, and sessions written back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late _FakeHealth health;
  late ProviderContainer container;

  final lastNight = ImportedNight(
    fellAsleepAt: DateTime.now().subtract(const Duration(hours: 9)),
    wokeAt: DateTime.now().subtract(const Duration(hours: 1)),
    source: 'com.example.watch',
  );

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    health = _FakeHealth();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appControllerProvider.overrideWith(() => _Ready(db)),
        healthSourceProvider.overrideWithValue(health),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const HealthConnectScreen()),
    );
    await tester.pumpAndSettle();
  }

  group('het scherm', () {
    testWidgets('zonder Health Connect wijst het naar de Play Store', (
      tester,
    ) async {
      health.availabilityAnswer = HealthAvailability.unavailable;
      await pumpScreen(tester);

      await tester.tap(find.text('Health Connect installeren'));
      await tester.pump();

      expect(health.installOpened, isTrue);
      expect(find.text('Verbinden'), findsNothing);
    });

    testWidgets('verbinden vraagt toestemming en haalt meteen op', (
      tester,
    ) async {
      health.snapshot = HealthSnapshot(nights: [lastNight]);
      await pumpScreen(tester);

      await tester.tap(find.text('Verbinden'));
      await tester.pumpAndSettle();

      expect(health.accessRequested, isTrue);
      expect((await db.settingsDao.getSettings()).healthConnectEnabled, isTrue);
      expect(await db.select(db.sleepEntriesTable).get(), hasLength(1));
      expect(find.textContaining('Opgehaald: 1 nacht'), findsOneWidget);
      expect(find.text('Nu ophalen'), findsOneWidget);
    });

    testWidgets('geen toestemming: dan staat er niets aan', (tester) async {
      health.grant = false;
      await pumpScreen(tester);

      await tester.tap(find.text('Verbinden'));
      await tester.pumpAndSettle();

      expect(find.textContaining('geen toegang'), findsOneWidget);
      expect(
        (await db.settingsDao.getSettings()).healthConnectEnabled,
        isFalse,
      );
      expect(health.reads, 0);
    });

    testWidgets('wat niet gelezen mag worden, staat erbij, met een knop', (
      tester,
    ) async {
      health.missing = ['hartslag'];
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
      await pumpScreen(tester);

      expect(
        find.textContaining('mag nog niet lezen: hartslag'),
        findsOneWidget,
      );

      health.missing = const [];
      await tester.tap(find.text('Toestemming aanpassen'));
      await tester.pumpAndSettle();

      expect(health.accessRequested, isTrue);
      expect(health.reads, 1);
      expect(find.textContaining('mag nog niet lezen'), findsNothing);
    });

    testWidgets('ontkoppelen en wissen haalt alles weg wat binnenkwam', (
      tester,
    ) async {
      health.snapshot = HealthSnapshot(nights: [lastNight]);
      await pumpScreen(tester);
      await tester.tap(find.text('Verbinden'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ontkoppelen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ontkoppelen en wissen'));
      await tester.pumpAndSettle();

      expect(health.revoked, isTrue);
      expect(
        (await db.settingsDao.getSettings()).healthConnectEnabled,
        isFalse,
      );
      expect(await db.select(db.sleepEntriesTable).get(), isEmpty);
      expect(find.text('Verbinden'), findsOneWidget);
    });
  });

  group('trainingen terugschrijven', () {
    Future<void> connect({bool write = false}) async {
      await db.settingsDao.updateSettings(
        AppSettingsTableCompanion(
          healthConnectEnabled: const Value(true),
          healthConnectWriteWorkouts: Value(write),
        ),
      );
    }

    /// A finished session, [daysAgo] days back, an hour long.
    Future<String> finished(String id, {int daysAgo = 1, String? name}) async {
      final start = DateTime.now().subtract(Duration(days: daysAgo));
      await db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: id,
              name: name ?? 'Benen',
              startedAt: start.millisecondsSinceEpoch,
              endedAt: Value(
                start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
              ),
            ),
          );
      return id;
    }

    Future<String?> writtenId(String workoutId) async =>
        (await db.workoutsDao.getWorkoutDetail(workoutId))!
            .workout
            .healthConnectId;

    testWidgets('de schakelaar vraagt toestemming en schrijft de laatste '
        'maand', (tester) async {
      await tester.runAsync(() async {
        await finished('w-recent', daysAgo: 3, name: 'Push');
        await finished('w-old', daysAgo: 45);
      });
      await pumpScreen(tester);
      await tester.tap(find.text('Verbinden'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trainingen ook naar Health Connect'));
      await tester.pumpAndSettle();

      expect(
        (await db.settingsDao.getSettings()).healthConnectWriteWorkouts,
        isTrue,
      );
      expect(health.written.single.title, 'Push');
      expect(
        health.written.single.end.difference(health.written.single.start),
        const Duration(hours: 1),
      );
      expect(await writtenId('w-recent'), 'hc-1');
      expect(await writtenId('w-old'), isNull);
    });

    testWidgets('niet verbonden: dan is er ook geen schakelaar', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Trainingen ook naar Health Connect'), findsNothing);
    });

    testWidgets('geen toestemming: dan blijft hij uit', (tester) async {
      health.grantWrite = false;
      await tester.runAsync(() => finished('w-1'));
      await pumpScreen(tester);
      await tester.tap(find.text('Verbinden'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trainingen ook naar Health Connect'));
      await tester.pumpAndSettle();

      expect(
        (await db.settingsDao.getSettings()).healthConnectWriteWorkouts,
        isFalse,
      );
      expect(health.written, isEmpty);
      expect(find.textContaining('geen toestemming'), findsOneWidget);
    });

    test('elke training één keer', () async {
      await connect(write: true);
      await finished('w-1');
      final sync = container.read(healthSyncProvider.notifier);

      expect(await sync.writeWorkouts(), 1);
      expect(await sync.writeWorkouts(), 0);
      expect(health.written, hasLength(1));
    });

    test('uit, of niet verbonden: niets', () async {
      await finished('w-1');
      final sync = container.read(healthSyncProvider.notifier);

      await connect();
      expect(await sync.writeWorkouts(), 0);

      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(
          healthConnectEnabled: Value(false),
          healthConnectWriteWorkouts: Value(true),
        ),
      );
      expect(await sync.writeWorkouts(), 0);
      expect(health.written, isEmpty);
    });

    test('een training die bezig is, gaat niet mee', () async {
      await connect(write: true);
      await db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: 'running',
              name: 'Bezig',
              startedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      expect(
        await container.read(healthSyncProvider.notifier).writeWorkouts(),
        0,
      );
    });

    test('afwerken schrijft de training meteen', () async {
      await connect(write: true);
      final controller = container.read(workoutControllerProvider);
      final id = await controller.startEmpty(name: 'Rug');
      // Een uur geleden begonnen, zodat de sessie een lengte heeft.
      await db.customStatement(
        'UPDATE workouts SET started_at = ? WHERE id = ?',
        [
          DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          id,
        ],
      );

      await controller.finish(id, discardPending: true);

      expect(health.written.single.title, 'Rug');
      expect(await writtenId(id), 'hc-1');
    });

    test('een mislukte schrijfpoging houdt het afwerken niet tegen, en '
        'wordt later opnieuw geprobeerd', () async {
      await connect(write: true);
      health.failingWrites = 1;
      final controller = container.read(workoutControllerProvider);
      final id = await controller.startEmpty(name: 'Rug');
      await db.customStatement(
        'UPDATE workouts SET started_at = ? WHERE id = ?',
        [
          DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          id,
        ],
      );

      await controller.finish(id, discardPending: true);
      final row = (await db.workoutsDao.getWorkoutDetail(id))!.workout;
      expect(row.endedAt, isNotNull);
      expect(row.healthConnectId, isNull);
      expect(container.read(healthSyncProvider).error, isNotNull);

      await container.read(healthSyncProvider.notifier).sync(force: true);
      expect(await writtenId(id), 'hc-1');
    });

    test('een training die je hier wist, verdwijnt ook daar', () async {
      await connect(write: true);
      await finished('w-1');
      await container.read(healthSyncProvider.notifier).writeWorkouts();

      await container.read(historyActionsProvider).deleteWorkout('w-1');

      expect(health.deleted, ['hc-1']);
    });

    test('ontkoppelen zet het schrijven ook uit', () async {
      await connect(write: true);

      await container
          .read(healthSyncProvider.notifier)
          .disconnect(forget: false);

      expect(
        (await db.settingsDao.getSettings()).healthConnectWriteWorkouts,
        isFalse,
      );
    });
  });

  group('het ochtendrapport', () {
    Future<void> scrollTo(WidgetTester tester, Finder target) async {
      await tester.scrollUntilVisible(target, 200);
      await tester.pumpAndSettle();
    }

    testWidgets('de schakelaar zet het aan, standaard om zeven uur', (
      tester,
    ) async {
      await pumpScreen(tester);
      await scrollTo(tester, find.text('Elke ochtend een rapport'));
      expect(find.text('Om 07:00'), findsOneWidget);

      await tester.tap(find.text('Elke ochtend een rapport'));
      await tester.pumpAndSettle();

      final settings = await db.settingsDao.getSettings();
      expect(settings.morningReportEnabled, isTrue);
      expect(settings.morningReportMinutes, 420);
      // Niet verbonden: dan valt er op de achtergrond niets te vragen.
      expect(health.backgroundAsked, isFalse);
    });

    testWidgets('met een pincode zegt het wat dat betekent', (tester) async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appControllerProvider.overrideWith(() => _Ready(db, pin: true)),
          healthSourceProvider.overrideWithValue(health),
        ],
      );
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(morningReportEnabled: Value(true)),
      );
      await pumpScreen(tester);
      await scrollTo(tester, find.textContaining('Je gebruikt een pincode'));

      expect(
        find.textContaining('zodra je FitLog ontgrendelt'),
        findsOneWidget,
      );
    });
  });

  group('het ophalen', () {
    Future<void> connect() async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
    }

    test('doet niets zolang er niet verbonden is', () async {
      await container.read(healthSyncProvider.notifier).sync(force: true);

      expect(health.reads, 0);
    });

    test('de eerste keer een maand terug', () async {
      await connect();
      final now = DateTime(2026, 3, 31, 9);

      await container.read(healthSyncProvider.notifier).sync(now: now);

      expect(health.lastFrom, DateTime(2026, 3, 1));
      expect(health.lastTo, now);
    });

    test('daarna vanaf twee dagen voor de vorige keer', () async {
      // Een horloge geeft zijn nacht soms uren later door.
      await connect();
      final first = DateTime(2026, 3, 31, 9);
      final later = DateTime(2026, 4, 2, 9);

      await container.read(healthSyncProvider.notifier).sync(now: first);
      await container.read(healthSyncProvider.notifier).sync(now: later);

      expect(health.lastFrom, DateTime(2026, 3, 29));
    });

    test('niet opnieuw binnen het kwartier, tenzij je erom vraagt', () async {
      await connect();
      final now = DateTime(2026, 3, 31, 9);
      final sync = container.read(healthSyncProvider.notifier);

      await sync.sync(now: now);
      await sync.sync(now: now.add(const Duration(minutes: 5)));
      expect(health.reads, 1);

      await sync.sync(now: now.add(const Duration(minutes: 5)), force: true);
      expect(health.reads, 2);
    });
  });
}

class _FakeHealth implements HealthSource {
  HealthAvailability availabilityAnswer = HealthAvailability.available;
  bool grant = true;
  bool grantWrite = true;
  HealthSnapshot snapshot = const HealthSnapshot();

  /// How many writes fail before they start working.
  int failingWrites = 0;
  final List<({DateTime start, DateTime end, String title})> written = [];
  final List<String> deleted = [];

  bool installOpened = false;
  bool accessRequested = false;
  bool revoked = false;
  int reads = 0;
  DateTime? lastFrom;
  DateTime? lastTo;

  @override
  Future<HealthAvailability> availability() async => availabilityAnswer;

  @override
  Future<void> openInstall() async => installOpened = true;

  @override
  Future<bool> hasAccess() async => grant;

  @override
  Future<bool> requestAccess() async {
    accessRequested = true;
    return grant;
  }

  @override
  Future<void> revokeAccess() async => revoked = true;

  @override
  Future<HealthSnapshot> read({
    required DateTime from,
    required DateTime to,
  }) async {
    reads++;
    lastFrom = from;
    lastTo = to;
    return snapshot;
  }

  @override
  Future<bool> requestWriteAccess() async => grantWrite;

  @override
  Future<String?> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async {
    if (failingWrites > 0) {
      failingWrites--;
      throw StateError('Health Connect is busy');
    }
    written.add((start: start, end: end, title: title));
    return 'hc-${written.length}';
  }

  @override
  Future<void> deleteWorkout(String id) async => deleted.add(id);

  bool backgroundAsked = false;

  /// What the watch measured, and what may not be read.
  List<ImportedReading> heart = const [];
  List<String> missing = const [];

  @override
  Future<List<ImportedReading>> heartRate({
    required DateTime from,
    required DateTime to,
  }) async => heart;

  @override
  Future<List<String>> missingAccess() async => missing;

  @override
  Future<bool> requestBackgroundAccess() async {
    backgroundAsked = true;
    return true;
  }
}

class _Ready extends AppController {
  _Ready(this._db, {this.pin = false});

  final AppDatabase _db;
  final bool pin;

  @override
  AppState build() => AppReady(
    db: _db,
    security: SecurityStatus(
      initialised: true,
      mode: pin ? LockMode.pin : LockMode.none,
      biometricEnabled: false,
      hasRecoveryPhrase: false,
      consecutiveFailures: 0,
      lastFailureAt: null,
    ),
  );
}
