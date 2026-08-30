/// The routine as it travels between two phones, and the code it becomes.
///
/// A QR code holds a couple of thousand bytes, so the payload is JSON with
/// one-letter keys, deflated. Repeated keys and shared name fragments compress
/// hard: a twelve-exercise routine with its own exercises and their
/// instructions lands around 700 bytes, which is a comfortable code to scan
/// off another phone's screen.
///
/// Nothing here touches the network. The two phones never talk; one draws a
/// picture and the other reads it.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/db/enums.dart';

/// `FL` and a format version, so a code from a future version is refused with
/// something better than a parse error.
const List<int> kRoutineCodeMagic = [0x46, 0x4C];
const int kRoutineCodeVersion = 1;

/// Limits on what a scanned code may contain. A QR is input from outside: the
/// only reason these are here is that somebody could hand us a code that is
/// not ours.
const int kMaxSharedExercises = 60;
const int kMaxSharedSets = 30;
const int kMaxSharedNameLength = 120;
const int kMaxSharedTextLength = 4000;
const int kMaxInflatedBytes = 256 * 1024;

/// Thrown for anything that is not a routine code we can read.
class InvalidRoutineCodeException implements Exception {
  const InvalidRoutineCodeException(this.message);

  final String message;

  @override
  String toString() => 'InvalidRoutineCodeException: $message';
}

/// One exercise inside a shared routine.
///
/// [id] is the catalogue id where there is one. It is the first thing the
/// other phone matches on, and everything else is the fallback for when it
/// does not know that id - a different app version, or an exercise the sender
/// made themselves.
class SharedExercise {
  const SharedExercise({
    required this.name,
    required this.primaryMuscle,
    required this.category,
    this.id,
    this.secondaryMuscles = const [],
    this.equipment,
    this.instructions,
    this.restSeconds,
    this.supersetGroup,
    this.notes,
    this.sets = const [],
  });

  final String? id;
  final String name;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final String? equipment;
  final ExerciseCategory category;
  final String? instructions;

  final int? restSeconds;
  final int? supersetGroup;
  final String? notes;
  final List<SharedSet> sets;
}

/// One planned set. No weight: the receiver lifts their own numbers, and the
/// previous column fills itself the first time they do the exercise.
class SharedSet {
  const SharedSet({
    this.type = SetType.normal,
    this.reps,
    this.durationSeconds,
  });

  final SetType type;
  final int? reps;
  final int? durationSeconds;
}

class SharedRoutine {
  const SharedRoutine({
    required this.name,
    this.notes,
    required this.exercises,
  });

  final String name;
  final String? notes;
  final List<SharedExercise> exercises;

  /// How many of the exercises came without a catalogue id, which is what the
  /// share screen shows as "your own exercises travel along".
  int get customCount => exercises.where((e) => e.id == null).length;
}

// --- Writing -----------------------------------------------------------------

Uint8List encodeRoutine(SharedRoutine routine) {
  final json = <String, Object?>{
    'v': kRoutineCodeVersion,
    'n': routine.name,
    if (routine.notes != null && routine.notes!.isNotEmpty) 'o': routine.notes,
    'e': [
      for (final exercise in routine.exercises)
        <String, Object?>{
          if (exercise.id != null) 'i': exercise.id,
          'n': exercise.name,
          'm': exercise.primaryMuscle,
          if (exercise.secondaryMuscles.isNotEmpty)
            'sm': exercise.secondaryMuscles,
          if (exercise.equipment != null) 'q': exercise.equipment,
          'c': exercise.category.wire,
          if (exercise.instructions != null &&
              exercise.instructions!.isNotEmpty)
            'x': exercise.instructions,
          if (exercise.restSeconds != null) 'r': exercise.restSeconds,
          if (exercise.supersetGroup != null) 'g': exercise.supersetGroup,
          if (exercise.notes != null && exercise.notes!.isNotEmpty)
            'o': exercise.notes,
          's': [
            for (final set in exercise.sets)
              <String, Object?>{
                if (set.type != SetType.normal) 't': set.type.wire,
                if (set.reps != null) 'p': set.reps,
                if (set.durationSeconds != null) 'd': set.durationSeconds,
              },
          ],
        },
    ],
  };

  final body = zlib.encode(utf8.encode(jsonEncode(json)));
  return Uint8List.fromList([
    ...kRoutineCodeMagic,
    kRoutineCodeVersion,
    ...body,
  ]);
}

// --- Reading -----------------------------------------------------------------

SharedRoutine decodeRoutine(List<int> code) {
  if (code.length < 4 ||
      code[0] != kRoutineCodeMagic[0] ||
      code[1] != kRoutineCodeMagic[1]) {
    throw const InvalidRoutineCodeException('Dit is geen FitLog-code.');
  }
  if (code[2] != kRoutineCodeVersion) {
    throw InvalidRoutineCodeException(
      'Deze code komt van een andere versie van FitLog (${code[2]}).',
    );
  }

  final List<int> inflated;
  try {
    inflated = zlib.decode(code.sublist(3));
  } on Object {
    throw const InvalidRoutineCodeException('De code is beschadigd.');
  }
  if (inflated.length > kMaxInflatedBytes) {
    throw const InvalidRoutineCodeException('De code is onredelijk groot.');
  }

  final Object? parsed;
  try {
    parsed = jsonDecode(utf8.decode(inflated));
  } on Object {
    throw const InvalidRoutineCodeException('De code is beschadigd.');
  }
  if (parsed is! Map<String, Object?>) {
    throw const InvalidRoutineCodeException('De code bevat geen routine.');
  }

  final exercises = parsed['e'];
  if (exercises is! List || exercises.isEmpty) {
    throw const InvalidRoutineCodeException('De code bevat geen oefeningen.');
  }
  if (exercises.length > kMaxSharedExercises) {
    throw const InvalidRoutineCodeException(
      'De code bevat onredelijk veel oefeningen.',
    );
  }

  return SharedRoutine(
    name: _text(parsed['n'], 'Gedeelde routine', kMaxSharedNameLength),
    notes: _optionalText(parsed['o'], kMaxSharedTextLength),
    exercises: [for (final raw in exercises) _decodeExercise(raw)],
  );
}

SharedExercise _decodeExercise(Object? raw) {
  if (raw is! Map<String, Object?>) {
    throw const InvalidRoutineCodeException('Een oefening is onleesbaar.');
  }

  final sets = raw['s'];
  if (sets is! List || sets.length > kMaxSharedSets) {
    throw const InvalidRoutineCodeException(
      'Een oefening heeft een onmogelijk aantal sets.',
    );
  }

  return SharedExercise(
    id: _optionalText(raw['i'], kMaxSharedNameLength),
    name: _text(raw['n'], 'Oefening', kMaxSharedNameLength),
    primaryMuscle: _text(raw['m'], 'onbekend', kMaxSharedNameLength),
    secondaryMuscles: _textList(raw['sm']),
    equipment: _optionalText(raw['q'], kMaxSharedNameLength),
    category: ExerciseCategory.fromWire(_text(raw['c'], 'barbell', 40)),
    instructions: _optionalText(raw['x'], kMaxSharedTextLength),
    restSeconds: _clampedInt(raw['r'], 0, 3600),
    supersetGroup: _clampedInt(raw['g'], 0, 25),
    notes: _optionalText(raw['o'], kMaxSharedTextLength),
    sets: [
      for (final set in sets)
        SharedSet(
          type: SetType.fromWire(
            set is Map<String, Object?> ? _text(set['t'], 'normal', 40) : '',
          ),
          reps: set is Map<String, Object?>
              ? _clampedInt(set['p'], 0, 1000)
              : null,
          durationSeconds: set is Map<String, Object?>
              ? _clampedInt(set['d'], 0, 86400)
              : null,
        ),
    ],
  );
}

String _text(Object? value, String fallback, int maxLength) {
  if (value is! String) return fallback;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed.length <= maxLength
      ? trimmed
      : trimmed.substring(0, maxLength);
}

String? _optionalText(Object? value, int maxLength) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= maxLength
      ? trimmed
      : trimmed.substring(0, maxLength);
}

List<String> _textList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value.take(kMaxSharedExercises))
      if (item is String && item.trim().isNotEmpty)
        item.trim().length <= kMaxSharedNameLength
            ? item.trim()
            : item.trim().substring(0, kMaxSharedNameLength),
  ];
}

int? _clampedInt(Object? value, int min, int max) {
  if (value is! int) return null;
  return value.clamp(min, max);
}
