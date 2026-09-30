import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:fitlog/features/health/presentation/health_connect_screen.dart';
import 'package:fitlog/features/health/presentation/health_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Health Connect as the user meets it: missing, not yet connected,
/// connected - and the import behind the button.
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
  HealthSnapshot snapshot = const HealthSnapshot();

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
}

class _Ready extends AppController {
  _Ready(this._db);

  final AppDatabase _db;

  @override
  AppState build() => AppReady(
    db: _db,
    security: const SecurityStatus(
      initialised: true,
      mode: LockMode.none,
      biometricEnabled: false,
      hasRecoveryPhrase: false,
      consecutiveFailures: 0,
      lastFailureAt: null,
    ),
  );
}
