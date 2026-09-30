import 'package:drift/drift.dart' show Value;
import 'package:fitlog/app.dart';
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A cold start, from before the database is open to the moment it is.
///
/// The root widget keeps the workout notification, the home-screen shortcuts
/// and the theme in step with the database. It watched those on every build,
/// also before the database was open, which left the database provider stuck
/// on "De database is nog niet geopend". The moment the app opened, the
/// Health Connect import - started from that same widget - was handed that
/// stale error, and every cold start logged it as an unhandled exception.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late _Scripted controller;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester, AppState initial) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    controller = _Scripted(initial);
    // The real database provider, deliberately: it is the one that refuses
    // to answer before the app is open.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith(() => controller)],
        child: const FitLogApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  testWidgets('unlocking with a PIN', (tester) async {
    await pumpApp(tester, _locked);

    controller.open(db);
    await settle(tester);

    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('opening straight through, without a PIN', (tester) async {
    await pumpApp(tester, const AppLoading());

    controller.open(db);
    await settle(tester);

    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('and unlocking again after the auto-lock', (tester) async {
    await pumpApp(tester, _locked);
    controller.open(db);
    await settle(tester);

    await controller.lock();
    await settle(tester);
    controller.open(db);
    await settle(tester);

    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('the lock screen keeps the theme you chose', (tester) async {
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(themeMode: Value('light')),
    );
    await pumpApp(tester, _locked);
    controller.open(db);
    await settle(tester);
    expect(themeMode(tester), ThemeMode.light);

    await controller.lock();
    await settle(tester);

    expect(themeMode(tester), ThemeMode.light);
    await tearDownApp(tester);
  });
}

ThemeMode? themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

/// A few frames, without waiting for the dashboard's animations to stop.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const _security = SecurityStatus(
  initialised: true,
  mode: LockMode.pin,
  biometricEnabled: false,
  hasRecoveryPhrase: false,
  consecutiveFailures: 0,
  lastFailureAt: null,
);

const _locked = AppLocked(_security);

/// An app controller the test moves from state to state by hand.
class _Scripted extends AppController {
  _Scripted(this._initial);

  final AppState _initial;

  @override
  AppState build() => _initial;

  void open(AppDatabase db) => state = AppReady(db: db, security: _security);

  /// What the auto-lock does, without asking the key store first.
  @override
  Future<void> lock() async => state = _locked;
}
