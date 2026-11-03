/// Geplande prompts: at a moment, FitLog asks the coach something in the
/// user's own words - after a workout, in the morning report, on Sunday
/// evening. Which moments there are, what each asks when the user has not
/// said otherwise, and the rules that go underneath every prompt.
library;

import '../../../core/db/database.dart';

/// One example under the prompt field: a word to tap, and what it fills in.
typedef PromptExample = ({String label, String prompt});

extension CoachMomentText on CoachMoment {
  String get title => switch (this) {
    CoachMoment.workout => 'Na je workout',
    CoachMoment.morning => 'Ochtendrapport',
    CoachMoment.week => 'Weekoverzicht',
  };

  /// When the question goes, and where the answer appears.
  String get when => switch (this) {
    CoachMoment.workout => 'Na elke workout, op de samenvatting',
    CoachMoment.morning => 'Elke ochtend, onder Herstel',
    CoachMoment.week => 'Zondag om 20:00, op het weekoverzicht',
  };

  /// The two that were already there are on, as they were; a new one is
  /// the user's to switch on.
  bool get onByDefault => this != CoachMoment.workout;

  /// What the switch does. Off, the morning and the week are still there,
  /// in FitLog's own words or numbers: only the question is not asked.
  String get switchTitle => switch (this) {
    CoachMoment.workout => 'Na elke workout',
    CoachMoment.morning => 'De coach schrijft het rapport',
    CoachMoment.week => 'De coach schrijft over je week',
  };

  String get switchHint => switch (this) {
    CoachMoment.workout =>
      'De coach antwoordt op de samenvatting. Eén vraag per workout.',
    CoachMoment.morning =>
      'Eén vraag per ochtend. Uit schrijft FitLog het rapport zelf.',
    CoachMoment.week => 'Eén vraag per week. Uit staan er alleen de cijfers.',
  };

  String get defaultPrompt => switch (this) {
    CoachMoment.workout =>
      'Geef een eerlijke, kritische mening over deze workout: wat ging goed, '
          'wat kan beter, en één ding voor volgende keer.',
    CoachMoment.morning =>
      'Zeg hoe de nacht was en wat HRV of rusthartslag zeggen als ze erbij '
          'staan, welke spiergroepen nog herstellen en welke klaar zijn, en '
          'wat dat betekent voor vandaag trainen.',
    CoachMoment.week =>
      'Zeg wat goed ging en wat achterbleef, en eindig met één concreet '
          'voorstel voor volgende week, in een zin die begint met "Volgende '
          'week:".',
  };

  AnswerLength get defaultLength => switch (this) {
    CoachMoment.morning => AnswerLength.short,
    CoachMoment.workout || CoachMoment.week => AnswerLength.normal,
  };

  List<PromptExample> get examples => switch (this) {
    CoachMoment.workout => const [
      (
        label: 'Kritisch',
        prompt:
            'Geef een kritische mening over mijn workout. Wees eerlijk, ook '
            'als het tegenvalt.',
      ),
      (
        label: 'Wat ging beter?',
        prompt: 'Wat ging er beter dan de vorige keer, en wat niet?',
      ),
      (
        label: 'Eén ding',
        prompt:
            'Noem één ding dat ik volgende keer anders moet doen, en waarom.',
      ),
    ],
    CoachMoment.morning => const [
      (
        label: 'Streng',
        prompt: 'Zeg vooral of ik vandaag zwaar mag trainen, en wees streng.',
      ),
      (label: 'Eén zin', prompt: 'Eén zin: trainen of rusten, en waarom.'),
      (
        label: 'Uitleg',
        prompt:
            'Leg uit wat mijn nacht, HRV en rusthartslag vandaag betekenen.',
      ),
    ],
    CoachMoment.week => const [
      (
        label: 'Eén prioriteit',
        prompt:
            'Vergelijk met de weken ervoor en geef één prioriteit voor volgende '
            'week.',
      ),
      (
        label: 'Kritisch',
        prompt: 'Wees kritisch over mijn week: wat liet ik liggen?',
      ),
      (
        label: 'Motiveer',
        prompt: 'Wat ging goed deze week? Motiveer me voor de volgende.',
      ),
    ],
  };

  /// What the coach writes, in its instruction.
  String get _writes => switch (this) {
    CoachMoment.workout => 'je reactie op een workout',
    CoachMoment.morning => 'het ochtendrapport',
    CoachMoment.week => 'het weekoverzicht',
  };

  /// What the facts are, in the coach's instruction.
  String get _facts => switch (this) {
    CoachMoment.workout => 'de workout die de gebruiker net afrondde',
    CoachMoment.morning => 'de feiten van vanochtend',
    CoachMoment.week => 'de feiten van de afgelopen week',
  };

  /// How to read what this moment's facts hold. Not the user's to change:
  /// it is what the JSON means, not what to say about it.
  String get _reading => switch (this) {
    CoachMoment.workout =>
      'Per oefening staan de sets in volgorde, met hun type (warmup is '
          'opwarming; drop en failure zijn zo bedoeld) en status (done is '
          'afgevinkt, skipped bewust overgeslagen, open niet gedaan). '
          'target_reps is wat de routine vraagt; last_time is dezelfde '
          'oefening de vorige keer, alleen de werksets. felt is hoe zwaar de '
          'gebruiker de workout vond. Staat deload of light erbij, dan was ze '
          'bewust lichter: zeg dan niet dat het minder was dan vorige keer.',
    CoachMoment.morning =>
      'Staat er een check_voor_training bij, volg dan haar oordeel en noem '
          'de sessie.',
    CoachMoment.week =>
      'lagging_muscles zijn spiergroepen die achterbleven bij hun gewoonte. '
          'Staat er deload_days, dan was het (deels) een deloadweek: minder '
          'volume was de bedoeling, en lichter trainen was dan goed.',
  };
}

extension AnswerLengthText on AnswerLength {
  String get label => switch (this) {
    AnswerLength.short => 'Kort',
    AnswerLength.normal => 'Normaal',
    AnswerLength.long => 'Lang',
  };

  String get _rule => switch (this) {
    AnswerLength.short => 'hoogstens drie korte zinnen en geen opsomming',
    AnswerLength.normal => 'hoogstens vijf zinnen en geen opsomming',
    AnswerLength.long => 'hoogstens tien zinnen; een korte opsomming mag',
  };

  /// Room for the words, and for a model that thinks before it writes and
  /// spends this limit on that too.
  int get maxTokens => switch (this) {
    AnswerLength.short => 512,
    AnswerLength.normal => 768,
    AnswerLength.long => 1280,
  };
}

/// What the user asks at one moment: their words and length, or the
/// moment's own.
class MomentPrompt {
  const MomentPrompt({
    required this.moment,
    required this.enabled,
    this.custom,
    this.customLength,
  });

  factory MomentPrompt.of(CoachMoment moment, CoachPromptRow? row) =>
      row == null
      ? MomentPrompt(moment: moment, enabled: moment.onByDefault)
      : MomentPrompt(
          moment: moment,
          enabled: row.enabled,
          custom: switch (row.prompt?.trim()) {
            final text? when text.isNotEmpty => text,
            _ => null,
          },
          customLength: AnswerLength.fromWire(row.length),
        );

  static Future<MomentPrompt> load(AppDatabase db, CoachMoment moment) async =>
      MomentPrompt.of(moment, await db.coachPromptsDao.promptRow(moment));

  final CoachMoment moment;
  final bool enabled;

  /// The user's own words; null is the moment's.
  final String? custom;
  final AnswerLength? customLength;

  String get text => custom ?? moment.defaultPrompt;
  AnswerLength get length => customLength ?? moment.defaultLength;

  /// Nothing about it was changed: what it asks is the app's.
  bool get isOwn => custom == null && customLength == null;
}

/// The coach's whole instruction for [prompt]: FitLog's rules, what the user
/// allowed it to know, and then the user's words.
///
/// The rules come first and stay whatever the prompt says: Dutch, only what
/// the facts hold, no doctor. The prompt decides what to say, not what to
/// make up.
String buildMomentSystem({
  required MomentPrompt prompt,
  String? weightUnit,
  String? aboutUser,
  List<String> notes = const [],
}) {
  final moment = prompt.moment;
  return [
    'Je schrijft ${moment._writes} in FitLog, een logboek voor '
        'krachttraining. Je krijgt ${moment._facts} als JSON. '
        '${moment._reading}',
    'Schrijf in het Nederlands, in de je-vorm, ${prompt.length._rule}. '
        'Gebruik alleen wat in de feiten staat: verzin geen cijfers, '
        'oefeningen of spiergroepen. Vraagt de gebruiker iets wat er niet in '
        'staat, zeg dat dan kort. Je bent geen arts: geen diagnoses, geen '
        'supplementen.',
    if (weightUnit != null)
      'Gewichten staan in kg; de gebruiker ziet ze in $weightUnit.',
    if (aboutUser != null) 'Over de gebruiker: $aboutUser.',
    if (notes.isNotEmpty)
      [
        'Wat je over de gebruiker onthoudt:',
        for (final note in notes) '- $note',
      ].join('\n'),
    'Wat de gebruiker je vraagt:\n${prompt.text}',
  ].join('\n\n');
}

/// What goes to the coach at [moment], line by line, as the settings stand:
/// what the user shares decides the last lines.
List<String> momentGets(
  CoachMoment moment, {
  required bool profile,
  required bool health,
  required bool memory,
}) => [
  ...switch (moment) {
    CoachMoment.workout => [
      'De workout: elke oefening met haar sets, gewicht, herhalingen en RPE, '
          'en wat je afvinkte of oversloeg',
      'Wat de routine vraagt, en elke oefening de vorige keer',
      'Records, duur en volume, je notities, en hoe zwaar het voelde als je '
          'dat al invulde',
      if (health) 'Je hartslag tijdens de workout, van je horloge',
    ],
    CoachMoment.morning => [
      'Je nacht en slaapscore, en welke spiergroepen nog herstellen of klaar '
          'zijn',
      'De check voor je volgende sessie',
      if (health) 'HRV en rusthartslag van je horloge',
    ],
    CoachMoment.week => [
      'Je trainingen: gepland en gedaan, sets per spiergroep, records en '
          'stilstand',
      health
          ? 'Je nachten, en HRV, rusthartslag en stappen van je horloge'
          : 'De nachten die je zelf invulde',
    ],
  },
  if (profile) 'Je leeftijd, geslacht en lengte',
  if (memory) 'Wat de coach over je onthoudt',
];
