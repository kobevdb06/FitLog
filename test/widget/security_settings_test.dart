import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/biometric_service.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/settings/presentation/security_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _NoBiometrics extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({String reason = ''}) async => false;
}

/// Beveiliging: when FitLog locks itself again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late InMemorySecretStore store;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    store = InMemorySecretStore();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(store),
        biometricServiceProvider.overrideWithValue(_NoBiometrics()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const SecuritySettingsScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<int> lockAfter(WidgetTester tester) async =>
      (await tester.runAsync(db.settingsDao.getSettings))!.autoLockSeconds;

  testWidgets('met een pincode kies je wanneer ze weer vergrendelt', (
    tester,
  ) async {
    // A PIN is there when its wrapped key is.
    await store.write('fitlog.dek.pin', 'wrapped');
    await pump(tester);

    await tester.tap(find.text('Na 5 minuten'));
    await tester.pumpAndSettle();

    expect(await lockAfter(tester), 300);
  });

  testWidgets('zonder pincode valt er niets te kiezen', (tester) async {
    await pump(tester);
    final before = await lockAfter(tester);

    await tester.tap(find.text('Na 5 minuten'));
    await tester.pumpAndSettle();

    expect(await lockAfter(tester), before);
    expect(
      find.text('Auto-vergrendelen werkt alleen met een pincode.'),
      findsOneWidget,
    );
  });
}
