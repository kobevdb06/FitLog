import 'dart:convert';
import 'dart:io';

import 'package:fitlog/core/db/enums.dart';
import 'package:fitlog/features/share/domain/routine_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bytes that end up in the QR code: small enough to scan, and strict
/// enough that a code from somewhere else cannot do anything strange.
void main() {
  SharedExercise exercise({
    String? id = 'cat-1',
    String name = 'Barbell Squat',
    String muscle = 'quadriceps',
    List<String> secondary = const ['bilspieren'],
    String? instructions,
    int sets = 3,
  }) => SharedExercise(
    id: id,
    name: name,
    primaryMuscle: muscle,
    secondaryMuscles: secondary,
    equipment: 'halterstang',
    category: ExerciseCategory.barbell,
    instructions: instructions,
    restSeconds: 120,
    supersetGroup: null,
    notes: 'rustig zakken',
    sets: [
      for (var i = 0; i < sets; i++)
        SharedSet(
          type: i == 0 ? SetType.warmup : SetType.normal,
          reps: 8 - i,
        ),
    ],
  );

  SharedRoutine routine({int count = 6, int custom = 0}) => SharedRoutine(
    name: 'Push A – vrijdag',
    notes: 'zwaar blok',
    exercises: [
      for (var i = 0; i < count; i++)
        exercise(
          id: i < custom ? null : 'cat-$i',
          name: 'Oefening nummer $i',
        ),
    ],
  );

  group('there and back', () {
    test('a routine survives the round trip', () {
      final original = routine(count: 3, custom: 1);

      final back = decodeRoutine(encodeRoutine(original));

      expect(back.name, original.name);
      expect(back.notes, original.notes);
      expect(back.exercises, hasLength(3));
      expect(back.customCount, 1);
    });

    test('every field of an exercise comes back', () {
      final back = decodeRoutine(
        encodeRoutine(
          SharedRoutine(
            name: 'Test',
            exercises: [exercise(instructions: 'Houd je rug recht.')],
          ),
        ),
      );

      final e = back.exercises.single;
      expect(e.id, 'cat-1');
      expect(e.name, 'Barbell Squat');
      expect(e.primaryMuscle, 'quadriceps');
      expect(e.secondaryMuscles, ['bilspieren']);
      expect(e.equipment, 'halterstang');
      expect(e.category, ExerciseCategory.barbell);
      expect(e.instructions, 'Houd je rug recht.');
      expect(e.restSeconds, 120);
      expect(e.notes, 'rustig zakken');
    });

    test('the sets keep their type and reps', () {
      final back = decodeRoutine(
        encodeRoutine(
          SharedRoutine(name: 'Test', exercises: [exercise(sets: 3)]),
        ),
      );

      final sets = back.exercises.single.sets;
      expect(sets.map((s) => s.type), [
        SetType.warmup,
        SetType.normal,
        SetType.normal,
      ]);
      expect(sets.map((s) => s.reps), [8, 7, 6]);
    });

    test('an exercise of your own travels without an id', () {
      final back = decodeRoutine(
        encodeRoutine(
          SharedRoutine(name: 'Test', exercises: [exercise(id: null)]),
        ),
      );
      expect(back.exercises.single.id, isNull);
    });
  });

  group('the size', () {
    /// What a QR code holds at medium error correction.
    const qrCapacity = 2331;

    test('an ordinary routine is a comfortable code', () {
      final bytes = encodeRoutine(routine(count: 8));
      expect(bytes.length, lessThan(qrCapacity ~/ 2));
    });

    test('a big one with its own exercises still fits', () {
      final long = 'Ga staan met de stang op je rug. ' * 8;
      final big = SharedRoutine(
        name: 'Alles',
        exercises: [
          for (var i = 0; i < 12; i++)
            exercise(
              id: i < 4 ? null : 'cat-$i',
              name: 'Een tamelijk lange oefeningsnaam $i',
              instructions: i < 4 ? long : null,
            ),
        ],
      );

      expect(encodeRoutine(big).length, lessThan(qrCapacity));
    });
  });

  group('a code we should not read', () {
    test('something that is not ours', () {
      expect(
        () => decodeRoutine(utf8.encode('https://example.com')),
        throwsA(isA<InvalidRoutineCodeException>()),
      );
    });

    test('too short to be anything', () {
      expect(
        () => decodeRoutine([0x46, 0x4c]),
        throwsA(isA<InvalidRoutineCodeException>()),
      );
    });

    test('a version we do not know', () {
      final bytes = encodeRoutine(routine(count: 1)).toList();
      bytes[2] = 99;
      expect(
        () => decodeRoutine(bytes),
        throwsA(
          isA<InvalidRoutineCodeException>().having(
            (e) => e.message,
            'message',
            contains('andere versie'),
          ),
        ),
      );
    });

    test('our header with rubbish behind it', () {
      expect(
        () => decodeRoutine([0x46, 0x4c, 0x01, 1, 2, 3, 4, 5]),
        throwsA(isA<InvalidRoutineCodeException>()),
      );
    });

    test('valid deflate that is not a routine', () {
      final body = zlib.encode(utf8.encode('"gewoon een string"'));
      expect(
        () => decodeRoutine([0x46, 0x4c, 0x01, ...body]),
        throwsA(isA<InvalidRoutineCodeException>()),
      );
    });

    test('a routine without exercises', () {
      final body = zlib.encode(utf8.encode(jsonEncode({'v': 1, 'e': []})));
      expect(
        () => decodeRoutine([0x46, 0x4c, 0x01, ...body]),
        throwsA(isA<InvalidRoutineCodeException>()),
      );
    });

    test('more exercises than anyone trains', () {
      final body = zlib.encode(
        utf8.encode(
          jsonEncode({
            'v': 1,
            'n': 'x',
            'e': [
              for (var i = 0; i < kMaxSharedExercises + 1; i++)
                {'n': 'x', 'm': 'borst', 'c': 'barbell', 's': <Object>[]},
            ],
          }),
        ),
      );
      expect(
        () => decodeRoutine([0x46, 0x4c, 0x01, ...body]),
        throwsA(isA<InvalidRoutineCodeException>()),
      );
    });

    test('more sets than anyone does', () {
      final body = zlib.encode(
        utf8.encode(
          jsonEncode({
            'v': 1,
            'n': 'x',
            'e': [
              {
                'n': 'x',
                'm': 'borst',
                'c': 'barbell',
                's': [
                  for (var i = 0; i < kMaxSharedSets + 1; i++) <String, Object>{},
                ],
              },
            ],
          }),
        ),
      );
      expect(
        () => decodeRoutine([0x46, 0x4c, 0x01, ...body]),
        throwsA(isA<InvalidRoutineCodeException>()),
      );
    });
  });

  group('what a strange code cannot do', () {
    Object? decodeField(Map<String, Object?> exercise) {
      final body = zlib.encode(
        utf8.encode(
          jsonEncode({
            'v': 1,
            'n': 'x',
            'e': [exercise],
          }),
        ),
      );
      return decodeRoutine([0x46, 0x4c, 0x01, ...body]).exercises.single;
    }

    test('a name of a megabyte is cut down', () {
      final e =
          decodeField({
                'n': 'x' * 100000,
                'm': 'borst',
                'c': 'barbell',
                's': <Object>[],
              })
              as SharedExercise;
      expect(e.name.length, kMaxSharedNameLength);
    });

    test('a rest of a year is clamped', () {
      final e =
          decodeField({
                'n': 'x',
                'm': 'borst',
                'c': 'barbell',
                'r': 999999999,
                's': <Object>[],
              })
              as SharedExercise;
      expect(e.restSeconds, 3600);
    });

    test('a category nobody has falls back', () {
      final e =
          decodeField({
                'n': 'x',
                'm': 'borst',
                'c': 'ruimteschip',
                's': <Object>[],
              })
              as SharedExercise;
      expect(e.category, ExerciseCategory.barbell);
    });

    test('numbers where text belongs do not throw', () {
      final e =
          decodeField({
                'n': 42,
                'm': false,
                'c': <String, Object>{},
                's': <Object>[],
              })
              as SharedExercise;
      expect(e.name, 'Oefening');
      expect(e.primaryMuscle, 'onbekend');
    });
  });
}
