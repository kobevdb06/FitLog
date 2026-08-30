import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/share/data/routine_import.dart';
import 'package:fitlog/features/share/domain/routine_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';

import '../widget/helpers.dart';

/// Every routine came out "too large for one code". The sizing tests had used
/// exercises without instructions, and every catalogue exercise has several
/// hundred characters of them - eight of those are bigger than a QR code all
/// by themselves.
///
/// So these build the routine out of the real database instead of out of what
/// I imagined it looked like.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;

  final random = Random(7);

  /// Text that deflate can do nothing with, which is the honest worst case.
  String gibberish(int length) => String.fromCharCodes([
    for (var i = 0; i < length; i++) 97 + random.nextInt(26),
  ]);

  /// The median catalogue exercise carries about this much instruction text.
  final catalogueInstructions =
      'Lie down on the floor and secure your feet. Your legs should be bent '
              'at the knees. Place your hands behind or to the side of your '
              'head, and begin with your back on the ground. ' *
          4;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async => db.close());

  Future<String> exercise({
    required String id,
    required String name,
    bool custom = false,
    String? instructions,
  }) async {
    await db.exercisesDao.insertExercise(
      ExercisesTableCompanion.insert(
        id: id,
        name: name,
        primaryMuscle: 'borst',
        secondaryMuscles: const Value('["triceps","schouders"]'),
        equipment: const Value('dumbbell'),
        category: 'dumbbell',
        instructions: Value(instructions ?? catalogueInstructions),
        isCustom: Value(custom),
        createdAt: 0,
      ),
    );
    return id;
  }

  Future<String> routineOf(List<String> exerciseIds) {
    return db.routinesDao.createRoutine(
      RoutineDraft(
        name: 'Chest day',
        exercises: [
          for (final id in exerciseIds)
            RoutineExerciseDraft(
              exerciseId: id,
              restSeconds: 120,
              sets: const [
                RoutineSetDraft(setType: SetType.warmup),
                RoutineSetDraft(targetReps: 10),
                RoutineSetDraft(targetReps: 8),
                RoutineSetDraft(targetReps: 8),
              ],
            ),
        ],
      ),
    );
  }

  /// The version of QR code the payload ends up needing.
  int qrVersionFor(SharedRoutine routine) {
    final encoded = encodeRoutineForQr(routine);
    return QrCode(
      payload: QrPayload.fromString(base64Url.encode(encoded.bytes)),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    ).typeNumber;
  }

  test('a catalogue routine leaves its instructions at home', () async {
    final ids = [
      for (var i = 0; i < 8; i++)
        await exercise(id: 'cat-$i', name: 'Incline Dumbbell Press $i'),
    ];
    final routine = await sharedRoutineFor(db, await routineOf(ids));

    expect(
      routine.exercises.every((e) => e.instructions == null),
      isTrue,
      reason: 'the receiver already has them in their own catalogue',
    );
    expect(encodeRoutineForQr(routine).droppedText, isFalse);
    expect(qrVersionFor(routine), lessThanOrEqualTo(25));
  });

  test('the routine that was too big now fits', () async {
    final ids = [
      for (var i = 0; i < 5; i++)
        await exercise(id: 'cat-$i', name: 'Incline Dumbbell Press $i'),
      for (var i = 0; i < 3; i++)
        await exercise(
          id: 'own-$i',
          name: 'Eigen oefening $i',
          custom: true,
          instructions: 'Rustig zakken en gecontroleerd omhoog drukken.',
        ),
    ];
    final routine = await sharedRoutineFor(db, await routineOf(ids));

    final encoded = encodeRoutineForQr(routine);
    expect(encoded.bytes.length, lessThan(kQrPayloadBudget));
    expect(encoded.droppedText, isFalse);
  });

  test('an exercise of your own keeps its notes, up to a point', () async {
    final id = await exercise(
      id: 'own-1',
      name: 'Eigen oefening',
      custom: true,
      instructions: 'x' * 5000,
    );
    final routine = await sharedRoutineFor(db, await routineOf([id]));

    final instructions = routine.exercises.single.instructions!;
    expect(instructions.length, lessThanOrEqualTo(kSharedInstructionLimit + 1));
    expect(instructions, endsWith('…'));
  });

  test('too much text is dropped rather than refused', () async {
    // Twelve of the user's own exercises, each with the most text allowed.
    // The text has to be different every time: deflate makes nothing of the
    // same sentence twelve times over, which is exactly the mistake that let
    // the original sizing look fine.
    final ids = [
      for (var i = 0; i < 12; i++)
        await exercise(
          id: 'own-$i',
          name: 'Een eigen oefening met een lange naam $i',
          custom: true,
          instructions: gibberish(700),
        ),
    ];
    final routine = await sharedRoutineFor(db, await routineOf(ids));

    final encoded = encodeRoutineForQr(routine);
    expect(encoded.droppedText, isTrue);
    expect(encoded.bytes.length, lessThan(kQrPayloadBudget));

    // What was dropped is the text, never the training.
    final back = decodeRoutine(encoded.bytes);
    expect(back.exercises, hasLength(12));
    expect(back.exercises.first.sets, hasLength(4));
    expect(back.exercises.first.restSeconds, 120);
    expect(back.exercises.first.instructions, isNull);
  });

  test('a routine nothing can shrink says so', () {
    final huge = SharedRoutine(
      name: 'Onmogelijk',
      exercises: [
        for (var i = 0; i < kMaxSharedExercises; i++)
          SharedExercise(
            id: gibberish(36),
            name: gibberish(60),
            primaryMuscle: gibberish(20),
            secondaryMuscles: [gibberish(20), gibberish(20), gibberish(20)],
            equipment: gibberish(20),
            category: ExerciseCategory.machine,
            sets: [
              for (var j = 0; j < kMaxSharedSets; j++) SharedSet(reps: j),
            ],
          ),
      ],
    );

    expect(
      () => encodeRoutineForQr(huge),
      throwsA(isA<RoutineTooLargeException>()),
    );
  });
}
