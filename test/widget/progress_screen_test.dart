import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/progress/presentation/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Voortgang.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets("onder Meer je foto's; records en metingen staan op Profiel", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const ProgressScreen()),
    );
    await tester.pumpAndSettle();

    final more = find.text('MEER');
    await tester.ensureVisible(more);
    expect(more, findsOneWidget);
    expect(find.widgetWithText(ListTile, "Voortgangsfoto's"), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Persoonlijke records'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Lichaamsmetingen'), findsNothing);
  });
}
