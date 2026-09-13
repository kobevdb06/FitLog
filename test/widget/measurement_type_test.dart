import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/measurements/presentation/measurements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Choosing what you are about to measure.
///
/// It was the last Material dropdown left in the app: a grey slab of twelve
/// names over the page, in a style nothing else here uses - and sitting right
/// above two fields that open a sheet when you tap them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  /// Every type name also sits in the list behind the sheet, so anything about
  /// the field itself is asked of the field itself.
  Finder typeField() => find.ancestor(
    of: find.text('Type'),
    matching: find.byType(InputDecorator),
  );

  Finder inTypeField(String text) =>
      find.descendant(of: typeField(), matching: find.text(text));

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithContainer(container, const MeasurementsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Meting'));
    await tester.pumpAndSettle();
  }

  Future<void> pickType(WidgetTester tester, String label) async {
    await tester.tap(typeField());
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the type opens the app sheet, not a dropdown', (tester) async {
    await openSheet(tester);

    expect(
      find.byType(DropdownButtonFormField<Object?>),
      findsNothing,
      reason: 'de oude stijl hoort nergens meer te staan',
    );
    expect(inTypeField('Gewicht'), findsOneWidget);

    await tester.tap(typeField());
    await tester.pumpAndSettle();

    expect(find.text('Wat wil je meten?'), findsOneWidget);
  });

  testWidgets('and the one you pick lands in the field', (tester) async {
    await openSheet(tester);

    await pickType(tester, 'Taille');

    expect(find.text('Wat wil je meten?'), findsNothing);
    expect(inTypeField('Taille'), findsOneWidget);
    expect(inTypeField('Gewicht'), findsNothing);
  });

  testWidgets('the unit follows the type', (tester) async {
    await openSheet(tester);
    // Weight is in kilograms, a waist in centimetres, and the field says so.
    expect(find.text('kg'), findsWidgets);

    await pickType(tester, 'Taille');

    expect(find.text('cm'), findsWidgets);
  });

  testWidgets('a value you typed does not survive a change of type', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Tik om in te vullen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('82'), findsOneWidget);

    await pickType(tester, 'Taille');

    expect(
      find.text('82'),
      findsNothing,
      reason: '82 kg wordt geen 82 cm omdat je van gedachten verandert',
    );
    expect(find.text('Tik om in te vullen'), findsOneWidget);
  });
}
