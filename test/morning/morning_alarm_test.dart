import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:fitlog/features/health/presentation/health_providers.dart';
import 'package:fitlog/features/morning/data/morning_alarm.dart';
import 'package:fitlog/features/morning/data/morning_reporter.dart';
import 'package:fitlog/features/morning/presentation/morning_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The morning report on its own: the hour, the alarm, and what happens when
/// it goes off - with the app open, closed, or behind a PIN.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('het volgende uur', () {
    test('vandaag, zolang het nog moet komen', () {
      expect(
        nextMorning(DateTime(2026, 3, 3, 6, 30), 420),
        DateTime(2026, 3, 3, 7),
      );
    });

    test('morgen, als het voorbij is of nu', () {
      expect(
        nextMorning(DateTime(2026, 3, 3, 7), 420),
        DateTime(2026, 3, 4, 7),
      );
      expect(
        nextMorning(DateTime(2026, 3, 3, 22), 450),
        DateTime(2026, 3, 4, 7, 30),
      );
    });

    test('ook de nacht dat de klok verspringt', () {
      // In België gaat de klok op 29 maart 2026 een uur vooruit.
      final next = nextMorning(DateTime(2026, 3, 28, 8), 420);

      expect(next.day, 29);
      expect(next.hour, 7);
      expect(next.minute, 0);
    });
  });

  group('het wekkertje', () {
    test('aan zet het op het volgende uur, uit haalt het weg', () async {
      final alarm = _Alarm();
      final schedule = MorningSchedule(alarm);

      await schedule.apply(
        enabled: true,
        minutes: 420,
        now: DateTime(2026, 3, 3, 8),
      );
      expect(alarm.at, DateTime(2026, 3, 4, 7));
      expect(alarm.minutes, 420);

      await schedule.apply(enabled: false, minutes: 420);
      expect(alarm.at, isNull);
    });
  });

  group('de app die al open is', () {
    tearDown(() => IsolateNameServer.removePortNameMapping(kMorningPortName));

    test('neemt het over als ze antwoordt', () async {
      final app = ReceivePort();
      addTearDown(app.close);
      IsolateNameServer.registerPortWithName(app.sendPort, kMorningPortName);
      app.listen((message) => (message as SendPort).send(true));

      expect(await handOffToOpenApp(), isTrue);
    });

    test('een naam die niemand meer beantwoordt, wordt opgeruimd', () async {
      final gone = ReceivePort();
      addTearDown(gone.close);
      IsolateNameServer.registerPortWithName(gone.sendPort, kMorningPortName);

      expect(
        await handOffToOpenApp(wait: const Duration(milliseconds: 50)),
        isFalse,
      );
      expect(IsolateNameServer.lookupPortByName(kMorningPortName), isNull);
    });

    test('en zonder app doet het wekkertje het zelf', () async {
      expect(await handOffToOpenApp(), isFalse);
    });
  });

  group('als het afgaat', () {
    final seven = DateTime(2026, 3, 3, 7);
    late _Alarm alarm;
    late _Notices notices;
    late InMemorySecretStore store;
    late KeyManager keys;
    AppDatabase? opened;

    setUp(() {
      alarm = _Alarm();
      notices = _Notices();
      store = InMemorySecretStore();
      keys = KeyManager(store);
      opened = null;
    });

    MorningAlarmHandler handler({
      bool handedOff = false,
      bool enabled = true,
    }) => MorningAlarmHandler(
      schedule: MorningSchedule(alarm),
      handOff: () async => handedOff,
      keys: keys,
      openDatabase: (key) async {
        final db = createTestDatabase();
        await db.settingsDao.ensureInitialized();
        await db.settingsDao.updateSettings(
          AppSettingsTableCompanion(morningReportEnabled: Value(enabled)),
        );
        await db.recoveryDao.setSleep(
          fellAsleepAt: DateTime(2026, 3, 2, 23),
          wokeAt: DateTime(2026, 3, 3, 6),
        );
        return opened = db;
      },
      source: _Watch(),
      notices: notices,
      clock: () => seven,
    );

    test('zonder pincode: ophalen, opstellen, melden', () async {
      await keys.setDirectKey(Uint8List(32));

      final outcome = await handler().handle(minutes: 420);

      expect(outcome, MorningOutcome.reported);
      expect(notices.reports.single.facts.score, 75);
      expect(notices.locked, 0);
      // En morgen weer.
      expect(alarm.at, DateTime(2026, 3, 4, 7));
    });

    test('met een pincode blijft het logboek dicht', () async {
      await keys.setPin(dek: Uint8List(32), pin: '1234');

      final outcome = await handler().handle(minutes: 420);

      expect(outcome, MorningOutcome.locked);
      expect(opened, isNull);
      expect(notices.locked, 1);
      expect(alarm.at, DateTime(2026, 3, 4, 7));
    });

    test('ook als biometrie een sleutel bewaart', () async {
      await keys.setPin(dek: Uint8List(32), pin: '1234', keepDirectKey: true);
      await keys.enableBiometrics(Uint8List(32));

      expect(await handler().handle(minutes: 420), MorningOutcome.locked);
      expect(opened, isNull);
    });

    test('is de app open, dan doet die het', () async {
      await keys.setDirectKey(Uint8List(32));

      final outcome = await handler(handedOff: true).handle(minutes: 420);

      expect(outcome, MorningOutcome.handedOff);
      expect(opened, isNull);
      expect(notices.reports, isEmpty);
    });

    test('uitgezet sinds het gezet werd: niets, en weg ermee', () async {
      await keys.setDirectKey(Uint8List(32));

      final outcome = await handler(enabled: false).handle(minutes: 420);

      expect(outcome, MorningOutcome.switchedOff);
      expect(notices.reports, isEmpty);
      expect(alarm.at, isNull);
    });
  });

  group('in de app', () {
    late AppDatabase db;
    late _Alarm alarm;
    late _Notices notices;
    late _Watch watch;

    ProviderContainer container({AppState? state}) {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appControllerProvider.overrideWith(
            () => _Fixed(state ?? AppReady(db: db, security: _open)),
          ),
          healthSourceProvider.overrideWithValue(watch),
          morningScheduleProvider.overrideWithValue(MorningSchedule(alarm)),
          morningNoticesProvider.overrideWithValue(notices),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      alarm = _Alarm();
      notices = _Notices();
      watch = _Watch();
    });
    tearDown(() => db.close());

    test('aanzetten zet het wekkertje, uitzetten haalt het weg', () async {
      final c = container();
      final morning = c.read(morningControllerProvider.notifier);

      await morning.enable();
      expect((await db.settingsDao.getSettings()).morningReportEnabled, isTrue);
      expect(alarm.at, isNotNull);
      expect(alarm.at!.hour, 7);

      await morning.setMinutes(6 * 60 + 45);
      expect(alarm.at!.hour, 6);
      expect(alarm.at!.minute, 45);

      await morning.disable();
      expect(alarm.at, isNull);
    });

    test(
      'met Health Connect vraagt het om op de achtergrond te lezen',
      () async {
        await db.settingsDao.updateSettings(
          const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
        );
        watch.background = false;
        final c = container();

        await c.read(morningControllerProvider.notifier).enable();

        expect(watch.backgroundAsked, isTrue);
        // Geweigerd, en toch staat het aan - met uitleg.
        expect(
          (await db.settingsDao.getSettings()).morningReportEnabled,
          isTrue,
        );
        expect(
          c.read(morningControllerProvider).notice,
          contains('achtergrond'),
        );
      },
    );

    test('gaat het af terwijl de app open is, dan maakt die het', () async {
      final c = container();

      await c.read(morningControllerProvider.notifier).onAlarm();

      expect(notices.reports, hasLength(1));
      expect(await db.select(db.morningReportsTable).get(), hasLength(1));
    });

    test('en is ze vergrendeld, dan wacht het op het ontgrendelen', () async {
      final c = container(state: const AppLocked(_pin));

      await c.read(morningControllerProvider.notifier).onAlarm();

      expect(notices.locked, 1);
      expect(await db.select(db.morningReportsTable).get(), isEmpty);
    });

    group('na het ontgrendelen', () {
      Future<void> switchOn() => db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(morningReportEnabled: Value(true)),
      );

      test('voor het uur: nog niets', () async {
        await switchOn();
        final c = container();

        await c
            .read(morningControllerProvider.notifier)
            .catchUp(now: DateTime(2026, 3, 3, 6, 30));

        expect(await db.select(db.morningReportsTable).get(), isEmpty);
      });

      test('erna, zonder rapport: het rapport van vanochtend', () async {
        await switchOn();
        notices.showing = true;
        final c = container();

        await c
            .read(morningControllerProvider.notifier)
            .catchUp(now: DateTime(2026, 3, 3, 9));

        expect(await db.select(db.morningReportsTable).get(), hasLength(1));
        // De melding die op het ontgrendelen wachtte, wordt het rapport.
        expect(notices.reports, hasLength(1));
      });

      test('zonder wachtende melding komt er geen nieuwe bij', () async {
        await switchOn();
        final c = container();

        await c
            .read(morningControllerProvider.notifier)
            .catchUp(now: DateTime(2026, 3, 3, 9));

        expect(await db.select(db.morningReportsTable).get(), hasLength(1));
        expect(notices.reports, isEmpty);
      });

      test('en is het er al, dan niet opnieuw', () async {
        await switchOn();
        final c = container();
        final morning = c.read(morningControllerProvider.notifier);
        await morning.makeNow(now: DateTime(2026, 3, 3, 7));
        final first = (await db.select(db.morningReportsTable).get()).single;

        await morning.catchUp(now: DateTime(2026, 3, 3, 9));

        final rows = await db.select(db.morningReportsTable).get();
        expect(rows.single.createdAt, first.createdAt);
      });

      test('en uitgezet: niets', () async {
        final c = container();

        await c
            .read(morningControllerProvider.notifier)
            .catchUp(now: DateTime(2026, 3, 3, 9));

        expect(await db.select(db.morningReportsTable).get(), isEmpty);
      });
    });
  });
}

const _open = SecurityStatus(
  initialised: true,
  mode: LockMode.none,
  biometricEnabled: false,
  hasRecoveryPhrase: false,
  consecutiveFailures: 0,
  lastFailureAt: null,
);

const _pin = SecurityStatus(
  initialised: true,
  mode: LockMode.pin,
  biometricEnabled: false,
  hasRecoveryPhrase: false,
  consecutiveFailures: 0,
  lastFailureAt: null,
);

class _Fixed extends AppController {
  _Fixed(this._state);

  final AppState _state;

  @override
  AppState build() => _state;
}

class _Alarm implements MorningAlarm {
  DateTime? at;
  int? minutes;

  @override
  Future<void> setAt(DateTime at, {required int minutes}) async {
    this.at = at;
    this.minutes = minutes;
  }

  @override
  Future<void> cancel() async {
    at = null;
    minutes = null;
  }
}

class _Notices implements MorningNotices {
  final List<MorningReport> reports = [];
  int locked = 0;
  bool showing = false;

  @override
  Future<void> showReport(MorningReport report) async => reports.add(report);

  @override
  Future<void> showLocked() async => locked++;

  @override
  Future<bool> isShowing() async => showing;
}

class _Watch implements HealthSource {
  bool background = true;
  bool backgroundAsked = false;

  @override
  Future<HealthSnapshot> read({
    required DateTime from,
    required DateTime to,
  }) async => const HealthSnapshot();

  @override
  Future<bool> requestBackgroundAccess() async {
    backgroundAsked = true;
    return background;
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
  Future<List<String>> missingAccess() async => const [];
}
