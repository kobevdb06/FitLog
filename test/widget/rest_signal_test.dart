import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/workout/presentation/rest_timer_bar.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The end of a rest, said once, wherever you are in the app (DECISIONS 285).
///
/// The sound came from the rest bar, and the bar gives way to the keypad:
/// typing your weights, you heard nothing. And the notification for when
/// the app is out of sight went off as well, on top of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late List<String> sounds;
  late _Notices notices;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sounds = [];
    notices = _Notices();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemSound.play') {
            sounds.add('${call.arguments}');
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await db.close();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        restNoticesProvider.overrideWithValue(notices),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('the end of a rest sounds once, also with no bar in sight', (
    tester,
  ) async {
    final c = container();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: RestSignal(child: SizedBox())),
      ),
    );
    await c.read(restTimerProvider.notifier).start(seconds: 1);
    // The rest is measured on the real clock: let a real second go by, then
    // the signal's own timer.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    expect(sounds, hasLength(1));
    expect(c.read(restTimerProvider).finishedHandled, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  test('the notification is for when FitLog is out of sight', () async {
    final c = container();
    final rest = c.read(restTimerProvider.notifier);

    await rest.start(seconds: 90);
    expect(notices.scheduled, 0, reason: 'in sight: the app says it');

    await rest.background();
    expect(notices.scheduled, 1);

    await rest.foreground();
    expect(notices.cancelled, greaterThanOrEqualTo(1));

    await rest.background();
    await rest.start(seconds: 60);
    expect(notices.scheduled, 3, reason: 'ticked off from the notification');
  });
}

class _Notices implements RestNotices {
  int scheduled = 0;
  int cancelled = 0;

  @override
  Future<void> schedule({
    required DateTime endsAt,
    required String exerciseName,
    required bool withSound,
  }) async => scheduled++;

  @override
  Future<void> cancel() async => cancelled++;
}
