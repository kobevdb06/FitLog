import 'dart:convert';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/chat/presentation/coach_screen.dart';
import 'package:fitlog/features/review/presentation/week_review_screen.dart';
import 'package:fitlog/routing/routes.dart';
import 'package:fitlog/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The coach on the weekly review: writing about a week, and handing what it
/// suggests to the coach in the chat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late List<String> sent;
  ProviderContainer? container;

  // Een week die voorbij is.
  final monday = DateTime(2026, 9, 28);

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appControllerProvider.overrideWith(() => _Ready(db)),
        coachClientFactoryProvider.overrideWithValue(
          (apiKey, provider) => AiClient(
            apiKey: apiKey,
            provider: provider,
            client: MockClient((request) async {
              sent.add(request.body);
              return http.Response(
                jsonEncode({
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {
                            'text':
                                'Rustige week. Volgende week: twee keer '
                                'trainen in plaats van één.',
                          },
                        ],
                      },
                    },
                  ],
                  'usageMetadata': {
                    'promptTokenCount': 600,
                    'candidatesTokenCount': 30,
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp.router(
          routerConfig: container!.read(routerProvider),
          theme: AppTheme.dark,
          locale: const Locale('nl'),
          supportedLocales: const [Locale('nl')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openWeek(WidgetTester tester) async {
    container!.read(routerProvider).push(Routes.weekReviewOf(monday));
    await tester.pumpAndSettle();
  }

  testWidgets('zonder sleutel geen coach op het weekoverzicht', (tester) async {
    await pumpApp(tester);
    await openWeek(tester);

    expect(find.byType(WeekReviewScreen), findsOneWidget);
    expect(find.text('28/9 – 4/10'), findsOneWidget);
    expect(find.text('De coach over je week'), findsNothing);
  });

  testWidgets('de coach schrijft op vraag, en zijn voorstel gaat naar de '
      'chat zonder te versturen', (tester) async {
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    // Iets in die week, anders is ze leeg.
    await db.recoveryDao.setSleep(
      fellAsleepAt: DateTime(2026, 9, 29, 23),
      wokeAt: DateTime(2026, 9, 30, 7),
    );
    await pumpApp(tester);
    await openWeek(tester);

    await tester.tap(find.text('Laat de coach erover schrijven'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(find.textContaining('Rustige week.'), findsOneWidget);

    await tester.tap(find.text('Laat de coach het aanpassen'));
    await tester.pumpAndSettle();

    expect(find.byType(CoachScreen), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(CoachScreen),
        matching: find.byType(TextField),
      ),
    );
    expect(
      field.controller!.text,
      'In mijn weekoverzicht van 28/9 – 4/10 schreef je: "Volgende week: '
      'twee keer trainen in plaats van één." Pas mijn routines in de map '
      'Coach daarop aan.',
    );
    // Klaargezet, niet verstuurd.
    expect(sent, hasLength(1));
  });
}

/// An app that is open and unlocked, so the shell is what the router shows.
class _Ready extends AppController {
  _Ready(this._db);

  final AppDatabase _db;

  @override
  AppState build() => AppReady(
    db: _db,
    security: const SecurityStatus(
      initialised: true,
      mode: LockMode.none,
      biometricEnabled: false,
      hasRecoveryPhrase: false,
      consecutiveFailures: 0,
      lastFailureAt: null,
    ),
  );
}
