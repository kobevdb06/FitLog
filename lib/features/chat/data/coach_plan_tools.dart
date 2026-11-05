part of 'coach_tools.dart';

/// The most weeks and sessions a schema may have. Fewer than two weeks is
/// not a schema; more than sixteen is a year the coach cannot look ahead.
const int kPlanMinWeeks = 2;
const int kPlanMaxWeeks = 16;
const int kPlanMaxSessions = 7;

/// The exercises of a session, written short: how many working sets of
/// what, not every set - a whole schema written set by set was too long to
/// fit in one answer.
const Map<String, Object?> _shortExercises = {
  'type': 'array',
  'items': {
    'type': 'object',
    'properties': {
      'exercise': {
        'type': 'string',
        'description': 'Exact de naam zoals ze in de app staat.',
      },
      'sets': {'type': 'integer', 'description': 'Aantal werksets.'},
      'reps': {'type': 'integer', 'description': 'Herhalingen per werkset.'},
      'weight_kg': {
        'type': 'number',
        'description': 'Gewicht per werkset; weglaten als je het niet weet.',
      },
      'seconds': {
        'type': 'integer',
        'description': 'Voor een houding: seconden per set.',
      },
      'warmup_sets': {
        'type': 'integer',
        'description': 'Warming-upsets voor de werksets.',
      },
      'rest_seconds': {'type': 'integer'},
      'superset': {'type': 'integer'},
      'notes': {'type': 'string'},
    },
    'required': ['exercise', 'sets'],
  },
};

/// The weeks of a schema, in order.
const Map<String, Object?> _weeksSchema = {
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
};

/// The name a session has now, for one the coach renames: it stays the
/// same session, with its exercises and what was done in it.
const Map<String, Object?> _wasField = {
  'type': 'string',
  'description':
      'Alleen als je een sessie hernoemt: de naam die ze nu heeft. Ze blijft '
      'dezelfde sessie, met wat er al in gedaan is.',
};

/// The sessions of a running schema that go. One left out and not named
/// here is refused (DECISIONS 240).
const Map<String, Object?> _removeField = {
  'type': 'array',
  'items': {'type': 'string'},
  'description':
      'Alleen bij een lopend schema: de sessies die echt weg moeten, bij hun '
      'naam. Een sessie die je weglaat zonder ze hier te noemen, wordt '
      'geweigerd.',
};

/// A whole schema, as save_plan and propose_plan_change take it.
const Map<String, Object?> _layoutSchema = {
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
    'weeks': _weeksSchema,
    'sessions': {
      'type': 'array',
      'description':
          'Alle sessies van een week, ook die je niet verandert, in de '
          'volgorde waarin ze gedaan worden: 1 tot $kPlanMaxSessions.',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'was': _wasField,
          'weekday': {
            'type': 'integer',
            'description': 'De dag ervoor: 1 is maandag, 7 zondag.',
          },
          'notes': {'type': 'string'},
          'exercises': _shortExercises,
        },
        'required': ['name', 'exercises'],
      },
    },
    'remove': _removeField,
  },
  'required': ['name', 'change', 'weeks', 'sessions'],
};

/// The two lookups of a schema's own conversation: reading it, and laying it
/// out. Offered only there, and only for that schema.
extension _PlanTools on CoachTools {
  /// What the coach gets on Sunday evening instead of save_plan: it
  /// proposes, and - while it keeps the numbers - sets next week's.
  static const List<Map<String, Object?>> sundayDefinitions = [
    {
      'name': 'propose_plan_change',
      'description':
          'Stelt een wijziging van het schema voor, als het hele schema zoals '
          'het zou worden - dezelfde vorm als save_plan. Er verandert niets: '
          'de gebruiker ziet een kaart met Aanvaarden en Houden.',
      'input_schema': _layoutSchema,
    },
  ];

  static const List<Map<String, Object?>> numbersDefinitions = [
    {
      'name': 'set_week_numbers',
      'description':
          'Zet de gewichten en herhalingen van volgende week: per sessie, '
          'per oefening die er al in staat, de werksets zoals ze moeten '
          'worden. De warming-up blijft als je er geen opgeeft. '
          'Andere oefeningen kunnen niet; die stel je voor met '
          'propose_plan_change.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'sessions': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'exercises': _shortExercises,
              },
              'required': ['name', 'exercises'],
            },
          },
        },
        'required': ['sessions'],
      },
    },
  ];

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
      'name': 'save_plan_outline',
      'description':
          'Legt de opzet van het schema vast, nog zonder oefeningen: de naam, '
          'de weken, de sessies van een week met hun dag en hun focus, en '
          'hoeveel werksets per spiergroep per week. Geef altijd alle '
          'sessies van de week mee, ook die je niet verandert. Een sessie '
          'die al bestaat, houdt haar oefeningen. Bij een ontwerp wacht de '
          'opzet daarna op het akkoord van de gebruiker.',
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
                'Eén zin voor de gebruiker: wat je opzette of veranderde, en '
                'waarom.',
          },
          'weeks': _weeksSchema,
          'sessions': {
            'type': 'array',
            'description':
                'Alle sessies van een week, ook die je niet verandert, in de '
                'volgorde waarin ze gedaan worden: 1 tot $kPlanMaxSessions.',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'was': _wasField,
                'weekday': {
                  'type': 'integer',
                  'description': 'De dag ervoor: 1 is maandag, 7 zondag.',
                },
                'focus': {
                  'type': 'string',
                  'description':
                      'Waar de sessie om draait, in een paar woorden: '
                      '"borst zwaar, schouders, triceps".',
                },
              },
              'required': ['name', 'focus'],
            },
          },
          'volume': {
            'type': 'array',
            'description': 'Werksets per spiergroep per week.',
            'items': {
              'type': 'object',
              'properties': {
                'muscle': {'type': 'string'},
                'sets': {'type': 'integer'},
              },
              'required': ['muscle', 'sets'],
            },
          },
          'remove': _removeField,
        },
        'required': ['name', 'change', 'weeks', 'sessions', 'volume'],
      },
    },
    {
      'name': 'save_plan_session',
      'description':
          'Legt één sessie uit de opzet vast, met al haar oefeningen. '
          'Oefeningen met exact de naam uit search_exercises en alleen wat kan '
          'in de zaal van de gebruiker (gym); gewichten op basis van '
          'exercise_history, weglaten als je het niet weet. Bij een ontwerp '
          'wacht de sessie daarna op het akkoord van de gebruiker; bij een '
          'lopend schema blijft hoe ze ervoor was bewaard.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'session': {
            'type': 'string',
            'description': 'De naam van de sessie, zoals in de opzet.',
          },
          'change': {
            'type': 'string',
            'description':
                'Eén zin voor de gebruiker: wat je koos of veranderde, en '
                'waarom.',
          },
          'notes': {'type': 'string'},
          'exercises': _shortExercises,
        },
        'required': ['session', 'change', 'exercises'],
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
        'focus': ?session.planFocus,
        'state': session.sessionState.wire,
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
        'weekly_sets': plan.weeklySets,
        'outline_approved': plan.outlineApproved,
        'sessions': sessions,
      }),
      summary: 'je schema "${plan.name}"',
    );
  }

  /// What the coach wrote as a whole schema, checked: every week within
  /// bounds, every session named once, every exercise by its exact name.
  Future<(_PlanLayout?, CoachLookup?)> _checkLayout(
    Map<String, Object?> input,
  ) async {
    (_PlanLayout?, CoachLookup?) refused(String error, String summary) => (
      null,
      CoachLookup(
        json: jsonEncode({'ok': false, 'error': error}),
        summary: summary,
      ),
    );

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

    final sessions = <_PlanSession>[];
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
      if (checked.refusal case final refusal?) return (null, refusal);
      final weekday = _number(entry['weekday'])?.round();
      sessions.add(
        _PlanSession(
          name: session,
          was: _text(entry['was']),
          weekday: weekday != null && weekday >= 1 && weekday <= 7
              ? weekday
              : null,
          notes: _text(entry['notes']),
          drafts: checked.drafts,
          // On a schema's card the working sets: "4×6", not the warm-up
          // counted in.
          card: [
            for (final (i, line) in checked.card.indexed)
              ProposedRoutineExercise(
                exerciseId: line.exerciseId,
                name: line.name,
                sets: checked.drafts[i].sets
                    .where((s) => s.setType != SetType.warmup)
                    .length,
                targetReps: line.targetReps,
              ),
          ],
        ),
      );
    }
    return (
      _PlanLayout(
        name: name,
        change: change,
        weeks: [
          for (final week in weeksIn)
            if (week is Map) PlanWeek.fromJson(week.cast<String, Object?>()),
        ],
        sessions: sessions,
      ),
      null,
    );
  }

  /// Which session that is there each of [wanted] is - by the name it had
  /// when it is renamed, or else by its name - and which are left out.
  /// While a schema runs, one left out goes only when [remove] names it: an
  /// outline written with just the session that changed once took every
  /// other with it, and what was done in them (DECISIONS 240).
  (_Matched?, CoachLookup?) _match(
    TrainingPlanRow plan,
    List<RoutineRow> before,
    List<({String name, String? was})> wanted,
    Object? remove,
  ) {
    final byName = {for (final row in before) row.name.toLowerCase(): row};
    final taken = <String>{};
    final existing = List<RoutineRow?>.filled(wanted.length, null);
    // The renamed first, so that a new session under an old name cannot
    // take the one that was renamed away from it.
    for (final (i, session) in wanted.indexed) {
      final row = byName[session.was?.toLowerCase()];
      if (row != null && taken.add(row.id)) existing[i] = row;
    }
    for (final (i, session) in wanted.indexed) {
      if (existing[i] != null) continue;
      final row = byName[session.name.toLowerCase()];
      if (row != null && taken.add(row.id)) existing[i] = row;
    }
    final gone = [
      for (final row in before)
        if (!taken.contains(row.id)) row,
    ];
    if (plan.state == PlanStatus.running) {
      final named = {
        for (final name in remove is List ? remove : const [])
          if (_text(name) case final text?) text.toLowerCase(),
      };
      final missing = [
        for (final row in gone)
          if (!named.contains(row.name.toLowerCase())) row.name,
      ];
      if (missing.isNotEmpty) {
        return (
          null,
          CoachLookup(
            json: jsonEncode({
              'ok': false,
              'error':
                  'je liet ${missing.join(', ')} weg. Geef alle sessies van '
                  'de week mee, ook die je niet verandert; een sessie die je '
                  'hernoemt, met was. Moet er echt een weg, zet ze dan in '
                  'remove.',
            }),
            summary: 'een schema zonder ${missing.join(' en ')}',
          ),
        );
      }
    }
    return (_Matched(existing: existing, gone: gone), null);
  }

  /// The schema of this conversation, or why it may not change.
  Future<(TrainingPlanRow?, CoachLookup?)> _changeable() async {
    final plan = await db.plansDao.plan(planId!);
    if (plan == null) {
      return (
        null,
        CoachLookup(
          json: jsonEncode({
            'ok': false,
            'error': 'het schema bestaat niet meer',
          }),
          summary: 'een schema dat weg is',
        ),
      );
    }
    if (plan.state == PlanStatus.done) {
      return (
        null,
        CoachLookup(
          json: jsonEncode({
            'ok': false,
            'error':
                'dit schema is afgelopen en verandert niet meer; een nieuw '
                'maakt de gebruiker met Nieuw schema',
          }),
          summary: 'een afgelopen schema',
        ),
      );
    }
    return (plan, null);
  }

  Future<CoachLookup> _savePlan(Map<String, Object?> input) async {
    final (plan, closed) = await _changeable();
    if (plan == null) return closed!;
    final (layout, refusal) = await _checkLayout(input);
    if (layout == null) return refusal!;

    final before = await db.plansDao.sessions(plan.id);
    final running = plan.state == PlanStatus.running;
    final (matched, left) = _match(plan, before, [
      for (final s in layout.sessions) (name: s.name, was: s.was),
    ], input['remove']);
    if (matched == null) return left!;
    await db.transaction(() async {
      // While it is still talked over, nothing was done in the sessions:
      // they are simply made again. A running schema keeps each session -
      // by its name, or the name it had - with what was done in it, and how
      // it was before.
      for (final row in running ? matched.gone : before) {
        // Gone from the schema. What was done in it stays in the history.
        await db.routinesDao.deleteRoutine(row.id);
      }
      for (final (position, session) in layout.sessions.indexed) {
        final draft = RoutineDraft(
          name: session.name,
          notes: session.notes,
          exercises: session.drafts,
        );
        final String id;
        if ((running ? matched.existing[position] : null)
            case final existing?) {
          id = existing.id;
          await db.routinesDao.keepVersion(id, 'Voor: ${layout.change}');
          await db.routinesDao.updateRoutine(id, draft);
        } else {
          id = await db.routinesDao.createRoutine(
            draft,
            id: running
                ? await db.plansDao.formerSession(plan, session.name)
                : null,
          );
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
        name: layout.name,
        weeks: layout.weeks,
        at: DateTime.now(),
      );
      await db.chatDao.renamePlanThread(plan.id, layout.name);
    });
    // The weeks may have moved its deload week.
    if (running) {
      await schedulePlanDeload(db, (await db.plansDao.plan(plan.id))!);
    }

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
          ? 'het schema "${layout.name}", dat het maakte'
          : 'het schema "${layout.name}", dat het aanpaste',
      proposal: CoachProposal.ofPlan(
        layout.card,
        appliedId: plan.id,
        made: made,
        change: layout.change,
      ),
    );
  }

  /// The outline: name, weeks, the sessions of a week with their day and
  /// focus, and the weekly sets per muscle group - no exercises yet. A
  /// session that is already there keeps what it has. While the schema is
  /// a draft the outline then waits for the user; a running one changes
  /// because the user asked.
  Future<CoachLookup> _saveOutline(Map<String, Object?> input) async {
    CoachLookup refused(String error, String summary) => CoachLookup(
      json: jsonEncode({'ok': false, 'error': error}),
      summary: summary,
    );
    final (plan, closed) = await _changeable();
    if (plan == null) return closed!;

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
        'een opzet zonder naam, weken of sessies',
      );
    }
    if (weeksIn.length < kPlanMinWeeks || weeksIn.length > kPlanMaxWeeks) {
      return refused(
        'een schema heeft $kPlanMinWeeks tot $kPlanMaxWeeks weken',
        'een opzet van ${weeksIn.length} weken',
      );
    }
    if (sessionsIn.length > kPlanMaxSessions) {
      return refused(
        'hoogstens $kPlanMaxSessions sessies per week',
        'een opzet met te veel sessies',
      );
    }
    final outline = <OutlineSession>[];
    final renamed = <String?>[];
    final names = <String>{};
    for (final entry in sessionsIn) {
      if (entry is! Map) continue;
      final session = _text(entry['name']);
      if (session == null) {
        return refused('elke sessie heeft een naam', 'een sessie zonder naam');
      }
      if (!names.add(session.toLowerCase())) {
        return refused(
          'twee sessies heten "$session"; geef elke sessie een eigen naam',
          'twee sessies met dezelfde naam',
        );
      }
      final weekday = _number(entry['weekday'])?.round();
      renamed.add(_text(entry['was']));
      outline.add(
        OutlineSession(
          name: session,
          weekday: weekday != null && weekday >= 1 && weekday <= 7
              ? weekday
              : null,
          focus: _text(entry['focus']),
        ),
      );
    }
    final weeks = [
      for (final week in weeksIn)
        if (week is Map) PlanWeek.fromJson(week.cast<String, Object?>()),
    ];
    final volume = <String, int>{
      for (final entry in input['volume'] as List? ?? const [])
        if (entry is Map &&
            _text(entry['muscle']) != null &&
            _number(entry['sets']) != null)
          _text(entry['muscle'])!: _number(entry['sets'])!.round().clamp(0, 60),
    };

    final running = plan.state == PlanStatus.running;
    final at = DateTime.now();
    final (matched, left) = _match(plan, await db.plansDao.sessions(plan.id), [
      for (final (i, s) in outline.indexed) (name: s.name, was: renamed[i]),
    ], input['remove']);
    if (matched == null) return left!;
    await db.transaction(() async {
      for (final row in matched.gone) {
        // Gone from the outline. What was done in it stays in the history.
        await db.routinesDao.deleteRoutine(row.id);
      }
      for (final (position, session) in outline.indexed) {
        final existing = matched.existing[position];
        final id =
            existing?.id ??
            await db.routinesDao.createRoutine(
              RoutineDraft(name: session.name, exercises: const []),
              // Put back while it runs: the session it was, with what was
              // done in it this week.
              id: running
                  ? await db.plansDao.formerSession(plan, session.name)
                  : null,
            );
        await db.plansDao.placeSession(
          id,
          planId: plan.id,
          position: position,
          weekday: session.weekday,
          focus: session.focus,
          name: existing != null && existing.name != session.name
              ? session.name
              : null,
          state: existing?.sessionState ?? PlanSessionState.planned,
        );
      }
      await db.plansDao.saveOutline(
        plan.id,
        name: name,
        weeks: weeks,
        volume: volume,
        at: at,
        approved: running,
      );
      await db.chatDao.renamePlanThread(plan.id, name);
    });
    if (running) {
      await schedulePlanDeload(db, (await db.plansDao.plan(plan.id))!);
    }

    return CoachLookup(
      json: jsonEncode({
        'ok': true,
        'shown_to_user': true,
        'note': running
            ? 'De opzet is aangepast. Een nieuwe sessie maak je met '
                  'save_plan_session.'
            : 'De opzet staat als kaart met Goedkeuren. Zeg in een paar '
                  'zinnen waarom je ze zo opzette en vraag of ze goed is; '
                  'maak nog geen sessies.',
      }),
      summary: 'de opzet van je schema "$name"',
      proposal: CoachProposal.ofOutline(
        OutlineProposal(
          planId: plan.id,
          at: at.millisecondsSinceEpoch,
          name: name,
          weeks: weeks,
          sessions: outline,
          volume: volume,
        ),
        change: change,
      ),
    );
  }

  /// One session of the outline, with all of its exercises. While the
  /// schema is a draft, only once the outline was approved, and the session
  /// then waits for the user; a running schema's changes because the user
  /// asked, keeping the session as it was first.
  Future<CoachLookup> _saveSession(Map<String, Object?> input) async {
    CoachLookup refused(String error, String summary) => CoachLookup(
      json: jsonEncode({'ok': false, 'error': error}),
      summary: summary,
    );
    final (plan, closed) = await _changeable();
    if (plan == null) return closed!;
    final running = plan.state == PlanStatus.running;
    if (!running && !plan.outlineApproved) {
      return refused(
        'de opzet is nog niet goedgekeurd; wacht op de gebruiker',
        'een sessie voor de opzet goedgekeurd is',
      );
    }

    final name = _text(input['session']);
    final change = _text(input['change']);
    final wanted = input['exercises'];
    if (name == null || change == null || wanted is! List || wanted.isEmpty) {
      return refused(
        'geef de naam van de sessie, een zin over wat je doet (change) en '
            'minstens één oefening',
        'een sessie zonder naam of oefeningen',
      );
    }
    final session = (await db.plansDao.sessions(plan.id))
        .where((s) => s.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (session == null) {
      return refused(
        'de opzet heeft geen sessie "$name"; zet ze eerst in de opzet met '
            'save_plan_outline',
        'een sessie die niet in de opzet staat',
      );
    }
    final checked = await _exercisesOf(wanted);
    if (checked.refusal case final refusal?) return refusal;

    if (running) await db.routinesDao.keepVersion(session.id, 'Voor: $change');
    await db.routinesDao.updateRoutine(
      session.id,
      RoutineDraft(
        name: session.name,
        notes: _text(input['notes']),
        folderId: session.folderId,
        colorIndex: session.colorIndex,
        exercises: checked.drafts,
      ),
    );
    await db.plansDao.markSession(
      session.id,
      running ? PlanSessionState.approved : PlanSessionState.proposed,
    );
    final saved = (await db.routinesDao.getRoutine(session.id))!;

    return CoachLookup(
      json: jsonEncode({
        'ok': true,
        'shown_to_user': true,
        'note': running
            ? 'De sessie is aangepast. Zeg kort wat je veranderde en waarom.'
            : 'De sessie staat als kaart met Goedkeuren en Aanpassen. Leg in '
                  'een paar zinnen uit wat je koos en vraag of ze goed is; maak '
                  'nog geen volgende sessie.',
      }),
      summary: 'sessie "${session.name}" van je schema',
      proposal: CoachProposal.ofSession(
        SessionProposal(
          planId: plan.id,
          routineId: session.id,
          savedAt: saved.updatedAt,
          name: session.name,
          weekday: session.planWeekday,
          focus: session.planFocus,
          exercises: [
            for (final (i, draft) in checked.drafts.indexed)
              _sessionExercise(checked.card[i].name, draft),
          ],
        ),
        change: change,
      ),
    );
  }

  SessionExercise _sessionExercise(String name, RoutineExerciseDraft draft) {
    final working = [
      for (final s in draft.sets)
        if (s.setType != SetType.warmup) s,
    ];
    final first = working.firstOrNull;
    return SessionExercise(
      name: name,
      sets: working.length,
      warmups: draft.sets.length - working.length,
      reps: first?.targetReps,
      weightKg: first?.targetWeightKg,
      seconds: first?.targetDurationSeconds,
      restSeconds: draft.restSeconds,
      notes: draft.notes,
    );
  }

  /// On Sunday the coach does not change the schema; it proposes, and the
  /// user decides. The whole schema as it would become goes on the card,
  /// checked already, and Aanvaarden lays it out as save_plan would.
  Future<CoachLookup> _proposePlanChange(Map<String, Object?> input) async {
    final (plan, closed) = await _changeable();
    if (plan == null) return closed!;
    final (layout, refusal) = await _checkLayout(input);
    if (layout == null) return refusal!;
    // Refused now, not only at Aanvaarden: a card that takes sessions
    // nobody meant to lose should not be offered at all.
    final (_, left) = _match(plan, await db.plansDao.sessions(plan.id), [
      for (final s in layout.sessions) (name: s.name, was: s.was),
    ], input['remove']);
    if (left != null) return left;
    return CoachLookup(
      json: jsonEncode({
        'ok': true,
        'shown_to_user': true,
        'note':
            'Het voorstel staat als kaart met Aanvaarden en Houden. Er '
            'verandert niets tot de gebruiker aanvaardt.',
      }),
      summary: 'een voorstel voor je schema',
      proposal: CoachProposal.ofPlanChange(
        PlanChangeProposal(layout: layout.card, input: input),
        planId: plan.id,
        change: layout.change,
      ),
    );
  }

  /// While the coach keeps the numbers: next week's sets of the exercises
  /// already in each session. Not a proposal - the user chose to leave the
  /// numbers to the coach - but every session is kept as it was first.
  Future<CoachLookup> _setWeekNumbers(Map<String, Object?> input) async {
    CoachLookup refused(String error) => CoachLookup(
      json: jsonEncode({'ok': false, 'error': error}),
      summary: 'de cijfers van volgende week',
    );
    final (plan, closed) = await _changeable();
    if (plan == null) return closed!;
    if (plan.progressionKind != PlanProgression.coach) {
      return refused(
        'bij dit schema stelt de app de cijfers bij, niet jij; stel een '
        'wijziging voor met propose_plan_change',
      );
    }
    final wanted = input['sessions'];
    if (wanted is! List || wanted.isEmpty) {
      return refused('geef per sessie de oefeningen en hun sets');
    }

    final sessions = {
      for (final s in await db.plansDao.sessions(plan.id))
        s.name.toLowerCase(): s,
    };
    final week = plan.weekAt(DateTime.now()) + 1;
    var changed = 0;
    for (final entry in wanted) {
      if (entry is! Map) continue;
      final name = _text(entry['name']);
      final session = name == null ? null : sessions[name.toLowerCase()];
      if (session == null) {
        return refused(
          'het schema heeft geen sessie "$name"; lees de namen met plan',
        );
      }
      final detail = (await db.routinesDao.getRoutineDetail(session.id))!;
      final draft = draftOf(detail);
      final exercises = [...draft.exercises];
      for (final item in entry['exercises'] as List? ?? const []) {
        if (item is! Map) continue;
        final asked = _text(item['exercise'])?.toLowerCase();
        final at = detail.exercises.indexWhere(
          (e) => e.exercise.name.toLowerCase() == asked,
        );
        if (at < 0) {
          return refused(
            '"${item['exercise']}" staat niet in ${session.name}; alleen '
            'de cijfers van oefeningen die er staan, een andere oefening '
            'stel je voor met propose_plan_change',
          );
        }
        final checked = await _exercisesOf([
          {...item, 'exercise': detail.exercises[at].exercise.name},
        ]);
        if (checked.refusal case final refusal?) return refusal;
        final old = exercises[at];
        final sets = checked.drafts.single.sets;
        exercises[at] = RoutineExerciseDraft(
          exerciseId: old.exerciseId,
          restSeconds: old.restSeconds,
          supersetGroup: old.supersetGroup,
          notes: old.notes,
          // Next week's numbers are the working sets; the warm-up stays as
          // it was unless the coach wrote one.
          sets: sets.any((s) => s.setType == SetType.warmup)
              ? sets
              : [
                  for (final s in old.sets)
                    if (s.setType == SetType.warmup) s,
                  ...sets,
                ],
        );
        changed++;
      }
      await db.routinesDao.keepVersion(session.id, 'Voor: week $week');
      await db.routinesDao.updateRoutine(
        session.id,
        RoutineDraft(
          name: draft.name,
          notes: draft.notes,
          folderId: draft.folderId,
          colorIndex: draft.colorIndex,
          exercises: exercises,
        ),
      );
    }
    return CoachLookup(
      json: jsonEncode({
        'ok': true,
        'note':
            'De cijfers van week $week staan in de sessies. Zeg kort wat '
            'er veranderde.',
      }),
      summary:
          'de cijfers van volgende week, voor '
          '${changed == 1 ? '1 oefening' : '$changed oefeningen'}',
    );
  }
}

/// A whole schema as the coach wrote it, checked and ready to lay out.
class _PlanLayout {
  const _PlanLayout({
    required this.name,
    required this.change,
    required this.weeks,
    required this.sessions,
  });

  final String name;
  final String change;
  final List<PlanWeek> weeks;
  final List<_PlanSession> sessions;

  PlanProposal get card => PlanProposal(
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
  );
}

class _PlanSession {
  const _PlanSession({
    required this.name,
    this.was,
    required this.weekday,
    required this.notes,
    required this.drafts,
    required this.card,
  });

  final String name;

  /// The name it has now, when the coach renames it.
  final String? was;
  final int? weekday;
  final String? notes;
  final List<RoutineExerciseDraft> drafts;
  final List<ProposedRoutineExercise> card;
}

/// How the sessions the coach wrote meet the ones that are there.
class _Matched {
  const _Matched({required this.existing, required this.gone});

  /// Per session written, in its order: the one it is, or null for a new
  /// one.
  final List<RoutineRow?> existing;

  /// What is there and was not written: it goes.
  final List<RoutineRow> gone;
}
