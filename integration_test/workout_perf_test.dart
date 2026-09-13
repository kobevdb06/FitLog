/// Hoe duur het workoutscherm is om te tonen, gemeten op een echt toestel.
///
/// Een widgettest heeft geen rasterthread en zegt dus niets over haperen. Dit
/// draait op een emulator of telefoon en telt de frames die over hun budget
/// gingen terwijl de pagina naar binnen schuift.
///
/// De app wordt niet echt opgestart: er is geen onboarding, geen slot en geen
/// bestand op schijf. Wat gemeten wordt is het scherm zelf, met dezelfde
/// overgang als in de app.
///
/// Draaien:
///   flutter drive --driver=test_driver/integration_test.dart
///     --target=integration_test/workout_perf_test.dart -d DEVICE --profile
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/providers/core_providers.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/core/widgets/exercise_image.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Eén frame van 60 Hz.
const double kBudgetMs = 16.7;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final frames = <FrameTiming>[];
  double ms(Duration d) => d.inMicroseconds / 1000;

  Map<String, Object> samenvatting(int vanaf) {
    final stuk = frames.sublist(vanaf.clamp(0, frames.length));
    if (stuk.isEmpty) return {'frames': 0};
    double grootste(double Function(FrameTiming) f) =>
        stuk.map(f).reduce((a, b) => a > b ? a : b);

    return {
      'frames': stuk.length,
      'teTraag': stuk.where((f) => ms(f.totalSpan) > kBudgetMs).length,
      'ergsteTotaal': grootste((f) => ms(f.totalSpan)).toStringAsFixed(1),
      'ergsteBuild': grootste((f) => ms(f.buildDuration)).toStringAsFixed(1),
      'ergsteRaster': grootste((f) => ms(f.rasterDuration)).toStringAsFixed(1),
    };
  }

  Future<void> rust(WidgetTester tester, [int seconden = 2]) async {
    for (var i = 0; i < seconden * 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<Map<String, Object>> meetMet(
    WidgetTester tester,
    int aantal, {
    bool spoor = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.settingsDao.ensureInitialized();
    for (var i = 0; i < aantal; i++) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-$i',
              name: 'Oefening $i',
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }

    // Een eerdere sessie, zodat de "vorige"-kolom echt werk te doen heeft.
    final oud = await db.workoutsDao.startWorkout(
      name: 'Vorige keer',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(oud, [
      for (var i = 0; i < aantal; i++) 'ex-$i',
    ], defaultRestSeconds: 90);
    final oudeDetail = (await db.workoutsDao.getWorkoutDetail(oud))!;
    for (final oefening in oudeDetail.exercises) {
      for (final set in oefening.sets) {
        await db.workoutsDao.updateSet(
          set.id,
          weightKg: const Value(100),
          reps: const Value(8),
          isCompleted: const Value(true),
        );
      }
    }
    await db.workoutsDao.finishWorkout(oud, discardPending: true);

    final nieuw = await db.workoutsDao.startWorkout(
      name: 'Chest day',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(nieuw, [
      for (var i = 0; i < aantal; i++) 'ex-$i',
    ], defaultRestSeconds: 90);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        exerciseImagesProvider.overrideWith(
          (ref) => ExerciseImageManifest(
            format: 'webp',
            animated: const {},
            staticOnly: const {},
            withoutImages: {for (var i = 0; i < aantal; i++) 'ex-$i'},
          ),
        ),
      ],
    );

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.dark,
          locale: const Locale('nl'),
          supportedLocales: const [Locale('nl')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: Center(child: Text('start'))),
        ),
      ),
    );
    await rust(tester, 2);

    // --- de overgang naar de workout --------------------------------------
    final voorOpenen = frames.length;
    if (spoor) {
      // Elke widget die gebouwd wordt komt als eigen gebeurtenis in de
      // tijdlijn te staan. Alleen aanzetten wanneer we willen weten waar de
      // tijd heen gaat: het kost zelf ook wat.
      debugProfileBuildsEnabled = true;
      await binding.traceAction(() async {
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (context) => const ActiveWorkoutScreen(),
            ),
          ),
        );
        await rust(tester, 3);
      }, reportKey: 'tijdlijn');
      debugProfileBuildsEnabled = false;
    } else {
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (context) => const ActiveWorkoutScreen(),
          ),
        ),
      );
      await rust(tester, 3);
    }
    final openen = samenvatting(voorOpenen);

    // --- een set afvinken --------------------------------------------------
    final voorVinken = frames.length;
    final vinkjes = find.byIcon(Icons.check);
    if (vinkjes.evaluate().isNotEmpty) {
      await tester.tap(vinkjes.first, warnIfMissed: false);
      await rust(tester, 2);
    }
    final vinken = samenvatting(voorVinken);

    // --- een seconde stilstaan, waarin de klok tikt ------------------------
    final voorStil = frames.length;
    await rust(tester, 3);
    final stil = samenvatting(voorStil);

    // Het scherm eerst weg, dan pas de container: de rusttimerbalk heeft een
    // eigen timer die anders nog een keer afgaat op een opgeruimde container.
    await tester.pumpWidget(const SizedBox.shrink());
    await rust(tester, 1);
    container.dispose();
    await db.close();

    return {
      'oefeningen': aantal,
      'openen': openen,
      'setAfvinken': vinken,
      'stilstaan': stil,
    };
  }

  testWidgets('een workout openen', (tester) async {
    Intl.defaultLocale = 'nl';
    await initializeDateFormatting('nl');
    SchedulerBinding.instance.addTimingsCallback(frames.addAll);

    final uitslagen = <Object>[];
    // De eerste meting is een opwarmronde: de allereerste keer dat een scherm
    // getoond wordt betaalt het voor van alles dat daarna warm is. Juist die
    // ronde wordt gevolgd, want daar zit de kost die we zoeken.
    uitslagen.add(await meetMet(tester, 4));
    await rust(tester, 1);
    for (final aantal in [0, 1, 4, 8]) {
      final uitslag = await meetMet(tester, aantal);
      uitslagen.add(uitslag);
      // Eén regel per meting: logcat kapt een lange regel af, en dan mist de
      // helft van de metingen zonder dat je het ziet.
      // ignore: avoid_print
      print('METING ${jsonEncode(uitslag["openen"])}');
      await rust(tester, 1);
    }

    // ignore: avoid_print
    print('UITSLAG ${jsonEncode(uitslagen)}');
    binding.reportData = {...?binding.reportData, 'metingen': uitslagen};
  });
}
