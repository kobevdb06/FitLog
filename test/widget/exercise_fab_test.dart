import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/providers/core_providers.dart';
import 'package:fitlog/core/widgets/exercise_image.dart';
import 'package:fitlog/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The button that turns into the other button, on the exercise page.
///
/// Same story as `routine_fab_test.dart`: a routine has "Start workout" and an
/// exercise has "PR-poging", both floating in the same corner, so Flutter flies
/// one into the other as you move between them. That only works if both exist
/// when the movement starts, and this one used to sit inside the branch that
/// waits for the exercise to be read - so the arriving page landed without it
/// and the button popped in a frame later instead of moving.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  List<Override> overrides({List<Override> extra = const []}) => [
    databaseProvider.overrideWithValue(db),
    exerciseImagesProvider.overrideWith(
      (ref) => const ExerciseImageManifest(
        format: 'webp',
        animated: {},
        staticOnly: {},
        withoutImages: {'ex-bench'},
      ),
    ),
    ...extra,
  ];

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);

    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Barbell Bench Press',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('it is there while the exercise is still being read', (
    tester,
  ) async {
    // Held in the loading state on purpose: in a test the database answers
    // before the first assertion, and this is exactly the moment that broke.
    final loading = ProviderContainer(
      overrides: overrides(
        extra: [
          exerciseByIdProvider('ex-bench')
              .overrideWith((ref) => const Stream<ExerciseRow?>.empty()),
        ],
      ),
    );
    addTearDown(loading.dispose);

    await tester.pumpWidget(
      wrapWithContainer(
        loading,
        const ExerciseDetailScreen(exerciseId: 'ex-bench'),
      ),
    );
    await tester.pump();

    expect(find.text('PR-poging'), findsOneWidget);
  });

  testWidgets('and stays once the exercise has been read', (tester) async {
    await tester.pumpWidget(
      wrapWithContainer(
        container,
        const ExerciseDetailScreen(exerciseId: 'ex-bench'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PR-poging'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsWidgets);
  });

  testWidgets('but not for an exercise that is gone', (tester) async {
    await tester.pumpWidget(
      wrapWithContainer(
        container,
        const ExerciseDetailScreen(exerciseId: 'bestaat-niet'),
      ),
    );
    await tester.pump();
    // Long enough for the Scaffold to finish taking the button away again: it
    // fades one out over a couple of hundred milliseconds rather than dropping
    // it, so a shorter wait would still find it on its way out.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Oefening niet gevonden'), findsOneWidget);
    expect(
      find.text('PR-poging'),
      findsNothing,
      reason: 'er valt geen record te vestigen op iets dat niet bestaat',
    );
  });
}
