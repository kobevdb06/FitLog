import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/chat/presentation/coach_session.dart';
import 'package:fitlog/features/workout/presentation/workout_coach.dart';
import 'package:fitlog/features/workout/presentation/workout_live_update.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The coach as the panel over another app reaches it: through the running
/// app, behind the PIN, into a conversation of its own per workout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late List<String> sent;
  late List<Map<String, Object?>> events;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
    events = [];
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
        workoutNoticePosterProvider.overrideWithValue(_Poster()),
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
                        'role': 'model',
                        'parts': [
                          {'text': 'Ja, probeer 82,5 kg.'},
                        ],
                      },
                    },
                  ],
                  'usageMetadata': {
                    'promptTokenCount': 900,
                    'candidatesTokenCount': 9,
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
    container.listen(workoutLiveUpdateProvider, (_, _) {});
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bench Press',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  WorkoutCoach coach() => container.read(workoutCoachProvider);

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> startBench() async {
    final controller = container.read(workoutControllerProvider);
    final id = await controller.startEmpty(name: 'Push A');
    await controller.addExercises(id, ['ex-bench']);
    final set = (await db.workoutsDao.getWorkoutDetail(id))!
        .exercises
        .single
        .sets
        .single;
    await controller.updateSetValues(
      set.id,
      weightKg: const Value(80),
      reps: const Value(8),
    );
    await settle();
  }

  Future<void> setPin(String pin) => container
      .read(keyManagerProvider)
      .setPin(dek: Uint8List.fromList(List.filled(32, 7)), pin: pin);

  test('zonder sleutel staat de coach uit', () async {
    final state = await coach().state();

    expect(state['available'], isFalse);
  });

  test('zonder pincode vraagt hij er geen', () async {
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');

    final state = await coach().state();

    expect(state['available'], isTrue);
    expect(state['locked'], isFalse);
  });

  test('met een pincode eerst die, ook al is de app open', () async {
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    await setPin('246810');

    expect((await coach().state())['locked'], isTrue);
    final refused = await coach().ask('Mag ik zwaarder?', send: events.add);
    expect(refused['locked'], isTrue);
    expect(sent, isEmpty, reason: 'nothing leaves before the PIN');

    expect((await coach().unlock(pin: '111111'))['ok'], isFalse);
    expect((await coach().unlock(pin: '246810'))['ok'], isTrue);
    expect((await coach().state())['locked'], isFalse);
  });

  test('een fout geeft de wachttijd van het slotscherm', () async {
    await setPin('246810');

    await coach().unlock(pin: '000000');
    await coach().unlock(pin: '000000');
    final third = await coach().unlock(pin: '000000');

    // Three wrong ones in a row: the lock screen waits too.
    expect(third['ok'], isFalse);
    expect(third['lockoutSeconds'], isA<int>());
  });

  test('de vraag gaat met de set erbij, het antwoord komt door en blijft '
      'bewaard', () async {
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    await startBench();

    expect(
      (await coach().state())['about'],
      'Bench Press · Set 1 van 1 · 80 kg × 8',
    );

    final answer = await coach().ask('Mag ik zwaarder?', send: events.add);

    expect(answer['ok'], isTrue);
    expect(events.last['type'], 'done');
    expect(events.last['text'], 'Ja, probeer 82,5 kg.');
    // The set is told to the coach, not stored with the question.
    expect(sent.single, contains('midden in een training'));
    expect(sent.single, contains('Bench Press'));
    final threads = await db.chatDao.watchThreads().first;
    final messages = await db.chatDao.messages(threads.single.id);
    expect(messages.map((m) => m.content), [
      'Mag ik zwaarder?',
      'Ja, probeer 82,5 kg.',
    ]);

    // A second question in the same workout goes on in the same thread.
    await coach().ask('En daarna?', send: events.add);
    expect(await db.chatDao.watchThreads().first, hasLength(1));
    expect((await coach().state())['thread'], hasLength(4));
  });

  test('het gesprek hoort bij de workout: na een herstart gaat het verder, '
      'en de Chat-tab schrijft erin', () async {
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    await startBench();
    await coach().ask('Mag ik zwaarder?', send: events.add);

    // Android closed FitLog: the panel starts with a coach of its own,
    // which knows nothing it was told before.
    container.invalidate(workoutCoachProvider);
    expect((await coach().state())['thread'], hasLength(2));

    // The Chat tab is on the same conversation, and a question there shows
    // in the panel.
    final session = container.read(coachSessionControllerProvider.notifier);
    container.listen(coachSessionControllerProvider, (_, _) {});
    await settle();
    final thread = await session.threadFor('Hoeveel rust?');
    final threads = await db.chatDao.watchThreads().first;
    expect(threads.single.id, thread);
    await container
        .read(coachControllerProvider.notifier)
        .ask(threadId: thread, question: 'Hoeveel rust?');
    expect((await coach().state())['thread'], hasLength(4));
    expect(threads.single.title, startsWith('Push A · '));
  });
}

class _Poster implements WorkoutNoticePoster {
  @override
  Future<void> show(notice, format) async {}

  @override
  Future<void> cancel() async {}
}
