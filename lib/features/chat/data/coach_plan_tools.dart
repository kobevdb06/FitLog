part of 'coach_tools.dart';

/// The most weeks and sessions a schema may have. Fewer than two weeks is
/// not a schema; more than sixteen is a year the coach cannot look ahead.
const int kPlanMinWeeks = 2;
const int kPlanMaxWeeks = 16;
const int kPlanMaxSessions = 7;

/// The two lookups of a schema's own conversation: reading it, and laying it
/// out. Offered only there, and only for that schema.
extension _PlanTools on CoachTools {
  static const List<Map<String, Object?>> definitions = [
    {
      'name': 'plan',
      'description':
          'Het schema waar dit gesprek bij hoort: wat de gebruiker wil, de '
          'split, de dagen, wie de cijfers bijstelt, waar het staat (ontwerp, '
          'lopend of afgelopen), de weken, en elke sessie met haar oefeningen '
          'en sets. Loopt het, dan ook welke week het is en welke sessies '
          'deze week gedaan zijn. Lees het voor je het aanpast.',
      'input_schema': {'type': 'object', 'properties': <String, Object?>{}},
    },
    {
      'name': 'save_plan',
      'description':
          'Legt het schema van dit gesprek vast: de naam, de weken en elke '
          'sessie. Geef altijd het hele schema, niet alleen wat verandert. '
          'Een sessie is een routine; oefeningen met exact de naam uit '
          'search_exercises en alleen wat kan in de zaal van de gebruiker '
          '(gym). Gewichten op basis van exercise_history; laat een gewicht '
          'weg als je het niet weet. Een week verandert alleen het aantal '
          'werksets per oefening (sets) of de herhalingen per set (reps), '
          'hoogstens 3 erbij of eraf, of is een deload. Bij een lopend schema '
          'blijft hoe een sessie ervoor was bewaard.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Een korte naam, bijvoorbeeld "Kracht en massa".',
          },
          'change': {
            'type': 'string',
            'description':
                'Eén zin voor de gebruiker: wat je maakte of veranderde, en '
                'waarom.',
          },
          'weeks': {
            'type': 'array',
            'description':
                'Elke week van het schema, in volgorde: $kPlanMinWeeks tot '
                '$kPlanMaxWeeks. Meestal een deload als laatste.',
            'items': {
              'type': 'object',
              'properties': {
                'kind': {
                  'type': 'string',
                  'enum': ['build', 'deload'],
                },
                'sets': {
                  'type': 'integer',
                  'description': 'Werksets per oefening erbij (of eraf: -1).',
                },
                'reps': {
                  'type': 'integer',
                  'description': 'Herhalingen per set erbij (of eraf: -2).',
                },
                'note': {
                  'type': 'string',
                  'description': 'Waarvoor de week is, in een paar woorden.',
                },
              },
              'required': ['kind'],
            },
          },
          'sessions': {
            'type': 'array',
            'description':
                'De sessies van een week, in de volgorde waarin ze gedaan '
                'worden: 1 tot $kPlanMaxSessions.',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'weekday': {
                  'type': 'integer',
                  'description': 'De dag ervoor: 1 is maandag, 7 zondag.',
                },
                'notes': {'type': 'string'},
                'exercises': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'exercise': {
                        'type': 'string',
                        'description':
                            'Exact de naam zoals ze in de app staat.',
                      },
                      'rest_seconds': {'type': 'integer'},
                      'superset': {'type': 'integer'},
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
              'required': ['name', 'exercises'],
            },
          },
        },
        'required': ['name', 'change', 'weeks', 'sessions'],
      },
    },
  ];

  Future<CoachLookup> _readPlan() async {
    final plan = await db.plansDao.plan(planId!);
    if (plan == null) {
      return CoachLookup(
        json: jsonEncode({'error': 'het schema bestaat niet meer'}),
        summary: 'een schema dat er niet meer is',
      );
    }
    final now = DateTime.now();
    final week = plan.weekAt(now);
    final running = plan.state == PlanStatus.running && week >= 1;
    final standing = running ? await db.plansDao.standing(plan, week) : null;

    final sessions = <Map<String, Object?>>[];
    for (final session in await db.plansDao.sessions(plan.id)) {
      sessions.add({
        'name': session.name,
        'weekday': ?session.planWeekday,
        'notes': ?_text(session.notes),
        if (standing != null)
          'done_this_week': standing.done.contains(session.id),
        'exercises': await _routineContent(session.id),
      });
    }

    return CoachLookup(
      json: jsonEncode({
        'name': plan.name,
        'status': plan.state.wire,
        'goal': plan.goal,
        'split': plan.splitKind.wire,
        'split_note': ?plan.splitNote,
        'days': CoachTools._days(plan.days),
        'progression': plan.progressionKind.wire,
        if (plan.startDay case final start?) 'started': CoachTools._day(start),
        if (running) 'week': week,
        'weeks': [for (final w in plan.planWeeks) w.toJson()],
        'sessions': sessions,
      }),
      summary: 'je schema "${plan.name}"',
    );
  }

  Future<CoachLookup> _savePlan(Map<String, Object?> input) async {
    CoachLookup refused(String error, String summary) => CoachLookup(
      json: jsonEncode({'ok': false, 'error': error}),
      summary: summary,
    );

    final plan = await db.plansDao.plan(planId!);
    if (plan == null) {
      return refused('het schema bestaat niet meer', 'een schema dat weg is');
    }
    if (plan.state == PlanStatus.done) {
      return refused(
        'dit schema is afgelopen en verandert niet meer; een nieuw maakt de '
            'gebruiker met Nieuw schema',
        'een afgelopen schema',
      );
    }

    final name = _text(input['name']);
    final change = _text(input['change']);
    final weeksIn = input['weeks'];
    final sessionsIn = input['sessions'];
    if (name == null ||
        change == null ||
        weeksIn is! List ||
        sessionsIn is! List ||
        sessionsIn.isEmpty) {
      return refused(
        'geef een naam, een zin over wat je doet (change), de weken en '
            'minstens één sessie',
        'een schema zonder naam, weken of sessies',
      );
    }
    if (weeksIn.length < kPlanMinWeeks || weeksIn.length > kPlanMaxWeeks) {
      return refused(
        'een schema heeft $kPlanMinWeeks tot $kPlanMaxWeeks weken',
        'een schema van ${weeksIn.length} weken',
      );
    }
    if (sessionsIn.length > kPlanMaxSessions) {
      return refused(
        'hoogstens $kPlanMaxSessions sessies per week',
        'een schema met te veel sessies',
      );
    }
    final weeks = [
      for (final week in weeksIn)
        if (week is Map) PlanWeek.fromJson(week.cast<String, Object?>()),
    ];

    final sessions =
        <
          ({
            String name,
            int? weekday,
            String? notes,
            List<RoutineExerciseDraft> drafts,
            List<ProposedRoutineExercise> card,
          })
        >[];
    final names = <String>{};
    for (final entry in sessionsIn) {
      if (entry is! Map) continue;
      final session = _text(entry['name']);
      final exercises = entry['exercises'];
      if (session == null || exercises is! List || exercises.isEmpty) {
        return refused(
          'elke sessie heeft een naam en minstens één oefening',
          'een sessie zonder naam of oefeningen',
        );
      }
      if (!names.add(session.toLowerCase())) {
        return refused(
          'twee sessies heten "$session"; geef elke sessie een eigen naam',
          'twee sessies met dezelfde naam',
        );
      }
      final checked = await _exercisesOf(exercises);
      if (checked.refusal case final refusal?) return refusal;
      final weekday = _number(entry['weekday'])?.round();
      sessions.add((
        name: session,
        weekday: weekday != null && weekday >= 1 && weekday <= 7
            ? weekday
            : null,
        notes: _text(entry['notes']),
        drafts: checked.drafts,
        card: checked.card,
      ));
    }

    final before = await db.plansDao.sessions(plan.id);
    final running = plan.state == PlanStatus.running;
    await db.transaction(() async {
      // While it is still talked over, nothing was done in the sessions:
      // they are simply made again. A running schema keeps its sessions by
      // name, with what was done in them, and how each was before.
      final kept = <String, RoutineRow>{
        if (running)
          for (final row in before) row.name.toLowerCase(): row,
      };
      for (final row in before) {
        if (!kept.containsKey(row.name.toLowerCase()) ||
            !names.contains(row.name.toLowerCase())) {
          // Gone from the schema. What was done in it stays in the history.
          await db.routinesDao.deleteRoutine(row.id);
        }
      }
      for (final (position, session) in sessions.indexed) {
        final draft = RoutineDraft(
          name: session.name,
          notes: session.notes,
          exercises: session.drafts,
        );
        final String id;
        if (kept[session.name.toLowerCase()] case final existing?) {
          id = existing.id;
          await db.routinesDao.keepVersion(id, 'Voor: $change');
          await db.routinesDao.updateRoutine(id, draft);
        } else {
          id = await db.routinesDao.createRoutine(draft);
        }
        await db.plansDao.placeSession(
          id,
          planId: plan.id,
          position: position,
          weekday: session.weekday,
        );
      }
      await db.plansDao.layOut(
        plan.id,
        name: name,
        weeks: weeks,
        at: DateTime.now(),
      );
      await db.chatDao.renamePlanThread(plan.id, name);
    });

    final made = before.isEmpty;
    return CoachLookup(
      json: jsonEncode({
        'ok': true,
        'shown_to_user': true,
        'note': running
            ? 'Het schema is aangepast en staat als kaart in het gesprek. '
                  'Zeg in een paar zinnen wat je veranderde en waarom.'
            : 'Het schema staat als kaart in het gesprek, met een knop Start '
                  'schema. Zeg in een paar zinnen hoe het in elkaar zit en '
                  'vraag of het zo goed is; niets verandert voor de gebruiker '
                  'op Start tikt.',
      }),
      summary: made
          ? 'het schema "$name", dat het maakte'
          : 'het schema "$name", dat het aanpaste',
      proposal: CoachProposal.ofPlan(
        PlanProposal(
          name: name,
          weeks: weeks,
          sessions: [
            for (final session in sessions)
              ProposedPlanSession(
                name: session.name,
                weekday: session.weekday,
                exercises: session.card,
              ),
          ],
        ),
        appliedId: plan.id,
        made: made,
        change: change,
      ),
    );
  }
}
