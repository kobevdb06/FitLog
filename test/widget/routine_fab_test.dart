import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/routines/presentation/routine_detail_screen.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The button that turns into the other button.
///
/// The routines tab has "Routine toevoegen" and a routine has "Start workout",
/// both floating in the same corner, so Flutter flies one into the other as
/// you move between them. That only works if both exist when the movement
/// starts - and this one used to wait for the routine to be read from the
/// database, by which time the arriving page had already covered the other.
/// Going back always looked right, because by then both were there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late String routineId;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    routineId = await db.routinesDao.createRoutine(
      const RoutineDraft(name: 'Push', exercises: []),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpDetail(WidgetTester tester, String id) async {
    await tester.pumpWidget(
      wrapWithContainer(container, RoutineDetailScreen(routineId: id)),
    );
  }

  testWidgets('it is there while the routine is still being read', (
    tester,
  ) async {
    // Held in the loading state on purpose: in a test the database answers
    // before the first assertion, and this is exactly the moment that broke.
    final loading = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        routineDetailProvider(
          routineId,
        ).overrideWith((ref) => const Stream<RoutineDetail?>.empty()),
      ],
    );
    addTearDown(loading.dispose);

    await tester.pumpWidget(
      wrapWithContainer(loading, RoutineDetailScreen(routineId: routineId)),
    );
    await tester.pump();

    expect(find.text('Start workout'), findsOneWidget);
  });

  testWidgets('and stays once the routine has been read', (tester) async {
    await pumpDetail(tester, routineId);
    await tester.pumpAndSettle();

    expect(find.text('Start workout'), findsOneWidget);
  });

  testWidgets('but not for a routine that is gone', (tester) async {
    await pumpDetail(tester, 'bestaat-niet');
    await tester.pumpAndSettle();

    expect(find.text('Routine niet gevonden'), findsOneWidget);
    expect(
      find.text('Start workout'),
      findsNothing,
      reason: 'er valt niets te starten',
    );
  });
}
