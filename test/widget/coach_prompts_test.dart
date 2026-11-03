import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/prompts/domain/coach_moments.dart';
import 'package:fitlog/features/prompts/presentation/coach_prompts_screen.dart';
import 'package:fitlog/features/workout/presentation/workout_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

/// Geplande prompts on screen: the answer on the summary, asked once, and
/// the settings that say what is asked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late int asked;

  AiClient client(String apiKey, CoachProvider provider) => AiClient(
    apiKey: apiKey,
    provider: provider,
    client: MockClient((request) async {
      asked++;
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Je laatste set zakte weg: neem 2,5 kg minder.'},
                ],
              },
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 900,
            'candidatesTokenCount': 30,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  ProviderContainer containerFor() {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        coachClientFactoryProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A finished session with one ticked-off set of bench presses.
  Future<String> finished() async {
    final id = await db.workoutsDao.startWorkout(
      name: 'Push',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(id, ['ex-bench'], defaultRestSeconds: 90);
    final set = (await db.workoutsDao.getWorkoutDetail(id))!
        .exercises
        .single
        .sets
        .single;
    await db.workoutsDao.updateSet(
      set.id,
      weightKg: const Value(80),
      reps: const Value(6),
      isCompleted: const Value(true),
    );
    await db.workoutsDao.finishWorkout(id, discardPending: false);
    return id;
  }

  Future<void> pumpSummary(WidgetTester tester, String workoutId) async {
    tester.view.physicalSize = const Size(1100, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(
        containerFor(),
        WorkoutSummaryScreen(workoutId: workoutId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    asked = 0;
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bankdrukken',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() => db.close());

  group('de samenvatting', () {
    setUp(() => db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg'));

    testWidgets('met de prompt aan staat het antwoord erop, één keer '
        'gevraagd, ook als je de samenvatting opnieuw opent', (tester) async {
      await db.coachPromptsDao.savePrompt(
        moment: CoachMoment.workout,
        enabled: true,
        prompt: 'Geef een kritische mening over mijn workout.',
      );
      final id = await tester.runAsync(finished);

      await pumpSummary(tester, id!);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Je laatste set zakte weg: neem 2,5 kg minder.'),
        findsOneWidget,
      );
      expect(
        find.text('Jouw prompt: Geef een kritische mening over mijn workout.'),
        findsOneWidget,
      );
      expect(find.text('Verder vragen'), findsOneWidget);

      await pumpSummary(tester, id);
      expect(
        find.text('Je laatste set zakte weg: neem 2,5 kg minder.'),
        findsOneWidget,
      );
      expect(asked, 1);

      // Unmounted here, so what the providers schedule on the way out runs
      // inside the test.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('met de prompt uit staat er niets van de coach, en wordt er '
        'niets gevraagd', (tester) async {
      final id = await tester.runAsync(finished);

      await pumpSummary(tester, id!);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Coach'), findsNothing);
      expect(asked, 0);
    });
  });

  testWidgets('de lijst toont de drie momenten: het ochtendrapport en het '
      'weekoverzicht aan, na je workout uit', (tester) async {
    await tester.pumpWidget(
      wrapWithContainer(containerFor(), const CoachPromptsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (final title in ['Na je workout', 'Ochtendrapport', 'Weekoverzicht']) {
      expect(find.text(title), findsOneWidget);
    }
    final switches = tester
        .widgetList<Switch>(find.byType(Switch))
        .map((s) => s.value);
    expect(switches, [false, true, true]);
  });

  testWidgets('een voorbeeld vult de prompt in en wordt bewaard; De gewone '
      'zet hem terug', (tester) async {
    tester.view.physicalSize = const Size(1100, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(
        containerFor(),
        const MomentPromptScreen(wire: 'workout'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final kritisch = CoachMoment.workout.examples.first;
    await tester.tap(find.text(kritisch.label));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      (await tester.runAsync(
        () => db.coachPromptsDao.promptRow(CoachMoment.workout),
      ))!.prompt,
      kritisch.prompt,
    );

    await tester.tap(find.text('De gewone'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      (await tester.runAsync(
        () => db.coachPromptsDao.promptRow(CoachMoment.workout),
      ))!.prompt,
      isNull,
    );
    expect(find.text(CoachMoment.workout.defaultPrompt), findsWidgets);
  });

  testWidgets('wat je typt wordt bewaard, en de lengte ook', (tester) async {
    tester.view.physicalSize = const Size(1100, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(
        containerFor(),
        const MomentPromptScreen(wire: 'morning'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), 'Eén zin: trainen of niet.');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Lang'));
    await tester.pump(const Duration(milliseconds: 100));

    final row = await tester.runAsync(
      () => db.coachPromptsDao.promptRow(CoachMoment.morning),
    );
    expect(row!.prompt, 'Eén zin: trainen of niet.');
    expect(row.length, AnswerLength.long.wire);
    expect(row.enabled, isTrue);
  });
}
