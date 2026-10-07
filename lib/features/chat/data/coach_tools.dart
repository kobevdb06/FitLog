/// What the coach may look up in your own database, and nothing beyond it.
///
/// The coach gets no data with the question. It has to ask, one lookup at a
/// time, and every lookup is one of the handful defined here: read-only, of a
/// fixed shape, and each one leaving a Dutch line behind that says in plain
/// words what it fetched. Those lines are what the chat screen shows under an
/// answer and what is kept with the message, so "wat heeft het over mij
/// gezien" stays answerable a month later.
///
/// Nothing here can delete or reach outside the database, and one thing
/// writes: a routine in the coach's folder, which only holds routines the
/// coach made or the user put there knowing it could change them.
library;

import 'dart:convert';

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, OrderingTerm, QueryRow, Variable;

import '../../../core/calc/plateau.dart';
import '../../../core/calc/recovery.dart';
import '../../../core/calc/sleep_score.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../../progress/data/plateau_loader.dart';
import '../../progress/data/recovery_loader.dart';
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
          'volume, aantal sets, hoe zwaar het voelde, welke oefeningen erin '
          'zaten, de notities van de gebruiker bij de sessie en bij elke '
          'oefening, en de gemiddelde en hoogste hartslag als een horloge die '
          'via Health Connect doorgaf.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Hoeveel sessies.'},
        },
      },
    },
    {
      'name': 'current_workout',
      'description':
          'De training die nu bezig is, als die er is: naam, hoe lang al, '
          'uit welke routine, en per oefening de sets met hun status - done '
          '(afgevinkt), skipped (bewust overgeslagen) of open (nog te doen). '
          'Bij een open set staat wat er nu ingevuld is: het doel uit de '
          'routine of wat de gebruiker al intypte, dat is niet te '
          'onderscheiden. Met de notities, de rusttijd, supersets en of een '
          'oefening per kant of als PR-poging gedaan wordt. Gebruik dit '
          'als de gebruiker midden in een training iets vraagt.',
      'input_schema': {'type': 'object', 'properties': <String, Object?>{}},
    },
    {
      'name': 'exercise_history',
      'description':
          'Wat de gebruiker de laatste keren voor één oefening heeft gedaan, '
          'set per set: gewicht, herhalingen, RPE (1-10, hoe zwaar de set '
          'voelde) als die is ingevuld, en de kant (left/right) als de '
          'oefening per kant gedaan werd. Per keer ook de notitie van de '
          'gebruiker bij de oefening en of het een PR-poging was, met het '
          'doel en de uitkomst.',
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
                'EEN korte Engelse zin voor de tekening van het begin, '
                'hoogstens 25 woorden. Begin met de camerahoek en de naam van '
                'de beweging ("Side view of a person doing a standing '
                'overhead triceps extension") en zeg er dan in een paar '
                'woorden bij hoe de gewrichten staan. Noem geen stang of '
                'handvat boven het hoofd - het tekenmodel maakt daar een '
                'optrekbeweging van. Geen merknaam van een machine, maar hoe '
                'ze werkt. Wordt gebruikt om een tekening te maken, als de '
                'gebruiker daar een token voor heeft.',
          },
          'end_image_prompt': {
            'type': 'string',
            'description':
                'Hetzelfde voor de HOUDING aan het eind, even kort. De twee '
                'zinnen moeten verschillen in de stand van de armen of de '
                'benen - staat er in allebei hetzelfde ("arms overhead"), dan '
                'krijgt de gebruiker twee keer dezelfde tekening en heeft het '
                'paar geen inhoud. Bij een triceps extension: begin met '
                'gebogen ellebogen, eind met gestrekte armen.',
          },
        },
        'required': ['name', 'primary_muscle'],
      },
    },
    {
      'name': 'coach_routines',
      'description':
          'De routines in de map Coach, de enige die je mag aanpassen: per '
          'routine de naam, notitie, ingeplande dagen, wanneer laatst '
          'gedaan, en elke oefening met rusttijd, superset, notitie en elke '
          'set (type, herhalingen, gewicht, tijd). Lees een routine hier '
          'voor je ze aanpast.',
      'input_schema': {'type': 'object', 'properties': <String, Object?>{}},
    },
    {
      'name': 'save_coach_routine',
      'description':
          'Maakt een routine op maat in de map Coach, of vervangt de inhoud '
          'van een routine die daar al staat (geef dan routine mee). Dit '
          'schrijft echt in de app; hoe ze ervoor was, blijft bewaard en de '
          'gebruiker kan het terugzetten. Geef altijd de hele routine zoals '
          'ze moet worden, niet alleen wat verandert. Elke oefening met '
          'exact de naam uit search_exercises, en alleen wat kan in de zaal '
          'van de gebruiker (gym). Herhalingen en gewichten op basis van '
          'exercise_history; laat een gewicht weg als je het niet weet.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'routine': {
            'type': 'string',
            'description':
                'De naam van de routine in de map Coach die je aanpast. '
                'Weglaten voor een nieuwe.',
          },
          'name': {'type': 'string'},
          'notes': {'type': 'string'},
          'change': {
            'type': 'string',
            'description':
                'Eén zin voor de gebruiker: wat je maakte of veranderde, en '
                'waarom.',
          },
          'exercises': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'exercise': {
                  'type': 'string',
                  'description': 'Exact de naam zoals ze in de app staat.',
                },
                'rest_seconds': {'type': 'integer'},
                'superset': {
                  'type': 'integer',
                  'description':
                      'Zelfde getal voor oefeningen die je na elkaar doet.',
                },
                'notes': {'type': 'string'},
                'sets': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'type': {
                        'type': 'string',
                        'enum': ['normal', 'warmup', 'drop', 'failure'],
                      },
                      'reps': {'type': 'integer'},
                      'weight_kg': {'type': 'number'},
                      'seconds': {'type': 'integer'},
                    },
                  },
                },
              },
              'required': ['exercise', 'sets'],
            },
          },
        },
        'required': ['name', 'change', 'exercises'],
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
            // From the enum itself: written out by hand it drifted to
            // names that are stored nowhere, and the coach found nothing.
            'description':
                'Een van: '
                '${MeasurementType.values.map((t) => t.wire).join(', ')}. '
                'Lengte staat hier niet.',
          },
          'limit': {'type': 'integer'},
        },
      },
    },
    {
      'name': 'sleep',
      'description':
          'De laatste nachten van de gebruiker: wanneer in slaap en wakker, '
          'hoe lang, de lichte, REM- en diepe slaap als die bekend zijn, de '
          'slaapscore van FitLog (0-100) en of de nacht van een horloge kwam '
          '(Health Connect) of zelf ingevuld is.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Hoeveel nachten.'},
        },
      },
    },
    {
      'name': 'heart_readings',
      'description':
          'HRV (RMSSD, ms) en rusthartslag (slagen per minuut) per dag, van '
          'het horloge van de gebruiker via Health Connect, met het gewone '
          'niveau: de mediaan van de vier weken voor vandaag. Een '
          'rusthartslag met resting_hr_from_sleep is door FitLog berekend '
          'als het laagste halfuur van de nachtelijke hartslag.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Hoeveel dagen.'},
        },
      },
    },
    {
      'name': 'cardio_sessions',
      'description':
          'Loop- en fietssessies die een andere app opnam en via Health '
          'Connect binnenkwamen: datum, soort en duur.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Hoeveel sessies.'},
        },
      },
    },
    {
      'name': 'recovery',
      'description':
          'De herstelschatting van FitLog per spiergroep die de laatste '
          'dagen getraind is: wanneer, of ze klaar is, hoeveel uur nog, en '
          'wat de schatting verschoof (belasting tegenover gewoonlijk, '
          'overgedragen herstel, eigen tempo, slaap, HRV en rusthartslag, '
          'alcohol, een loop of rit, wat de gebruiker zelf zei).',
      'input_schema': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'steps',
      'description':
          'Stappen per dag van de gebruiker, zoals Health Connect ze telt '
          'over alle apps samen, en de zuurstofsaturatie (%) tijdens de nacht '
          'die die ochtend eindigde: gemiddeld en laagst.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Hoeveel dagen.'},
        },
      },
    },
    {
      'name': 'plateaus',
      'description':
          'De oefeningen die volgens FitLog stilstaan: minstens vier weken en '
          'drie keer zonder een stap vooruit van minstens 1% (in geschatte '
          '1RM, of de meeste herhalingen zonder gewicht, of de langste tijd). '
          'Per oefening: sinds wanneer, het beste en het laatste resultaat, '
          'en wat er sindsdien gebeurde - keer per week, werksets per keer, '
          'de gewone herhalingen, sets per week voor de spiergroep en slaap '
          'per nacht, die twee ook voor even lang ervoor als dat er is - en '
          'hoe vaak de spier nog niet hersteld was toen de oefening begon. '
          'Een lege lijst betekent: niets staat stil.',
      'input_schema': {'type': 'object', 'properties': <String, Object?>{}},
    },
    {
      'name': 'gym',
      'description':
          'Waar de gebruiker traint, in eigen woorden (de zaal, wat er wel '
          'of niet staat), en welk materiaal en welke oefeningen de '
          'gebruiker de laatste acht weken echt deed. Kijk hier voor je '
          'oefeningen kiest: neem alleen wat daar kan. Staat er niets '
          'beschreven, ga dan uit van wat de gebruiker al deed, of vraag '
          'het.',
      'input_schema': {'type': 'object', 'properties': <String, Object?>{}},
    },
    {
      'name': 'drinks',
      'description':
          'Hoeveel standaardglazen alcohol de gebruiker per dag noteerde. '
          'Een dag zonder rij is een dag zonder glazen of zonder invoer.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Hoeveel dagen.'},
        },
      },
    },
  ];

  static const Set<String> names = {
    'propose_exercise',
    'coach_routines',
    'save_coach_routine',
    'search_exercises',
    'recent_workouts',
    'current_workout',
    'exercise_history',
    'personal_records',
    'routines',
    'weekly_volume',
    'body_measurements',
    'sleep',
    'heart_readings',
    'cardio_sessions',
    'recovery',
    'drinks',
    'steps',
    'plateaus',
    'gym',
  };

  /// Runs one lookup. An unknown name is an answer, not a crash: the model
  /// invented it, and telling it so is better than failing the whole turn.
  Future<CoachLookup> run(String name, Map<String, Object?> input) async {
    return switch (name) {
      'propose_exercise' => _proposeExercise(input),
      'coach_routines' => _coachRoutines(),
      'save_coach_routine' => _saveCoachRoutine(input),
      'search_exercises' => _searchExercises(input),
      'recent_workouts' => _recentWorkouts(input),
      'current_workout' => _currentWorkout(),
      'exercise_history' => _exerciseHistory(input),
      'personal_records' => _personalRecords(input),
      'routines' => _routines(),
      'weekly_volume' => _weeklyVolume(input),
      'body_measurements' => _bodyMeasurements(input),
      'sleep' => _sleep(input),
      'heart_readings' => _heartReadings(input),
      'cardio_sessions' => _cardioSessions(input),
      'recovery' => _recovery(),
      'drinks' => _drinks(input),
      'steps' => _steps(input),
      'plateaus' => _plateaus(),
      'gym' => _gym(),
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

  /// The routines in the coach's folder, set by set.
  Future<CoachLookup> _coachRoutines() async {
    final folder = await db.routinesDao.coachFolder();
    final rows = await db.routinesDao.coachRoutines();
    final routines = <Map<String, Object?>>[];
    for (final row in rows.take(kCoachRowCap)) {
      final detail = await db.routinesDao.getRoutineDetail(row.id);
      if (detail == null) continue;
      routines.add({
        'name': row.name,
        'notes': ?_text(row.notes),
        'scheduled_days': _days(row.scheduledDays),
        'last_done': switch (row.lastPerformedAt) {
          final at? => _day(at),
          null => null,
        },
        'exercises': [
          for (final item in detail.exercises)
            {
              'exercise': item.exercise.name,
              'rest_seconds': ?item.routineExercise.restSeconds,
              'superset': ?item.routineExercise.supersetGroup,
              'notes': ?_text(item.routineExercise.notes),
              'sets': [
                for (final set in item.sets)
                  {
                    'type': set.setType,
                    'reps': ?set.targetReps,
                    'weight_kg': ?set.targetWeightKg,
                    'seconds': ?set.targetDurationSeconds,
                    'meters': ?set.targetDistanceM,
                  },
              ],
            },
        ],
      });
    }

    return CoachLookup(
      json: jsonEncode({'folder_exists': folder != null, 'routines': routines}),
      summary: 'je routines in de map Coach',
    );
  }

  /// The most of each the coach may put in one routine. A guard against a
  /// runaway answer, far above anything a person would train.
  static const int _maxExercises = 20;
  static const int _maxSets = 12;

  /// Makes a routine in the coach's folder, or changes one that is there.
  ///
  /// The only lookup that writes, and it can only write there: a routine
  /// outside the folder is refused by name, whatever the model asks. The
  /// routine as it was is kept first, so the change can be put back.
  Future<CoachLookup> _saveCoachRoutine(Map<String, Object?> input) async {
    CoachLookup refused(String error, String summary) => CoachLookup(
      json: jsonEncode({'ok': false, 'error': error}),
      summary: summary,
    );

    final name = _text(input['name']);
    final change = _text(input['change']);
    final wanted = input['exercises'];
    if (name == null || change == null || wanted is! List || wanted.isEmpty) {
      return refused(
        'geef een naam, een zin over wat je doet (change) en minstens één '
            'oefening',
        'een routine zonder naam of oefeningen',
      );
    }
    if (wanted.length > _maxExercises) {
      return refused(
        'hoogstens $_maxExercises oefeningen in één routine',
        'een routine met te veel oefeningen',
      );
    }

    // Every exercise by its exact name: a routine is not the place to guess
    // which of three bench presses was meant.
    final exercises = <RoutineExerciseDraft>[];
    final card = <ProposedRoutineExercise>[];
    final missing = <String>[];
    for (final entry in wanted) {
      if (entry is! Map) continue;
      final asked = _text(entry['exercise']);
      final sets = entry['sets'];
      if (asked == null || sets is! List || sets.isEmpty) {
        return refused(
          'elke oefening heeft een naam en minstens één set',
          'een oefening zonder sets',
        );
      }
      if (sets.length > _maxSets) {
        return refused(
          'hoogstens $_maxSets sets per oefening ($asked)',
          'een oefening met te veel sets',
        );
      }
      final match = await db
          .customSelect(
            'SELECT id, name FROM exercises '
            'WHERE is_archived = 0 AND LOWER(name) = LOWER(?) LIMIT 1',
            variables: [Variable.withString(asked)],
          )
          .getSingleOrNull();
      if (match == null) {
        missing.add(asked);
        continue;
      }

      final drafts = <RoutineSetDraft>[];
      for (final set in sets) {
        if (set is! Map) continue;
        final reps = _number(set['reps'])?.round();
        final kg = _number(set['weight_kg']);
        final seconds = _number(set['seconds'])?.round();
        if ((reps != null && (reps < 1 || reps > 100)) ||
            (kg != null && (kg < 0 || kg > 500)) ||
            (seconds != null && (seconds < 1 || seconds > 3600))) {
          return refused(
            'onmogelijke waarden bij $asked: herhalingen 1-100, gewicht '
                '0-500 kg, tijd 1-3600 seconden',
            'een set met onmogelijke waarden',
          );
        }
        drafts.add(
          RoutineSetDraft(
            setType: SetType.fromWire('${set['type'] ?? 'normal'}'),
            targetReps: reps,
            targetWeightKg: kg,
            targetDurationSeconds: seconds,
          ),
        );
      }

      final id = match.read<String>('id');
      exercises.add(
        RoutineExerciseDraft(
          exerciseId: id,
          restSeconds: _number(entry['rest_seconds'])?.round(),
          supersetGroup: _number(entry['superset'])?.round(),
          notes: _text(entry['notes']),
          sets: drafts,
        ),
      );
      card.add(
        ProposedRoutineExercise(
          exerciseId: id,
          name: match.read<String>('name'),
          sets: drafts.length,
          targetReps: drafts
              .where((s) => s.setType != SetType.warmup)
              .map((s) => s.targetReps)
              .nonNulls
              .firstOrNull,
        ),
      );
    }
    if (missing.isNotEmpty) {
      return CoachLookup(
        json: jsonEncode({
          'ok': false,
          'error':
              'deze oefeningen bestaan niet met die naam; zoek ze op met '
              'search_exercises en gebruik de naam exact zoals ze daar staat',
          'not_found': missing,
        }),
        summary: 'oefeningen die niet bestaan: ${missing.join(', ')}',
      );
    }

    final ours = await db.routinesDao.coachRoutines();
    RoutineRow? named(String wanted) => ours
        .where((r) => r.name.toLowerCase() == wanted.toLowerCase())
        .firstOrNull;
    final changing = _text(input['routine']);

    final String id;
    if (changing != null) {
      final existing = named(changing);
      if (existing == null) {
        return refused(
          '"$changing" staat niet in de map Coach. Alleen routines daar mag '
              'je aanpassen; maak een nieuwe, of vraag de gebruiker de routine '
              'zelf in de map Coach te zetten.',
          'de routine "$changing", die het niet mag aanpassen',
        );
      }
      id = existing.id;
      await db.routinesDao.keepVersion(id, 'Voor: $change');
      await db.routinesDao.updateRoutine(
        id,
        RoutineDraft(
          name: name,
          notes: _text(input['notes']),
          folderId: existing.folderId,
          colorIndex: existing.colorIndex,
          exercises: exercises,
        ),
      );
    } else {
      if (named(name) != null) {
        return refused(
          '"$name" staat al in de map Coach; geef routine: "$name" mee om '
              'ze aan te passen',
          'de routine "$name", die al bestond',
        );
      }
      id = await db.routinesDao.createRoutine(
        RoutineDraft(
          name: name,
          notes: _text(input['notes']),
          folderId: await db.routinesDao.ensureCoachFolder(),
          exercises: exercises,
        ),
      );
    }

    return CoachLookup(
      json: jsonEncode({
        'ok': true,
        'shown_to_user': true,
        'note':
            'De routine staat in de map Coach en als kaart in het gesprek. '
            'Zeg in een paar zinnen wat je maakte of veranderde en waarom; '
            'de kaart toont de oefeningen.',
      }),
      summary: changing == null
          ? 'de routine "$name", die het maakte'
          : 'de routine "$name", die het aanpaste',
      proposal: CoachProposal.ofCoachRoutine(
        RoutineProposal(
          name: name,
          exercises: card,
          notes: _text(input['notes']),
        ),
        appliedId: id,
        made: changing == null,
        change: change,
      ),
    );
  }

  double? _number(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

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
          'w.total_volume_kg, w.total_sets, w.perceived_effort, '
          'w.avg_heart_rate, w.max_heart_rate, w.notes '
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
            'SELECT e.name AS name, we.notes AS notes, COUNT(ws.id) AS sets '
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
        'notes': ?_text(row.read<String?>('notes')),
        if (row.read<int?>('avg_heart_rate') case final average?)
          'heart_rate': {
            'average': average,
            'highest': row.read<int?>('max_heart_rate'),
          },
        'exercises': [
          for (final exercise in exercises)
            {
              'name': exercise.read<String>('name'),
              'sets': exercise.read<int>('sets'),
              'notes': ?_text(exercise.read<String?>('notes')),
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

  /// The session that is running, set by set, as far as it got.
  Future<CoachLookup> _currentWorkout() async {
    final running = await db.workoutsDao.getActiveWorkoutRow();
    final detail = running == null
        ? null
        : await db.workoutsDao.getWorkoutDetail(running.id);
    if (detail == null) {
      return const CoachLookup(
        json: '{"running":false}',
        summary: 'of er een training bezig is',
      );
    }

    final workout = detail.workout;
    final routine = workout.routineId == null
        ? null
        : await db.routinesDao.getRoutine(workout.routineId!);
    final started = DateTime.fromMillisecondsSinceEpoch(workout.startedAt);

    return CoachLookup(
      json: jsonEncode({
        'running': true,
        'name': workout.name,
        'started': _day(workout.startedAt),
        'minutes_so_far': DateTime.now().difference(started).inMinutes,
        'from_routine': ?routine?.name,
        'notes': ?_text(workout.notes),
        'exercises': [
          for (final item in detail.exercises)
            {
              'name': item.exercise.name,
              'notes': ?_text(item.workoutExercise.notes),
              'rest_seconds': item.workoutExercise.restSeconds,
              'superset': ?item.workoutExercise.supersetGroup,
              if (item.workoutExercise.isUnilateral) 'per_side': true,
              if (item.workoutExercise.isPrAttempt)
                'pr_attempt': {
                  'target_kg': item.workoutExercise.prTargetWeightKg,
                },
              'sets': [
                for (final set in item.sets)
                  {
                    'type': set.setType,
                    'status': set.isCompleted
                        ? 'done'
                        : set.isSkipped
                        ? 'skipped'
                        : 'open',
                    'weight_kg': ?set.weightKg,
                    'reps': ?set.reps,
                    'seconds': ?set.durationSeconds,
                    'meters': ?set.distanceM,
                    'rpe': ?set.rpe,
                    'side': ?set.side,
                  },
              ],
            },
        ],
      }),
      summary: 'je training van nu',
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
          'SELECT w.started_at AS at, we.id AS session, we.notes AS notes, '
          'we.is_pr_attempt AS pr_attempt, '
          'we.pr_target_weight_kg AS pr_target, we.pr_result AS pr_result, '
          'ws.set_type AS type, ws.weight_kg AS weight, ws.reps AS reps, '
          'ws.duration_seconds AS seconds, ws.distance_m AS distance, '
          'ws.rpe AS rpe, ws.side AS side '
          'FROM workout_sets ws '
          'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
          'JOIN workouts w ON w.id = we.workout_id '
          'WHERE we.exercise_id = ? AND ws.is_completed = 1 '
          'AND w.ended_at IS NOT NULL '
          'ORDER BY w.started_at DESC, we.sort_order ASC, ws.sort_order ASC',
          variables: [Variable.withString(match.read<String>('id'))],
        )
        .get();

    // One entry per time it was done, not per day: twice on one day is two
    // times, each with its own notes.
    final done = <String, Map<String, Object?>>{};
    for (final row in rows) {
      final id = row.read<String>('session');
      if (!done.containsKey(id) && done.length >= sessions) continue;
      final session = done.putIfAbsent(
        id,
        () => {
          'date': _day(row.read<int>('at')),
          'notes': ?_text(row.read<String?>('notes')),
          if (row.read<bool>('pr_attempt'))
            'pr_attempt': {
              'target_kg': row.read<double?>('pr_target'),
              // success, failed or abandoned; null while it runs.
              'result': row.read<String?>('pr_result'),
            },
          'sets': <Map<String, Object?>>[],
        },
      );
      (session['sets']! as List<Map<String, Object?>>).add({
        'type': row.read<String>('type'),
        'weight_kg': row.read<double?>('weight'),
        'reps': row.read<int?>('reps'),
        'seconds': row.read<int?>('seconds'),
        'meters': row.read<double?>('distance'),
        'rpe': ?row.read<double?>('rpe'),
        'side': ?row.read<String?>('side'),
      });
    }

    return CoachLookup(
      json: jsonEncode({'exercise': name, 'sessions': done.values.toList()}),
      summary: 'je laatste ${done.length} keer $name',
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
    final type = _measurementType(_text(input['type']));
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

  /// A measurement as the coach asks for it, as it is stored.
  ///
  /// It used to be told `arm_left` where `left_arm` is stored, and an older
  /// conversation can still teach it that; those are read the right way round.
  String? _measurementType(String? asked) {
    if (asked == null) return null;
    final old = RegExp(r'^(arm|thigh|calf)_(left|right)$').firstMatch(asked);
    return old == null ? asked : '${old.group(2)}_${old.group(1)}';
  }

  Future<CoachLookup> _sleep(Map<String, Object?> input) async {
    final limit = _limit(input['limit'], 7);
    final nights =
        await (db.select(db.sleepEntriesTable)
              ..orderBy([(t) => OrderingTerm.desc(t.wokeAt)])
              ..limit(limit))
            .get();

    // The score of a night needs the four weeks of readings before it.
    final vitals = nights.isEmpty
        ? const <VitalsDay>[]
        : [
            for (final row
                in await db.healthDao
                    .watchVitalsSince(
                      DateTime.fromMillisecondsSinceEpoch(nights.last.wokeAt)
                          .subtract(kVitalsBaselineWindow),
                    )
                    .first)
              vitalsDayOf(row),
          ];

    return CoachLookup(
      json: jsonEncode({
        'nights': [
          for (final night in nights)
            {
              'morning': _day(night.wokeAt),
              'asleep': _clock(night.fellAsleepAt),
              'woke': _clock(night.wokeAt),
              'minutes': (night.wokeAt - night.fellAsleepAt) ~/ 60000,
              'light_minutes': ?night.lightMinutes,
              'rem_minutes': ?night.remMinutes,
              'deep_minutes': ?night.deepMinutes,
              'score': _nightScore(night, vitals).value,
              'from': night.source == null ? 'zelf ingevuld' : 'Health Connect',
            },
        ],
      }),
      summary: 'je laatste ${nights.length} nachten',
    );
  }

  static SleepScore _nightScore(SleepEntryRow night, List<VitalsDay> vitals) {
    final morning = morningAgainstUsual(
      DateTime.fromMillisecondsSinceEpoch(night.wokeAt),
      vitals,
    );
    return sleepScore(
      asleep: Duration(milliseconds: night.wokeAt - night.fellAsleepAt),
      deepMinutes: night.deepMinutes,
      remMinutes: night.remMinutes,
      hrvDrop: morning.hrvDrop,
      restingHrRise: morning.restingHrRise,
    );
  }

  Future<CoachLookup> _heartReadings(Map<String, Object?> input) async {
    final limit = _limit(input['limit'], 14);
    final today = DateTime.now();
    final days =
        await (db.select(db.dailyVitalsTable)
              ..orderBy([(t) => OrderingTerm.desc(t.day)])
              ..limit(limit))
            .get();
    final month = await db.healthDao
        .watchVitalsSince(today.subtract(kVitalsBaselineWindow))
        .first;

    double? median(Iterable<double?> values) {
      final sorted = [for (final v in values) ?v]..sort();
      if (sorted.isEmpty) return null;
      final mid = sorted.length ~/ 2;
      return sorted.length.isOdd
          ? sorted[mid]
          : (sorted[mid - 1] + sorted[mid]) / 2;
    }

    double? round(double? value) =>
        value == null ? null : (value * 10).round() / 10;

    return CoachLookup(
      json: jsonEncode({
        'usual': {
          'hrv_ms': ?round(median(month.map((d) => d.hrvMs))),
          'resting_hr': ?round(median(month.map((d) => d.restingHr))),
        },
        'days': [
          for (final day in days)
            {
              'date': _day(day.day),
              'hrv_ms': ?round(day.hrvMs),
              'resting_hr': ?round(day.restingHr),
              // Worked out by FitLog from the night, not given by the watch.
              if (day.restingHrDerived) 'resting_hr_from_sleep': true,
            },
        ],
      }),
      summary: 'je HRV en rusthartslag',
    );
  }

  Future<CoachLookup> _cardioSessions(Map<String, Object?> input) async {
    final limit = _limit(input['limit'], 10);
    final rows =
        await (db.select(db.cardioSessionsTable)
              ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
              ..limit(limit))
            .get();

    return CoachLookup(
      json: jsonEncode({
        'sessions': [
          for (final row in rows)
            {
              'date': _day(row.startedAt),
              'kind': CardioKind.fromWire(row.kind)?.label ?? row.kind,
              'minutes': (row.endedAt - row.startedAt) ~/ 60000,
            },
        ],
      }),
      summary: 'je loop- en fietssessies',
    );
  }

  Future<CoachLookup> _recovery() async {
    final now = DateTime.now();
    final estimates = await loadRecoveryEstimates(db, now: now);
    const shown = Duration(hours: 96);

    String percent(double factor) => '+${((factor - 1) * 100).round()}%';

    return CoachLookup(
      json: jsonEncode({
        'muscles': [
          for (final e in estimates)
            if (!e.isReadyAt(now) || now.difference(e.trainedAt) < shown)
              {
                'muscle': e.muscle,
                'trained': _day(e.trainedAt.millisecondsSinceEpoch),
                'ready': e.isReadyAt(now),
                if (!e.isReadyAt(now))
                  'hours_left': e.remainingAt(now).inMinutes ~/ 60,
                'estimate_hours': e.recovery.inMinutes ~/ 60,
                'load_vs_usual': (e.loadRatio * 100).round() / 100,
                if (e.provisional) 'provisional': true,
                if (e.carryover > Duration.zero)
                  'carried_over_hours': e.carryover.inMinutes ~/ 60,
                if (e.personalFactor != 1)
                  'own_pace': (e.personalFactor * 100).round() / 100,
                if (e.sleepFactor > 1) 'short_nights': percent(e.sleepFactor),
                if (e.vitalsFactor > 1) 'heart': percent(e.vitalsFactor),
                if (e.hrvDrop case final drop?)
                  'hrv_vs_usual': '${(-drop * 100).round()}%',
                if (e.restingHrRise case final rise?)
                  'resting_hr_vs_usual': rise.round(),
                if (e.alcoholFactor > 1) ...{
                  'alcohol': percent(e.alcoholFactor),
                  'drinks': e.drinks,
                },
                if (e.cardio case final run?)
                  'held_back_by': {
                    'kind': run.kind.label,
                    'date': _day(run.end.millisecondsSinceEpoch),
                    'minutes': run.duration.inMinutes,
                  },
                if (e.check case final level?)
                  'user_said': {
                    'feels': level.label,
                    'date': _day(e.checkedAt!.millisecondsSinceEpoch),
                  },
              },
        ],
      }),
      summary: 'je herstel per spiergroep',
    );
  }

  Future<CoachLookup> _steps(Map<String, Object?> input) async {
    final limit = _limit(input['limit'], 14);
    final rows =
        await (db.select(db.dailyVitalsTable)
              ..where((t) => t.steps.isNotNull() | t.spo2Avg.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.day)])
              ..limit(limit))
            .get();

    return CoachLookup(
      json: jsonEncode({
        'days': [
          for (final row in rows)
            {
              'date': _day(row.day),
              'steps': ?row.steps,
              if (row.spo2Avg != null)
                'night_spo2': {'average': row.spo2Avg, 'lowest': row.spo2Min},
            },
        ],
      }),
      summary: 'je stappen en zuurstof per dag',
    );
  }

  /// Where you train, and what you actually used there lately.
  ///
  /// How you describe your gym is part of your profile, so it only comes
  /// along when you share that; what you did there is your training, which
  /// the coach always sees.
  Future<CoachLookup> _gym() async {
    final settings = await db.settingsDao.getSettings();
    final described = settings.coachSeesProfile
        ? _text(settings.coachGym)
        : null;
    final since = DateTime.now()
        .subtract(const Duration(days: 56))
        .millisecondsSinceEpoch;
    final rows = await db
        .customSelect(
          'SELECT e.name AS name, e.equipment AS equipment, '
          'e.category AS category, COUNT(DISTINCT w.id) AS times '
          'FROM workout_exercises we '
          'JOIN workouts w ON w.id = we.workout_id '
          'JOIN exercises e ON e.id = we.exercise_id '
          'WHERE w.ended_at IS NOT NULL AND w.started_at >= ? '
          'AND EXISTS (SELECT 1 FROM workout_sets ws '
          '  WHERE ws.workout_exercise_id = we.id AND ws.is_completed = 1) '
          'GROUP BY e.id ORDER BY times DESC, e.name LIMIT $kCoachRowCap',
          variables: [Variable.withInt(since)],
        )
        .get();

    // What it is done with: the equipment where the catalogue names it,
    // the way it is logged otherwise.
    String kit(QueryRow row) =>
        _text(row.read<String?>('equipment')) ?? row.read<String>('category');
    final used = <String, int>{};
    for (final row in rows) {
      used[kit(row)] = (used[kit(row)] ?? 0) + row.read<int>('times');
    }

    return CoachLookup(
      json: jsonEncode({
        'described_by_user': described,
        'equipment_used_last_8_weeks': used,
        'exercises_done_last_8_weeks': [
          for (final row in rows)
            {
              'name': row.read<String>('name'),
              'equipment': kit(row),
              'times': row.read<int>('times'),
            },
        ],
      }),
      summary: 'waar je traint',
    );
  }

  Future<CoachLookup> _plateaus() async {
    final found = await loadPlateaus(db);
    double one(double value) => (value * 10).round() / 10;
    Map<String, Object?> compared(Object? now, Object? before) => {
      'now': now,
      'before': ?before,
    };

    return CoachLookup(
      json: jsonEncode({
        'plateaus': [
          for (final item in found.take(kCoachRowCap))
            {
              'exercise': item.exercise.name,
              'muscle': item.exercise.primaryMuscle,
              'measured_in': switch (item.plateau.measure) {
                ProgressMeasure.oneRm => 'estimated_1rm_kg',
                ProgressMeasure.reps => 'most_reps_in_a_set',
                ProgressMeasure.hold => 'longest_hold_seconds',
              },
              'since': _day(item.plateau.since.millisecondsSinceEpoch),
              'weeks': item.plateau.weeksAt(DateTime.now()),
              'best': one(item.plateau.best),
              'latest': one(item.plateau.latest),
              'sessions_since': item.context.sessions,
              'sessions_per_week': one(item.context.sessionsPerWeek),
              'working_sets_per_session': one(item.context.setsPerSession),
              'typical_reps': ?item.context.typicalReps,
              'muscle_sets_per_week': compared(
                one(item.context.muscleSetsPerWeek),
                switch (item.context.muscleSetsPerWeekBefore) {
                  final rate? => one(rate),
                  null => null,
                },
              ),
              if (item.context.averageSleep case final sleep?)
                'sleep_minutes_per_night': compared(
                  sleep.inMinutes,
                  item.context.averageSleepBefore?.inMinutes,
                ),
              if (item.plateau.measure != ProgressMeasure.hold)
                'started_before_recovered': item.context.unrecovered,
            },
        ],
      }),
      summary: 'welke oefeningen stilstaan',
    );
  }

  Future<CoachLookup> _drinks(Map<String, Object?> input) async {
    final limit = _limit(input['limit'], 14);
    final rows =
        await (db.select(db.drinkDaysTable)
              ..orderBy([(t) => OrderingTerm.desc(t.day)])
              ..limit(limit))
            .get();

    return CoachLookup(
      json: jsonEncode({
        'days': [
          for (final row in rows) {'date': _day(row.day), 'drinks': row.drinks},
        ],
      }),
      summary: 'je glazen per dag',
    );
  }

  /// The hour of a night, `23:40`. Only for sleep: when you went to bed is
  /// what advice about sleep is about.
  static String _clock(int millis) {
    final at = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
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
