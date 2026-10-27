import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/measurements/presentation/measurements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Lichaamsmetingen: weight and body fat above, every girth beside the part
/// of the body it is taken of.
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

  Future<void> measure(MeasurementType type, double value, DateTime at) =>
      db.recordsDao.addMeasurement(type: type, value: value, measuredAt: at);

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1100, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const MeasurementsScreen()),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('elke maat bij haar lichaamsdeel, met wat je mat', (
    tester,
  ) async {
    final today = DateTime.now();
    await measure(MeasurementType.weight, 95, DateTime(2026, 10, 4));
    await measure(MeasurementType.leftArm, 46, today);
    await measure(MeasurementType.rightArm, 46.5, today);
    await pump(tester);

    expect(find.text('95 kg'), findsOneWidget);
    expect(find.text('46 cm'), findsOneWidget);
    expect(find.text('46,5 cm'), findsOneWidget);
    // Body fat and the eight girths not measured yet; no row for each.
    expect(find.text('+ meten'), findsNWidgets(9));
    expect(find.text('Nog geen meting'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    // Left of the figure what is on your left, as in a mirror.
    expect(
      tester.getCenter(find.text('Arm L')).dx,
      lessThan(tester.getCenter(find.text('Arm R')).dx),
    );
    expect(
      tester.getCenter(find.text('Nek')).dy,
      lessThan(tester.getCenter(find.text('Kuit L')).dy),
    );
  });

  testWidgets('een gemeten maat toont haar verloop, met waarvan het '
      'verschil is', (tester) async {
    await measure(MeasurementType.weight, 95, DateTime(2026, 10, 4));
    await measure(MeasurementType.weight, 95, DateTime(2026, 10, 20));
    await measure(MeasurementType.leftArm, 45.5, DateTime(2026, 10, 4));
    await measure(MeasurementType.leftArm, 46, DateTime(2026, 10, 20));
    await pump(tester);

    await tester.tap(find.text('Gewicht'));
    await tester.pumpAndSettle();
    expect(find.textContaining('gelijk sinds 4 okt'), findsOneWidget);
    expect(find.text('Meting toevoegen'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arm L'));
    await tester.pumpAndSettle();
    expect(find.text('Arm links'), findsOneWidget);
    expect(find.textContaining('+0,5 cm sinds 4 okt'), findsOneWidget);

    // Taking it again starts from the same measure.
    await tester.tap(find.text('Meting toevoegen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sinds 4 okt'), findsNothing);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Type'),
          matching: find.byType(InputDecorator),
        ),
        matching: find.text('Arm links'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('een maat zonder meting opent meteen de meting', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Taille'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Type'),
          matching: find.byType(InputDecorator),
        ),
        matching: find.text('Taille'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('op een smalle gsm met grote letters staat niets over elkaar', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await measure(MeasurementType.rightArm, 46.5, DateTime.now());
    await pump(tester, size: const Size(360, 800));

    expect(tester.takeException(), isNull);
    Rect rect(String text) => tester.getRect(find.text(text));
    for (final side in [
      ['Nek', 'Arm L', 'Taille', 'Dij L', 'Kuit L'],
      ['Borst', 'Arm R', 'Heupen', 'Dij R', 'Kuit R'],
    ]) {
      for (var i = 1; i < side.length; i++) {
        expect(rect(side[i]).top, greaterThan(rect(side[i - 1]).bottom));
      }
    }
    // The value stays whole on the right edge of the screen.
    expect(rect('46,5 cm').right, lessThanOrEqualTo(360));
  });
}
