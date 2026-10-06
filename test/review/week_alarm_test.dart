import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/review/data/week_alarm.dart';
import 'package:fitlog/features/review/data/week_reviewer.dart';
import 'package:fitlog/features/review/presentation/review_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The weekly review on Sunday evening: when, what with a PIN, and catching
/// up after an unlock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wanneer', () {
    test('de komende zondag om acht', () {
      expect(
        nextSundayEvening(DateTime(2026, 9, 30, 12)),
        DateTime(2026, 10, 4, 20),
      );
      expect(
        nextSundayEvening(DateTime(2026, 10, 4, 19, 59)),
        DateTime(2026, 10, 4, 20),
      );
    });

    test('vanaf acht is het die van volgende week', () {
      expect(
        nextSundayEvening(DateTime(2026, 10, 4, 20)),
        DateTime(2026, 10, 11, 20),
      );
      expect(
        nextSundayEvening(DateTime(2026, 10, 4, 22)),
        DateTime(2026, 10, 11, 20),
      );
    });

    test('ook de zondag dat de klok verspringt', () {
      // 25 oktober 2026: de wintertijd begint.
      final sunday = nextSundayEvening(DateTime(2026, 10, 21, 9));
      expect(sunday, DateTime(2026, 10, 25, 20));
      expect(sunday.hour, 20);
    });

    test('de laatste die voorbij is', () {
      expect(
        lastSundayEvening(DateTime(2026, 10, 5, 9)),
        DateTime(2026, 10, 4, 20),
      );
      expect(
        lastSundayEvening(DateTime(2026, 10, 4, 19)),
        DateTime(2026, 9, 27, 20),
      );
    });
  });

  group('als het afgaat', () {
    final sundayEvening = DateTime(2026, 10, 4, 20);
    late _Alarm alarm;
    late _Notices notices;
    late KeyManager keys;
    AppDatabase? opened;

    setUp(() {
      alarm = _Alarm();
      notices = _Notices();
      keys = KeyManager(InMemorySecretStore());
      opened = null;
    });

    WeekAlarmHandler handler({bool handedOff = false, bool enabled = true}) =>
        WeekAlarmHandler(
          schedule: WeekSchedule(alarm),
          handOff: () async => handedOff,
          keys: keys,
          openDatabase: (key) async {
            final db = createTestDatabase();
            await db.settingsDao.ensureInitialized();
            await db.settingsDao.updateSettings(
              AppSettingsTableCompanion(weekReviewNotify: Value(enabled)),
            );
            await db.recoveryDao.setSleep(
              fellAsleepAt: DateTime(2026, 10, 2, 23),
              wokeAt: DateTime(2026, 10, 3, 7),
            );
            return opened = db;
          },
          notices: notices,
          clock: () => sundayEvening,
        );

    test('zonder pincode: maken, bewaren, melden', () async {
      await keys.setDirectKey(Uint8List(32));

      final outcome = await handler().handle();

      expect(outcome, WeekOutcome.reported);
      expect(notices.reviews.single.facts.start, DateTime(2026, 9, 28));
      // Zonder coach geen tekst: de melding zegt dan de cijfers.
      expect(notices.reviews.single.coachText, isNull);
      // En volgende zondag weer.
      expect(alarm.at, DateTime(2026, 10, 11, 20));
    });

    test('met een pincode blijft het logboek dicht', () async {
      await keys.setPin(dek: Uint8List(32), pin: '1234');

      final outcome = await handler().handle();

      expect(outcome, WeekOutcome.locked);
      expect(opened, isNull);
      expect(notices.locked, 1);
      expect(alarm.at, DateTime(2026, 10, 11, 20));
    });

    test('is de app open, dan doet die het', () async {
      await keys.setDirectKey(Uint8List(32));

      expect(await handler(handedOff: true).handle(), WeekOutcome.handedOff);
      expect(opened, isNull);
    });

    test('uitgezet: niets, en weg met het wekkertje', () async {
      await keys.setDirectKey(Uint8List(32));

      expect(await handler(enabled: false).handle(), WeekOutcome.switchedOff);
      expect(notices.reviews, isEmpty);
      expect(alarm.at, isNull);
    });
  });

  group('in de app', () {
    late AppDatabase db;
    late _Alarm alarm;
    late _Notices notices;
    ProviderContainer? container;

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      alarm = _Alarm();
      notices = _Notices();
    });

    tearDown(() async {
      container?.dispose();
      container = null;
      await db.close();
    });

    WeekNotify notify({AppState? state}) {
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          weekScheduleProvider.overrideWithValue(WeekSchedule(alarm)),
          weekNoticesProvider.overrideWithValue(notices),
          appControllerProvider.overrideWith(
            () => _Fixed(state ?? AppReady(db: db, security: _none)),
          ),
        ],
      );
      return container!.read(weekNotifyProvider);
    }

    test('standaard aan: het wekkertje komt er bij het ontgrendelen', () async {
      await notify().syncAlarm(now: DateTime(2026, 10, 6, 9));

      expect(alarm.at, DateTime(2026, 10, 11, 20));
    });

    test('uitzetten haalt het weg', () async {
      final week = notify();
      await week.syncAlarm(now: DateTime(2026, 10, 6, 9));
      await week.disable();

      expect(alarm.at, isNull);
      expect((await db.settingsDao.getSettings()).weekReviewNotify, isFalse);
    });

    test('gaat het af terwijl de app open is, dan maakt die het', () async {
      await notify().onAlarm(now: DateTime(2026, 10, 4, 20));

      expect(notices.reviews.single.facts.start, DateTime(2026, 9, 28));
      expect(
        await db.reportsDao.weekReviewFor(DateTime(2026, 9, 28)),
        isNotNull,
      );
    });

    test('en is ze vergrendeld, dan wacht het op het ontgrendelen', () async {
      await notify(state: const AppLocked(_none)).onAlarm();

      expect(notices.locked, 1);
      expect(notices.reviews, isEmpty);
    });

    group('na het ontgrendelen', () {
      test('maandag zonder overzicht: het overzicht van vorige week, in '
          'plaats van de wachtende melding', () async {
        notices.showing = true;

        await notify().catchUp(now: DateTime(2026, 10, 5, 9));

        expect(notices.reviews.single.facts.start, DateTime(2026, 9, 28));
        expect(
          await db.reportsDao.weekReviewFor(DateTime(2026, 9, 28)),
          isNotNull,
        );
      });

      test('zonder wachtende melding geen nieuwe, maar wel gemaakt', () async {
        await notify().catchUp(now: DateTime(2026, 10, 5, 9));

        expect(notices.reviews, isEmpty);
        expect(
          await db.reportsDao.weekReviewFor(DateTime(2026, 9, 28)),
          isNotNull,
        );
      });

      test('en is het er al, dan niet opnieuw', () async {
        final week = notify();
        await week.catchUp(now: DateTime(2026, 10, 5, 9));
        notices.showing = true;
        await week.catchUp(now: DateTime(2026, 10, 5, 10));

        expect(notices.reviews, isEmpty);
      });

      test('woensdag is te laat om nog over vorige week te beginnen', () async {
        await notify().catchUp(now: DateTime(2026, 10, 7, 9));

        expect(
          await db.reportsDao.weekReviewFor(DateTime(2026, 9, 28)),
          isNull,
        );
      });

      test('en uitgezet: niets', () async {
        await db.settingsDao.updateSettings(
          const AppSettingsTableCompanion(weekReviewNotify: Value(false)),
        );

        await notify().catchUp(now: DateTime(2026, 10, 5, 9));

        expect(
          await db.reportsDao.weekReviewFor(DateTime(2026, 9, 28)),
          isNull,
        );
      });
    });
  });
}

const _none = SecurityStatus(
  initialised: true,
  mode: LockMode.none,
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

class _Alarm implements WeekAlarm {
  DateTime? at;

  @override
  Future<void> setAt(DateTime at) async => this.at = at;

  @override
  Future<void> cancel() async => at = null;
}

class _Notices implements WeekNotices {
  final List<WeekReview> reviews = [];
  int locked = 0;
  bool showing = false;

  @override
  Future<void> showReview(WeekReview review) async => reviews.add(review);

  @override
  Future<void> showLocked() async => locked++;

  @override
  Future<bool> isShowing() async => showing;
}
