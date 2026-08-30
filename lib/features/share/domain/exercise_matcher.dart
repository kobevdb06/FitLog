/// Decides whether an exercise arriving in a shared routine is one the user
/// already has.
///
/// The same problem exists without sharing - nothing stops anyone making
/// "Bench Press" twice - so this is written against a plain list of exercises
/// and used from both places.
library;

import '../../../core/db/database.dart';
import 'routine_code.dart';

enum ExerciseMatchKind {
  /// The same catalogue entry. Nothing to decide.
  sameId,

  /// The same name once case and punctuation are ignored.
  sameName,

  /// Close enough to be worth proposing: nearly the same name, the same
  /// primary muscle and the same category.
  similar,

  /// Nothing like it. It will be added as an exercise of your own.
  none,
}

class ExerciseMatch {
  const ExerciseMatch(this.kind, [this.existing]);

  final ExerciseMatchKind kind;
  final ExerciseRow? existing;

  /// Whether the app links to [existing] unless the user says otherwise.
  bool get linksByDefault => kind != ExerciseMatchKind.none;
}

/// How far apart two names may be and still be proposed as the same exercise.
const int kMaxNameDistance = 2;

/// Strips everything two people would spell differently: case, accents,
/// punctuation and doubled spaces. "Bench Press" and "bench-press" become the
/// same string.
String normaliseExerciseName(String name) {
  const accents = 'áàâäãåéèêëíìîïóòôöõúùûüýÿñç';
  const plain = 'aaaaaaeeeeiiiiooooouuuuyync';

  final buffer = StringBuffer();
  var lastWasSpace = true;
  for (final rune in name.toLowerCase().runes) {
    var char = String.fromCharCode(rune);
    final accent = accents.indexOf(char);
    if (accent >= 0) char = plain[accent];

    final isWord =
        (char.codeUnitAt(0) >= 0x61 && char.codeUnitAt(0) <= 0x7a) ||
        (char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39);
    if (isWord) {
      buffer.write(char);
      lastWasSpace = false;
    } else if (!lastWasSpace) {
      buffer.write(' ');
      lastWasSpace = true;
    }
  }
  return buffer.toString().trim();
}

/// Finds the exercise in [mine] that [incoming] most likely already is.
ExerciseMatch matchSharedExercise(
  SharedExercise incoming,
  List<ExerciseRow> mine,
) {
  final id = incoming.id;
  if (id != null) {
    for (final row in mine) {
      if (row.id == id) return ExerciseMatch(ExerciseMatchKind.sameId, row);
    }
  }
  return matchExerciseByName(
    name: incoming.name,
    primaryMuscle: incoming.primaryMuscle,
    category: incoming.category,
    mine: mine,
  );
}

/// The name-based half, also used when the user types a name of their own.
///
/// [ignoreId] leaves one exercise out, so editing an exercise does not report
/// it as a duplicate of itself.
ExerciseMatch matchExerciseByName({
  required String name,
  required String primaryMuscle,
  required ExerciseCategory category,
  required List<ExerciseRow> mine,
  String? ignoreId,
}) {
  final wanted = normaliseExerciseName(name);
  if (wanted.isEmpty) return const ExerciseMatch(ExerciseMatchKind.none);

  ExerciseRow? nearest;
  var nearestDistance = kMaxNameDistance + 1;

  for (final row in mine) {
    if (row.id == ignoreId) continue;
    final theirs = normaliseExerciseName(row.name);
    if (theirs == wanted) {
      return ExerciseMatch(ExerciseMatchKind.sameName, row);
    }

    // Only worth proposing when the rest of the exercise agrees as well: a
    // barbell bench press and a dumbbell one are two exercises, however alike
    // the names read.
    if (row.primaryMuscle != primaryMuscle) continue;
    if (ExerciseCategory.fromWire(row.category) != category) continue;

    final distance = _nameDistance(wanted, theirs);
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearest = row;
    }
  }

  if (nearest != null) return ExerciseMatch(ExerciseMatchKind.similar, nearest);
  return const ExerciseMatch(ExerciseMatchKind.none);
}

/// Edit distance, except that one name wholly containing the other counts as
/// very close: "bench press" against "bench press barbell" is the same lift
/// written down twice.
int _nameDistance(String a, String b) {
  if (_containsAsWords(a, b) || _containsAsWords(b, a)) return 1;
  return _levenshtein(a, b);
}

bool _containsAsWords(String haystack, String needle) {
  if (needle.isEmpty) return false;
  final words = haystack.split(' ');
  final wanted = needle.split(' ');
  for (var i = 0; i + wanted.length <= words.length; i++) {
    var hit = true;
    for (var j = 0; j < wanted.length; j++) {
      if (words[i + j] != wanted[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return true;
  }
  return false;
}

/// Stops counting once it is past what we would accept, which keeps it cheap
/// over a catalogue of hundreds.
int _levenshtein(String a, String b) {
  if ((a.length - b.length).abs() > kMaxNameDistance) {
    return kMaxNameDistance + 1;
  }

  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    var best = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final value = [
        current[j - 1] + 1,
        previous[j] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      current[j] = value;
      if (value < best) best = value;
    }
    if (best > kMaxNameDistance) return kMaxNameDistance + 1;
    previous = current;
  }
  return previous[b.length];
}
