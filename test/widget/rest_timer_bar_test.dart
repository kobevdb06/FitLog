import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/features/workout/domain/rest_timer.dart';
import 'package:fitlog/features/workout/presentation/rest_timer_bar.dart';
import 'package:fitlog/features/workout/presentation/rest_timer_screen.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A rest that started [ago] and lasts 90 seconds.
class _StartedAgo extends RestTimer {
  _StartedAgo(this.ago);

  final Duration ago;

  @override
  RestTimerState build() => RestTimerState.start(
    seconds: 90,
    from: DateTime.now().subtract(ago),
    exerciseName: 'Bankdrukken',
  );
}

/// The bar under the sets once the rest is over: it says so, and then it goes.
///
/// It used to stay until the next set was ticked off, with -15 and +15 still
/// beside "Rust voorbij" although there was nothing left to shorten or
/// lengthen.
void main() {
  setUpAll(initialiseTestLocale);

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
  });

  Future<ProviderContainer> pumpBar(WidgetTester tester, Duration ago) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        restTimerProvider.overrideWith(() => _StartedAgo(ago)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      wrapWithContainer(
        container,
        const Scaffold(bottomNavigationBar: RestTimerBar()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('while resting, the time can be shortened or lengthened', (
    tester,
  ) async {
    await pumpBar(tester, const Duration(seconds: 10));

    expect(find.text('-15'), findsOneWidget);
    expect(find.text('+15'), findsOneWidget);
    expect(find.byTooltip('Overslaan'), findsOneWidget);
  });

  testWidgets('once it is over, only closing it is left', (tester) async {
    final container = await pumpBar(tester, const Duration(seconds: 95));

    expect(find.text('Rust voorbij'), findsOneWidget);
    expect(find.text('-15'), findsNothing);
    expect(find.text('+15'), findsNothing);

    await tester.tap(find.byTooltip('Sluiten'));
    await tester.pump();

    expect(container.read(restTimerProvider).isActive, isFalse);
    expect(find.text('Rust voorbij'), findsNothing);
  });

  testWidgets('and half a minute after, it goes by itself', (tester) async {
    final container = await pumpBar(tester, const Duration(seconds: 125));

    // One tick of the bar's clock.
    await tester.pump(const Duration(milliseconds: 600));

    expect(container.read(restTimerProvider).isActive, isFalse);
    expect(find.text('Rust voorbij'), findsNothing);
  });

  testWidgets('but not before', (tester) async {
    final container = await pumpBar(tester, const Duration(seconds: 100));

    await tester.pump(const Duration(milliseconds: 600));

    expect(container.read(restTimerProvider).isActive, isTrue);
    expect(find.text('Rust voorbij'), findsOneWidget);
  });

  group('the full screen', () {
    /// A page with the full screen on top of it, as the bar opens it.
    Future<ProviderContainer> pumpScreen(
      WidgetTester tester,
      Duration ago,
    ) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          restTimerProvider.overrideWith(() => _StartedAgo(ago)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        wrapWithContainer(
          container,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RestTimerScreen(),
                    ),
                  ),
                  child: const Text('De workout'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('De workout'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('once it is over, only going back is left', (tester) async {
      await pumpScreen(tester, const Duration(seconds: 95));

      expect(find.text('-15 s'), findsNothing);
      expect(find.text('+15 s'), findsNothing);
      expect(find.text('Overslaan'), findsNothing);

      await tester.tap(find.text('Terug naar je workout'));
      await tester.pumpAndSettle();

      expect(find.byType(RestTimerScreen), findsNothing);
      expect(find.text('De workout'), findsOneWidget);
    });

    testWidgets('put away while it is open, it closes instead of going blank', (
      tester,
    ) async {
      final container = await pumpScreen(tester, const Duration(seconds: 95));

      container.read(restTimerProvider.notifier).dismiss();
      await tester.pumpAndSettle();

      expect(find.text('Geen rusttimer'), findsNothing);
      expect(find.text('De workout'), findsOneWidget);
    });

    testWidgets('skipping closes it once, not the page under it too', (
      tester,
    ) async {
      await pumpScreen(tester, const Duration(seconds: 10));

      await tester.tap(find.text('Overslaan'));
      await tester.pumpAndSettle();

      expect(find.byType(RestTimerScreen), findsNothing);
      expect(find.text('De workout'), findsOneWidget);
    });
  });
}
