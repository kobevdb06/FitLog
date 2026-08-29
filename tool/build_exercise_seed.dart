// Build-time tool. Downloads the free-exercise-db catalogue, reduces it to the
// fields FitLog stores, translates muscle groups and equipment to Dutch, and
// writes assets/data/exercises.json.
//
// Run with:  dart run tool/build_exercise_seed.dart
//
// This script is the ONLY place in the repository that touches the network,
// and it never runs inside the app. Source:
// https://github.com/yuhonas/free-exercise-db  (public domain / Unlicense)

import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

const _sourceUrl =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';

const _outputPath = 'assets/data/exercises.json';

/// A fixed namespace so that a rebuild of the seed produces the same ids and
/// existing databases keep pointing at the same exercises.
const _namespace = '9f5b6c2e-4d13-4a7f-9c2b-5e1a7d3f8b60';

/// Muscle groups, translated. The values double as the keys of the colour map
/// in lib/core/theme/app_colors.dart.
const Map<String, String> muscleTranslations = {
  'abdominals': 'buik',
  'abductors': 'abductoren',
  'adductors': 'adductoren',
  'biceps': 'biceps',
  'calves': 'kuiten',
  'chest': 'borst',
  'forearms': 'onderarmen',
  'glutes': 'bilspieren',
  'hamstrings': 'hamstrings',
  'lats': 'lats',
  'lower back': 'onderrug',
  'middle back': 'bovenrug',
  'neck': 'nek',
  'quadriceps': 'quadriceps',
  'shoulders': 'schouders',
  'traps': 'trapezius',
  'triceps': 'triceps',
};

/// Equipment names, translated.
const Map<String, String> equipmentTranslations = {
  'bands': 'weerstandsbanden',
  'barbell': 'halterstang',
  'body only': 'lichaamsgewicht',
  'cable': 'kabel',
  'dumbbell': 'dumbbells',
  'e-z curl bar': 'ez-stang',
  'exercise ball': 'fitnessbal',
  'foam roll': 'foamroller',
  'kettlebells': 'kettlebells',
  'machine': 'machine',
  'medicine ball': 'medicijnbal',
  'other': 'overig',
};

/// Maps the source's equipment plus category onto the FitLog category, which
/// decides which input columns a set shows.
String deriveCategory(String? equipment, String? sourceCategory) {
  if (sourceCategory == 'cardio') return 'cardio';
  if (sourceCategory == 'stretching') return 'duration';

  switch (equipment) {
    case 'barbell':
    case 'e-z curl bar':
      return 'barbell';
    case 'dumbbell':
    case 'kettlebells':
    case 'medicine ball':
      return 'dumbbell';
    case 'machine':
      return 'machine';
    case 'cable':
    case 'bands':
      return 'cable';
    case 'body only':
    case 'foam roll':
    case 'exercise ball':
    case 'other':
    case null:
      return 'bodyweight';
    default:
      return 'bodyweight';
  }
}

Future<String> _download(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} voor $url');
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

Future<void> main(List<String> args) async {
  stdout.writeln('Ophalen van $_sourceUrl ...');
  final raw = await _download(_sourceUrl);
  final source = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  stdout.writeln('${source.length} oefeningen ontvangen.');

  const uuid = Uuid();
  final unknownMuscles = <String>{};
  final unknownEquipment = <String>{};

  final exercises = <Map<String, dynamic>>[];

  for (final item in source) {
    final name = (item['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;

    final primaryList = (item['primaryMuscles'] as List?)?.cast<String>() ?? [];
    if (primaryList.isEmpty) continue;

    String translateMuscle(String m) {
      final t = muscleTranslations[m];
      if (t == null) unknownMuscles.add(m);
      return t ?? m;
    }

    final equipmentRaw = item['equipment'] as String?;
    String? equipment;
    if (equipmentRaw != null) {
      equipment = equipmentTranslations[equipmentRaw];
      if (equipment == null) {
        unknownEquipment.add(equipmentRaw);
        equipment = equipmentRaw;
      }
    }

    final instructions =
        (item['instructions'] as List?)?.cast<String>().join('\n\n');

    exercises.add({
      // Deterministic v5 id derived from the upstream slug, so rebuilding the
      // seed never orphans logged workouts.
      'id': uuid.v5(_namespace, 'free-exercise-db/${item['id']}'),
      'name': name,
      'primary_muscle': translateMuscle(primaryList.first),
      'secondary_muscles': [
        ...primaryList.skip(1).map(translateMuscle),
        ...((item['secondaryMuscles'] as List?)?.cast<String>() ?? [])
            .map(translateMuscle),
      ],
      'equipment': equipment,
      'category': deriveCategory(equipmentRaw, item['category'] as String?),
      'instructions': (instructions == null || instructions.isEmpty)
          ? null
          : instructions,
    });
  }

  exercises.sort(
    (a, b) => (a['name'] as String).toLowerCase().compareTo(
      (b['name'] as String).toLowerCase(),
    ),
  );

  if (unknownMuscles.isNotEmpty) {
    stderr.writeln('Onvertaalde spiergroepen: ${unknownMuscles.join(', ')}');
  }
  if (unknownEquipment.isNotEmpty) {
    stderr.writeln('Onvertaald materiaal: ${unknownEquipment.join(', ')}');
  }

  final output = File(_outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'source': 'https://github.com/yuhonas/free-exercise-db',
      'license': 'Unlicense (public domain)',
      'generated_by': 'tool/build_exercise_seed.dart',
      'exercises': exercises,
    }),
  );

  stdout.writeln('${exercises.length} oefeningen weggeschreven naar '
      '$_outputPath');

  final byCategory = <String, int>{};
  for (final e in exercises) {
    byCategory.update(
      e['category'] as String,
      (v) => v + 1,
      ifAbsent: () => 1,
    );
  }
  stdout.writeln('Per categorie: $byCategory');
}
