/// What the coach may look up in your own database, and nothing beyond it.
///
/// The coach gets no data with the question. It has to ask, one lookup at a
/// time, and every lookup is one of the handful defined here: read-only, of a
/// fixed shape, and each one leaving a Dutch line behind that says in plain
/// words what it fetched. Those lines are what the chat screen shows under an
/// answer and what is kept with the message, so "wat heeft het over mij
/// gezien" stays answerable a month later.
///
/// Nothing here can write, delete, or reach outside the database.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../domain/coach_proposal.dart';

/// The result of one lookup: what goes back to the model, and what the user
/// is told was looked at.
class CoachLookup {
  const CoachLookup({required this.json, required this.summary, this.proposal});

  /// The tool result, as the model sees it.
  final String json;

  /// One line of Dutch: "je laatste 5 sessies".
  final String summary;

  /// Something the coach offers to add, for the app to draw as a card. The
  /// tool itself changes nothing.
  final CoachProposal? proposal;
}

/// How many rows a single lookup may ever return.
///
/// A cap rather than a promise to be sensible: every row here is a row that
/// leaves the device, and an unbounded query on a three-year logbook would
/// send the lot.
const int kCoachRowCap = 40;

class CoachTools {
  CoachTools(this.db);

  final AppDatabase db;

  /// The tool definitions, as the API wants them.
  static List<Map<String, Object?>> definitions() => [
    {
      'name': 'search_exercises',
      'description':
          'Zoek oefeningen in de catalogus van de app, inclusief de eigen '
          'oefeningen van de gebruiker. Gebruik dit voordat je een oefening '
          'aanraadt, zodat je een naam noemt die echt in de app staat.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Woord in de naam, het materiaal of het type.',
          },
          'muscle': {
            'type': 'string',
            'description': 'Primaire spiergroep, bijvoorbeeld borst of rug.',
          },
          'limit': {'type': 'integer'},
        },
      },
    },
    {
      'name': 'recent_workouts',
      'description':
          'De laatste afgewerkte sessies van de gebruiker: datum, naam, duur, '
          'volume, aantal sets en welke oefeningen erin zaten.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Hoeveel sessies.'},
        },
      },
    },
    {
      'name': 'exercise_history',
      'description':
          'Wat de gebruiker de laatste keren voor één oefening heeft gedaan, '
          'set per set, met gewicht en herhalingen.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'exercise': {
            'type': 'string',
            'description': 'Naam van de oefening, of een deel ervan.',
          },
          'sessions': {'type': 'integer'},
        },
        'required': ['exercise'],
      },
    },
    {
      'name': 'personal_records',
      'description':
          'De persoonlijke records van de gebruiker, eventueel voor één '
          'oefening.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'exercise': {'type': 'string'},
        },
      },
    },
    {
      'name': 'routines',
      'description':
          'De routines van de gebruiker, met de oefeningen erin en op welke '
          'dagen ze gepland staan.',
      'input_schema': {'type': 'object', 'properties': <String, Object?>{}},
    },
    {
      'name': 'weekly_volume',
      'description':
          'Volume, aantal sessies en aantal sets per week, en per spiergroep '
          'over dezelfde periode. Gebruik dit voor vragen over vooruitgang of '
          'of iemand genoeg doet voor een spiergroep.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'weeks': {'type': 'integer'},
        },
      },
    },
    {
      'name': 'propose_exercise',
      'description':
          'Stel een nieuwe oefening voor die de gebruiker met één tik kan '
          'toevoegen. Maakt zelf niets aan: de gebruiker beslist. Zoek eerst '
          'met search_exercises of ze niet al bestaat.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'primary_muscle': {
            'type': 'string',
            'description': 'Nederlands, zoals in de app: borst, rug, biceps.',
          },
          'secondary_muscles': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'equipment': {'type': 'string'},
          'category': {
            'type': 'string',
            'description':
                'Hoe een set gemeten wordt: barbell, dumbbell, machine, '
                'cable, bodyweight, assisted_bodyweight, duration of cardio. '
                'Of de naam van een eigen categorie van de gebruiker.',
          },
          'instructions': {'type': 'string'},
          'start_image_prompt': {
            'type': 'string',
            'description':
                'Engelse beschrijving van hoe de STARTpositie eruitziet: de '
                'houding van de persoon, hoe het materiaal vastgehouden '
                'wordt, en vanuit welke hoek je de beweging het best ziet. '
                'Beschrijf een machine aan de hand van hoe ze werkt ("seated '
                'at a chest-supported row machine with two handles that move '
                'backward"), nooit met een merknaam: het tekenprogramma kent '
                'die niet en verzint er dan een. Wordt gebruikt om een '
                'tekening te maken, als de gebruiker daar een token voor '
                'heeft.',
          },
          'end_image_prompt': {
            'type': 'string',
            'description':
                'Hetzelfde voor de EINDpositie. Beschrijf wat er verschilt '
                'van de start: dat verschil is waar het paar om draait.',
          },
        },
        'required': ['name', 'primary_muscle'],
      },
    },
    {
      'name': 'propose_routine',
      'description':
          'Stel een routine voor die de gebruiker met één tik kan toevoegen. '
          'Maakt zelf niets aan. Elke oefening moet met haar naam in de app '
          'bestaan; zoek ze eerst op met search_exercises.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'notes': {'type': 'string'},
          'exercises': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'exercise': {
                  'type': 'string',
                  'description': 'Naam zoals ze in de app staat.',
                },
                'sets': {'type': 'integer'},
                'target_reps': {'type': 'integer'},
              },
              'required': ['exercise', 'sets'],
            },
          },
        },
        'required': ['name', 'exercises'],
      },
    },
    {
      'name': 'body_measurements',
      'description':
          'De lichaamsmetingen van de gebruiker, bijvoorbeeld gewicht, in '
          'metrische eenheden.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'description':
                'weight, height, body_fat, neck, chest, waist, hips, '
                'thigh_left, thigh_right, arm_left, arm_right, calf_left, '
                'calf_right.',
          },
          'limit': {'type': 'integer'},
        },
      },
    },
  ];

  static const Set<String> names = {
    'propose_exercise',
    'propose_routine',
    'search_exercises',
    'recent_workouts',
    'exercise_history',
    'personal_records',
    'routines',
    'weekly_volume',
    'body_measurements',
  };

  /// Runs one lookup. An unknown name is an answer, not a crash: the model
  /// invented it, and telling it so is better than failing the whole turn.
  Future<CoachLookup> run(String name, Map<String, Object?> input) async {
    return switch (name) {
      'propose_exercise' => _proposeExercise(input),
      'propose_routine' => _proposeRoutine(input),
      'search_exercises' => _searchExercises(input),
      'recent_workouts' => _recentWorkouts(input),
      'exercise_history' => _exerciseHistory(input),
      'personal_records' => _personalRecords(input),
      'routines' => _routines(),
      'weekly_volume' => _weeklyVolume(input),
      'body_measurements' => _bodyMeasurements(input),
      _ => CoachLookup(
        json: jsonEncode({'error': 'onbekende tool: $name'}),
        summary: 'een opzoeking die niet bestaat ($name)',
      ),
    };
  }

  int _limit(Object? value, int fallback) {
    final asked = value is int ? value : int.tryParse('$value');
    if (asked == null || asked <= 0) return fallback;
    return asked > kCoachRowCap ? kCoachRowCap : asked;
  }

  String? _text(Object? value) {
    final text = value is String ? value.trim() : null;
    return text == null || text.isEmpty ? null : text;
  }

  /// An exercise the coach would make. Nothing is written here.
  Future<CoachLookup> _proposeExercise(Map<String, Object?> input) async {
    final name = _text(input['name']);
    final muscle = _text(input['primary_muscle']);
    if (name == null || muscle == null) {
      return const CoachLookup(
        json: '{"ok":false,"error":"geef minstens een naam en een spiergroep"}',
        summary: 'een voorstel zonder naam',
      );
    }

    // An exercise that already exists is the answer, not a second copy of it.
    final existing = await db
        .customSelect(
          'SELECT name FROM exercises WHERE LOWER(name) = LOWER(?) '
          'AND is_archived = 0 LIMIT 1',
          variables: [Variable.withString(name)],
        )
        .getSingleOrNull();
    if (existing != null) {
      return CoachLookup(
        json: jsonEncode({
          'ok': false,
          'error': 'die oefening bestaat al',
          'existing': existing.read<String>('name'),
        }),
        summary: 'of "$name" al bestaat',
      );
    }

    final proposal = ExerciseProposal(
      name: name,
      primaryMuscle: muscle.toLowerCase(),
      secondaryMuscles: [
        for (final entry in input['secondary_muscles'] as List? ?? const [])
          if (_text(entry) case final muscle?) muscle.toLowerCase(),
      ],
      equipment: _text(input['equipment']),
      category: _text(input['category']) ?? 'barbell',
      instructions: _text(input['instructions']),
      startImagePrompt: _text(input['start_image_prompt']),
      endImagePrompt: _text(input['end_image_prompt']),
    );

    return CoachLookup(
      json: jsonEncode({
        'ok': true,
        'shown_to_user': true,
        'note':
            'Het voorstel staat als kaart in het gesprek. Zeg kort wat je '
            'voorstelt; de gebruiker tikt zelf op Toevoegen.',
      }),
      summary: 'een voorstel voor de oefening "$name"',
      proposal: CoachProposal.ofExercise(proposal),
    );
  }

  /// A routine the coach would make, with every exercise matched to a real
  /// one. An invented name comes back as an error so the model can fix it.
  Future<CoachLookup> _proposeRoutine(Map<String, Object?> input) async {
    final name = _text(input['name']);
    final wanted = input['exercises'];
    if (name == null || wanted is! List || wanted.isEmpty) {
      return const CoachLookup(
        json: '{"ok":false,"error":"geef een naam en minstens één oefening"}',
        summary: 'een voorstel zonder oefeningen',
      );
    }

    final exercises = <ProposedRoutineExercise>[];
    final missing = <String>[];
    for (final entry in wanted.take(kCoachRowCap)) {
      if (entry is! Map) continue;
      final asked = _text(entry['exercise']);
      if (asked == null) continue;

      final match = await db
          .customSelect(
            'SELECT id, name FROM exercises '
            'WHERE is_archived = 0 AND (LOWER(name) = LOWER(?) '
            'OR name LIKE ?) ORDER BY LENGTH(name) LIMIT 1',
            variables: [
              Variable.withString(asked),
              Variable.withString('%$asked%'),
            ],
          )
          .getSingleOrNull();

      if (match == null) {
        missing.add(asked);
        continue;
      }
      exercises.add(
        ProposedRoutineExercise(
          exerciseId: match.read<String>('id'),
          name: match.read<String>('name'),
          sets: _limit(entry['sets'], 3),
          targetReps: entry['target_reps'] is int
              ? entry['target_reps']! as int
              : null,
        ),
      );
    }

    if (missing.isNotEmpty) {
      return CoachLookup(
        json: jsonEncode({
          'ok': false,
          'error':
              'deze oefeningen bestaan niet in de app; zoek ze op met '
              'search_exercises en gebruik de naam die daar staat, of stel ze '
              'eerst voor met propose_exercise',
          'not_found': missing,
        }),
        summary: 'oefeningen die niet bestaan: ${missing.join(', ')}',
      );
    }

    return CoachLookup(
      json: jsonEncode({
        'ok': true,
        'shown_to_user': true,
        'note':
            'Het voorstel staat als kaart in het gesprek. Zeg kort waarom je '
            'deze routine voorstelt; de gebruiker tikt zelf op Toevoegen.',
      }),
      summary: 'een voorstel voor de routine "$name"',
      proposal: CoachProposal.ofRoutine(
        RoutineProposal(
          name: name,
          exercises: exercises,
          notes: _text(input['notes']),
        ),
      ),
    );
  }

  Future<CoachLookup> _searchExercises(Map<String, Object?> input) async {
    final query = _text(input['query']);
    final muscle = _text(input['muscle']);
    final limit = _limit(input['limit'], 15);

    final rows = await db.exercisesDao.getExercises(
      ExerciseFilter(
        query: query ?? '',
        muscles: muscle == null ? const {} : {muscle.toLowerCase()},
      ),
    );

    final found = rows.take(limit).toList();
    return CoachLookup(
      json: jsonEncode({
        'count': rows.length,
        'shown': found.length,
        'exercises': [
          for (final exercise in found)
            {
              'name': exercise.name,
              'primary_muscle': exercise.primaryMuscle,
              'secondary_muscles': decodeSecondaryMuscles(
                exercise.secondaryMuscles,
              ),
              'equipment': exercise.equipment,
              'category': exercise.categoryLabel,
              'own': exercise.isCustom,
            },
        ],
      }),
      summary: switch ((query, muscle)) {
        (final q?, final m?) => 'oefeningen voor $m met "$q"',
        (final q?, null) => 'oefeningen die passen bij "$q"',
        (null, final m?) => 'oefeningen voor $m',
        _ => 'de oefeningencatalogus',
      },
    );
  }

  Future<CoachLookup> _recentWorkouts(Map<String, Object?> input) async {
    final limit = _limit(input['limit'], 5);
    final rows = await db
        .customSelect(
          'SELECT w.id, w.name, w.started_at, w.duration_seconds, '
          'w.total_volume_kg, w.total_sets, w.perceived_effort '
          'FROM workouts w WHERE w.ended_at IS NOT NULL '
          'ORDER BY w.started_at DESC LIMIT ?',
          variables: [Variable.withInt(limit)],
        )
        .get();

    final sessions = <Map<String, Object?>>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      final exercises = await db
          .customSelect(
            'SELECT e.name AS name, COUNT(ws.id) AS sets '
            'FROM workout_exercises we '
            'JOIN exercises e ON e.id = we.exercise_id '
            'LEFT JOIN workout_sets ws ON ws.workout_exercise_id = we.id '
            '  AND ws.is_completed = 1 '
            'WHERE we.workout_id = ? GROUP BY we.id ORDER BY we.sort_order',
            variables: [Variable.withString(id)],
          )
          .get();

      sessions.add({
        'date': _day(row.read<int>('started_at')),
        'name': row.read<String>('name'),
        'minutes': (row.read<int?>('duration_seconds') ?? 0) ~/ 60,
        'volume_kg': row.read<double?>('total_volume_kg')?.round(),
        'sets': row.read<int?>('total_sets'),
        'felt': row.read<String?>('perceived_effort'),
        'exercises': [
          for (final exercise in exercises)
            {
              'name': exercise.read<String>('name'),
              'sets': exercise.read<int>('sets'),
            },
        ],
      });
    }

    return CoachLookup(
      json: jsonEncode({'workouts': sessions}),
      summary:
          'je laatste ${sessions.length} '
          '${sessions.length == 1 ? 'sessie' : 'sessies'}',
    );
  }

  Future<CoachLookup> _exerciseHistory(Map<String, Object?> input) async {
    final wanted = _text(input['exercise']);
    if (wanted == null) {
      return const CoachLookup(
        json: '{"error":"geef een oefening op"}',
        summary: 'een oefening zonder naam',
      );
    }
    final sessions = _limit(input['sessions'], 5);

    final match = await db
        .customSelect(
          'SELECT id, name FROM exercises WHERE name LIKE ? '
          'ORDER BY LENGTH(name) LIMIT 1',
          variables: [Variable.withString('%$wanted%')],
        )
        .getSingleOrNull();

    if (match == null) {
      return CoachLookup(
        json: jsonEncode({'found': false, 'searched': wanted}),
        summary: 'je geschiedenis voor "$wanted", die niet bestaat',
      );
    }

    final name = match.read<String>('name');
    final rows = await db
        .customSelect(
          'SELECT w.started_at AS at, ws.set_type AS type, '
          'ws.weight_kg AS weight, ws.reps AS reps, '
          'ws.duration_seconds AS seconds, ws.distance_m AS distance '
          'FROM workout_sets ws '
          'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
          'JOIN workouts w ON w.id = we.workout_id '
          'WHERE we.exercise_id = ? AND ws.is_completed = 1 '
          'AND w.ended_at IS NOT NULL '
          'ORDER BY w.started_at DESC, ws.sort_order ASC',
          variables: [Variable.withString(match.read<String>('id'))],
        )
        .get();

    final byDay = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final day = _day(row.read<int>('at'));
      if (!byDay.containsKey(day) && byDay.length >= sessions) continue;
      (byDay[day] ??= []).add({
        'type': row.read<String>('type'),
        'weight_kg': row.read<double?>('weight'),
        'reps': row.read<int?>('reps'),
        'seconds': row.read<int?>('seconds'),
        'meters': row.read<double?>('distance'),
      });
    }

    return CoachLookup(
      json: jsonEncode({
        'exercise': name,
        'sessions': [
          for (final entry in byDay.entries)
            {'date': entry.key, 'sets': entry.value},
        ],
      }),
      summary: 'je laatste ${byDay.length} keer $name',
    );
  }

  Future<CoachLookup> _personalRecords(Map<String, Object?> input) async {
    final wanted = _text(input['exercise']);
    final rows = await db
        .customSelect(
          'SELECT e.name AS name, pr.record_type AS type, pr.value AS value, '
          'pr.achieved_at AS at FROM personal_records pr '
          'JOIN exercises e ON e.id = pr.exercise_id '
          '${wanted == null ? '' : 'WHERE e.name LIKE ? '}'
          'ORDER BY pr.achieved_at DESC LIMIT $kCoachRowCap',
          variables: [if (wanted != null) Variable.withString('%$wanted%')],
        )
        .get();

    return CoachLookup(
      json: jsonEncode({
        'records': [
          for (final row in rows)
            {
              'exercise': row.read<String>('name'),
              'type': row.read<String>('type'),
              'value': row.read<double>('value'),
              'date': _day(row.read<int>('at')),
            },
        ],
      }),
      summary: wanted == null
          ? 'je persoonlijke records'
          : 'je records voor "$wanted"',
    );
  }

  Future<CoachLookup> _routines() async {
    final routines = await db
        .customSelect(
          'SELECT id, name, scheduled_days, is_favourite, last_performed_at '
          'FROM routines ORDER BY sort_order',
        )
        .get();

    final result = <Map<String, Object?>>[];
    for (final routine in routines.take(kCoachRowCap)) {
      final exercises = await db
          .customSelect(
            'SELECT e.name AS name, COUNT(rs.id) AS sets '
            'FROM routine_exercises re '
            'JOIN exercises e ON e.id = re.exercise_id '
            'LEFT JOIN routine_sets rs ON rs.routine_exercise_id = re.id '
            'WHERE re.routine_id = ? GROUP BY re.id ORDER BY re.sort_order',
            variables: [Variable.withString(routine.read<String>('id'))],
          )
          .get();

      result.add({
        'name': routine.read<String>('name'),
        'favourite': routine.read<bool>('is_favourite'),
        'scheduled_days': _days(routine.read<int?>('scheduled_days') ?? 0),
        'last_done': switch (routine.read<int?>('last_performed_at')) {
          final at? => _day(at),
          _ => null,
        },
        'exercises': [
          for (final exercise in exercises)
            {
              'name': exercise.read<String>('name'),
              'sets': exercise.read<int>('sets'),
            },
        ],
      });
    }

    return CoachLookup(
      json: jsonEncode({'routines': result}),
      summary: 'je routines',
    );
  }

  Future<CoachLookup> _weeklyVolume(Map<String, Object?> input) async {
    final weeks = _limit(input['weeks'], 8);
    final since = DateTime.now()
        .subtract(Duration(days: 7 * weeks))
        .millisecondsSinceEpoch;

    final perWeek = await db
        .customSelect(
          "SELECT strftime('%Y-%W', w.started_at / 1000, 'unixepoch') AS week, "
          'COUNT(DISTINCT w.id) AS sessions, '
          'SUM(w.total_sets) AS sets, SUM(w.total_volume_kg) AS volume '
          'FROM workouts w '
          'WHERE w.ended_at IS NOT NULL AND w.started_at >= ? '
          'GROUP BY week ORDER BY week DESC',
          variables: [Variable.withInt(since)],
        )
        .get();

    final perMuscle = await db
        .customSelect(
          'SELECT e.primary_muscle AS muscle, COUNT(ws.id) AS sets '
          'FROM workout_sets ws '
          'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
          'JOIN workouts w ON w.id = we.workout_id '
          'JOIN exercises e ON e.id = we.exercise_id '
          'WHERE ws.is_completed = 1 AND ws.set_type != ? '
          'AND w.ended_at IS NOT NULL AND w.started_at >= ? '
          'GROUP BY e.primary_muscle ORDER BY sets DESC',
          variables: [Variable.withString('warmup'), Variable.withInt(since)],
        )
        .get();

    return CoachLookup(
      json: jsonEncode({
        'weeks': [
          for (final row in perWeek.take(kCoachRowCap))
            {
              'week': row.read<String>('week'),
              'sessions': row.read<int>('sessions'),
              'sets': row.read<int?>('sets'),
              'volume_kg': row.read<double?>('volume')?.round(),
            },
        ],
        'sets_per_muscle': {
          for (final row in perMuscle)
            row.read<String>('muscle'): row.read<int>('sets'),
        },
        'over_weeks': weeks,
      }),
      summary: 'je cijfers van de laatste $weeks weken',
    );
  }

  Future<CoachLookup> _bodyMeasurements(Map<String, Object?> input) async {
    final type = _text(input['type']);
    final limit = _limit(input['limit'], 10);

    final rows = await db
        .customSelect(
          'SELECT type, value, measured_at FROM body_measurements '
          '${type == null ? '' : 'WHERE type = ? '}'
          'ORDER BY measured_at DESC LIMIT ?',
          variables: [
            if (type != null) Variable.withString(type),
            Variable.withInt(limit),
          ],
        )
        .get();

    return CoachLookup(
      json: jsonEncode({
        'unit': 'metrisch: kg, cm, %',
        'measurements': [
          for (final row in rows)
            {
              'type': row.read<String>('type'),
              'value': row.read<double>('value'),
              'date': _day(row.read<int>('measured_at')),
            },
        ],
      }),
      summary: type == null ? 'je lichaamsmetingen' : 'je metingen van $type',
    );
  }

  /// Dates go out as plain days. The model never needs the hour someone
  /// trained, and a timestamp is more about a person than a date is.
  static String _day(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// The weekday mask of a routine, as names the model can read.
  static List<String> _days(int mask) {
    const names = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
    return [
      for (var i = 0; i < names.length; i++)
        if (mask & (1 << i) != 0) names[i],
    ];
  }
}
