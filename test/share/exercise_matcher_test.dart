import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/share/domain/exercise_matcher.dart';
import 'package:fitlog/features/share/domain/routine_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deciding whether your friend's "bench press" is the "Bench Press" you
/// already have. Getting this wrong in one direction leaves you with two of
/// everything; in the other it silently swaps your exercise for his.
void main() {
  ExerciseRow row({
    required String id,
    required String name,
    String muscle = 'borst',
    String category = 'barbell',
    bool custom = true,
  }) => ExerciseRow(
    id: id,
    name: name,
    primaryMuscle: muscle,
    secondaryMuscles: '[]',
    equipment: null,
    category: category,
    instructions: null,
    imageAsset: null,
    startImageFile: null,
    endImageFile: null,
    isCustom: custom,
    isArchived: false,
    createdAt: 0,
  );

  SharedExercise incoming({
    String? id,
    required String name,
    String muscle = 'borst',
    ExerciseCategory category = ExerciseCategory.barbell,
  }) => SharedExercise(
    id: id,
    name: name,
    primaryMuscle: muscle,
    category: category,
  );

  group('normalising a name', () {
    test('case and spacing do not matter', () {
      expect(normaliseExerciseName('  Bench   Press '), 'bench press');
    });

    test('punctuation does not matter', () {
      expect(normaliseExerciseName('Bench-Press!'), 'bench press');
    });

    test('accents do not matter', () {
      expect(normaliseExerciseName('Développé couché'), 'developpe couche');
    });

    test('an empty name stays empty', () {
      expect(normaliseExerciseName('---'), '');
    });
  });

  group('matching', () {
    final mine = [
      row(id: 'cat-bench', name: 'Bench Press', custom: false),
      row(id: 'own-curl', name: 'Kabel curl schuin', muscle: 'biceps',
          category: 'cable'),
    ];

    test('the same id is the same exercise', () {
      final match = matchSharedExercise(
        incoming(id: 'cat-bench', name: 'Iets heel anders'),
        mine,
      );
      expect(match.kind, ExerciseMatchKind.sameId);
      expect(match.existing!.id, 'cat-bench');
    });

    test('the same name in other letters is the same exercise', () {
      final match = matchSharedExercise(incoming(name: 'bench press'), mine);
      expect(match.kind, ExerciseMatchKind.sameName);
      expect(match.existing!.id, 'cat-bench');
    });

    test('a name with a suffix is proposed', () {
      final match = matchSharedExercise(
        incoming(name: 'Bench Press barbell'),
        mine,
      );
      expect(match.kind, ExerciseMatchKind.similar);
      expect(match.existing!.id, 'cat-bench');
    });

    test('a typo is proposed', () {
      final match = matchSharedExercise(incoming(name: 'Bench Pres'), mine);
      expect(match.kind, ExerciseMatchKind.similar);
    });

    test('another muscle is another exercise', () {
      final match = matchSharedExercise(
        incoming(name: 'Bench Pres', muscle: 'triceps'),
        mine,
      );
      expect(match.kind, ExerciseMatchKind.none);
    });

    test('another category is another exercise', () {
      final match = matchSharedExercise(
        incoming(name: 'Bench Pres', category: ExerciseCategory.dumbbell),
        mine,
      );
      expect(
        match.kind,
        ExerciseMatchKind.none,
        reason: 'a dumbbell press is not a barbell press',
      );
    });

    test('the same name still wins over a different category', () {
      // The name being identical is a stronger signal than the category
      // agreeing: people fill that field in differently.
      final match = matchSharedExercise(
        incoming(name: 'Bench Press', category: ExerciseCategory.machine),
        mine,
      );
      expect(match.kind, ExerciseMatchKind.sameName);
    });

    test('something genuinely new is new', () {
      final match = matchSharedExercise(
        incoming(name: 'Zercher squat', muscle: 'quadriceps'),
        mine,
      );
      expect(match.kind, ExerciseMatchKind.none);
      expect(match.existing, isNull);
      expect(match.linksByDefault, isFalse);
    });

    test('an empty catalogue matches nothing', () {
      final match = matchSharedExercise(incoming(name: 'Bench Press'), const []);
      expect(match.kind, ExerciseMatchKind.none);
    });
  });

  group('typing a name yourself', () {
    final mine = [row(id: 'own-1', name: 'Bench Press')];

    test('an exercise is not a duplicate of itself', () {
      final match = matchExerciseByName(
        name: 'Bench Press',
        primaryMuscle: 'borst',
        category: ExerciseCategory.barbell,
        mine: mine,
        ignoreId: 'own-1',
      );
      expect(match.kind, ExerciseMatchKind.none);
    });

    test('but it is a duplicate of another one', () {
      final match = matchExerciseByName(
        name: 'bench press',
        primaryMuscle: 'borst',
        category: ExerciseCategory.barbell,
        mine: mine,
      );
      expect(match.kind, ExerciseMatchKind.sameName);
    });

    test('a blank name matches nothing', () {
      final match = matchExerciseByName(
        name: '  ',
        primaryMuscle: 'borst',
        category: ExerciseCategory.barbell,
        mine: mine,
      );
      expect(match.kind, ExerciseMatchKind.none);
    });
  });
}
