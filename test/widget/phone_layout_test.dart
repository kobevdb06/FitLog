import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/health/presentation/health_overview_screen.dart';
import 'package:fitlog/features/health/presentation/heart_rate_week_screen.dart';
import 'package:fitlog/features/health/presentation/steps_week_screen.dart';
import 'package:fitlog/features/morning/domain/morning_facts.dart';
import 'package:fitlog/features/morning/presentation/morning_report_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The screens as they look on a real phone: about 412 points wide, with the
/// text a little larger than the default, as many people set it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
    );
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpPhone(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(
        container,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(412, 2400),
            textScaler: TextScaler.linear(1.15),
          ),
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The tops of these texts, to see they sit on one line.
  List<double> tops(WidgetTester tester, List<String> texts) => [
    // The first: the same number can stand in a list further down.
    for (final text in texts) tester.getTopLeft(find.text(text).first).dy,
  ];

  testWidgets('de rapportkaart past, met beide knoppen', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(
      () => db.reportsDao.saveReport(
        day: now,
        createdAt: now,
        facts: jsonEncode(
          MorningFacts(
            day: DateTime(now.year, now.month, now.day),
            score: 100,
          ).toJson(),
        ),
        coachText: 'Een rapport.',
      ),
    );
    await pumpPhone(
      tester,
      const Scaffold(body: SingleChildScrollView(child: MorningReportCard())),
    );

    expect(tester.takeException(), isNull);
    for (final label in ['Alle rapporten', 'Opnieuw opstellen']) {
      final right = tester.getBottomRight(find.text(label)).dx;
      expect(
        right,
        lessThanOrEqualTo(412),
        reason: '$label valt van het scherm',
      );
    }
  });

  testWidgets('op Gezondheid staan de getallen op één lijn', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await db.recoveryDao.setSleep(
        fellAsleepAt: today.subtract(const Duration(minutes: 30)),
        wokeAt: today.add(const Duration(hours: 9, minutes: 40)),
      );
      await db.healthDao.setSteps(today, 3249);
    });
    await pumpPhone(tester, HealthOverviewScreen(now: now));

    final sleep = tops(tester, ['100', '10 u 10']);
    expect(sleep[0], sleep[1]);
    // Vandaag en het gemiddelde zijn hier allebei 3.249.
    final steps = find.text('3.249');
    expect(
      tester.getTopLeft(steps.at(0)).dy,
      tester.getTopLeft(steps.at(1)).dy,
    );
  });

  testWidgets('bij de stappen raken de labels elkaar niet', (tester) async {
    await tester.runAsync(() async {
      await db.healthDao.setSteps(DateTime(2026, 10, 1), 6775);
      await db.healthDao.setSteps(DateTime(2026, 10, 3), 9600);
    });
    await pumpPhone(tester, StepsWeekScreen(now: DateTime(2026, 10, 4, 21)));

    final average = tester.getBottomRight(find.text('Gemiddeld per dag')).dx;
    final best = tester.getTopLeft(find.text('Beste dag')).dx;
    expect(best - average, greaterThanOrEqualTo(8));
    final values = tops(tester, ['16.375', '8.188', '9.600']);
    expect(values.toSet(), hasLength(1));
  });

  testWidgets('bij de hartslag ook', (tester) async {
    await tester.runAsync(
      () => db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: 'w1',
              name: 'Leg day',
              startedAt: DateTime(2026, 9, 30, 18).millisecondsSinceEpoch,
              endedAt: Value(DateTime(2026, 9, 30, 19).millisecondsSinceEpoch),
              avgHeartRate: const Value(116),
              maxHeartRate: const Value(150),
            ),
          ),
    );
    await pumpPhone(
      tester,
      HeartRateWeekScreen(now: DateTime(2026, 10, 4, 21)),
    );

    final values = tops(tester, ['116 bpm', '150 bpm', '1']);
    expect(values.toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
