/// The questions an empty conversation offers: about you, today.
///
/// They used to be the same four for everyone, forever. Now they are made
/// from what is going on - the workout running, what is planned, a muscle
/// still recovering, an exercise standing still - each with a line that
/// says why it is there.
///
/// Who makes them is a [CoachSuggester]. For now one on the phone: free,
/// there at once, and nothing leaves the device before you ask. One that
/// asks the coach can take its place later; the screen only knows the
/// interface.
library;

/// Why a question is offered, which is also the icon it gets.
enum SuggestionReason {
  workout,
  deload,
  today,
  recovery,
  stalled,
  record,
  comeback,
  sleep,
  start,
  app,
  general,
}

class CoachSuggestion {
  const CoachSuggestion({
    required this.question,
    required this.why,
    required this.reason,
  });

  /// What is sent when you tap it.
  final String question;

  /// One short line under it: "Staat 5 weken stil".
  final String why;

  final SuggestionReason reason;
}

/// Where the questions come from.
abstract interface class CoachSuggester {
  /// The most fitting first.
  Future<List<CoachSuggestion>> suggest();
}

/// How many show at once; Andere vragen shows the next ones.
const int kSuggestionsShown = 4;

/// What the questions on the phone are made from. Everything optional:
/// what is not known is not asked about.
class SuggestionFacts {
  const SuggestionFacts({
    this.workout,
    this.exercise,
    this.deloadDay,
    this.deloadDays,
    this.plannedToday,
    this.recovering,
    this.recoveringHours,
    this.stalled,
    this.stalledWeeks,
    this.weeksWithoutBreak,
    this.deloadDue = false,
    this.record,
    this.daysSinceLast,
    this.workouts = 0,
    this.lastNight,
    this.dayOfYear = 0,
  });

  /// The workout running, and the exercise it is at.
  final String? workout;
  final String? exercise;

  /// The day of the deload going on now, and how many it has.
  final int? deloadDay;
  final int? deloadDays;

  /// The routine planned for today and not done yet.
  final String? plannedToday;

  /// The muscle with the longest still to go, and how many hours.
  final String? recovering;
  final int? recoveringHours;

  /// The exercise that has stood still the longest, and for how many weeks.
  final String? stalled;
  final int? stalledWeeks;

  final int? weeksWithoutBreak;

  /// Whether the proposal on Start would say it is time for a deload.
  final bool deloadDue;

  /// An exercise with a record this last week.
  final String? record;

  final int? daysSinceLast;

  /// Finished sessions, ever.
  final int workouts;

  /// Last night's sleep, when it was short enough to matter.
  final Duration? lastNight;

  /// Which question about the app is up today: they take turns.
  final int dayOfYear;
}

/// Questions about the app itself, one at a time, a different one each day.
const List<String> kAppQuestions = [
  'Hoe log ik een dropset in deze app?',
  'Hoe werkt een deload in FitLog?',
  'Hoe zet ik een routine op mijn trainingsdagen?',
  'Wat betekent RPE, en moet ik het invullen?',
  'Hoe werkt de herstelschatting?',
];

/// The questions [facts] give rise to, the most fitting first.
List<CoachSuggestion> suggestQuestions(SuggestionFacts facts) {
  final found = <CoachSuggestion>[];
  void add(String question, String why, SuggestionReason reason) =>
      found.add(CoachSuggestion(question: question, why: why, reason: reason));

  // Mid-workout, the workout is what it is about.
  if (facts.workout case final workout?) {
    final now = 'Nu bezig: $workout';
    if (facts.exercise case final exercise?) {
      add(
        'Is mijn gewicht goed voor $exercise?',
        now,
        SuggestionReason.workout,
      );
      add(
        '$exercise voelt zwaar vandaag, wat doe ik?',
        now,
        SuggestionReason.workout,
      );
      add(
        'Waarmee vervang ik $exercise als het toestel bezet is?',
        now,
        SuggestionReason.workout,
      );
    }
    add(
      'Hoeveel rust neem ik tussen mijn sets?',
      now,
      SuggestionReason.workout,
    );
  }

  if (facts.deloadDay case final day?) {
    add(
      'Hoe train ik in deze deload?',
      'Deload: dag $day van ${facts.deloadDays}',
      SuggestionReason.deload,
    );
  }

  if (facts.workout == null) {
    if (facts.plannedToday case final routine?) {
      add(
        'Hoe pak ik $routine vandaag aan?',
        'Gepland voor vandaag',
        SuggestionReason.today,
      );
    } else if (facts.workouts >= 3) {
      add(
        'Wat train ik vandaag?',
        'Niets gepland vandaag',
        SuggestionReason.today,
      );
    }
  }

  if (facts.recovering case final muscle?) {
    add(
      'Mag ik vandaag $muscle trainen?',
      '${_capital(muscle)} nog ${facts.recoveringHours} u herstel',
      SuggestionReason.recovery,
    );
  }

  if (facts.stalled case final exercise?) {
    final weeks = facts.stalledWeeks ?? 4;
    add(
      'Hoe kom ik voorbij mijn stilstand op $exercise?',
      'Staat $weeks ${weeks == 1 ? 'week' : 'weken'} stil',
      SuggestionReason.stalled,
    );
  }

  if (facts.deloadDue && facts.deloadDay == null) {
    add('Is het tijd voor een deload?', switch (facts.weeksWithoutBreak) {
      final weeks? when weeks > 0 => '$weeks weken zonder pauze',
      _ => 'Oefeningen staan stil',
    }, SuggestionReason.deload);
  }

  if (facts.record case final exercise?) {
    add(
      'Ik zette een record op $exercise. Hoe ga ik verder?',
      'Nieuw record deze week',
      SuggestionReason.record,
    );
  }

  if (facts.daysSinceLast case final days? when days >= 7) {
    add(
      'Hoe pak ik het weer op na $days dagen?',
      '$days dagen niet getraind',
      SuggestionReason.comeback,
    );
  }

  if (facts.lastNight case final night?) {
    final hours = night.inHours;
    final minutes = night.inMinutes.remainder(60);
    add(
      'Ik sliep maar $hours u ${minutes.toString().padLeft(2, '0')}. Hoe '
          'zwaar train ik vandaag?',
      'Korte nacht',
      SuggestionReason.sleep,
    );
  }

  if (facts.workouts < 3) {
    add(
      'Maak een schema voor drie dagen per week.',
      'Om te beginnen',
      SuggestionReason.start,
    );
    add(
      'Welke oefeningen passen bij mijn zaal?',
      'Om te beginnen',
      SuggestionReason.start,
    );
  }

  add(
    kAppQuestions[facts.dayOfYear % kAppQuestions.length],
    'Over de app',
    SuggestionReason.app,
  );

  // Enough to fill the first four, also on a quiet day.
  for (final question in const [
    'Doe ik genoeg voor mijn rug deze week?',
    'Hoeveel sets per spiergroep per week heb ik nodig?',
    'Hoe word ik sterker zonder langer te trainen?',
  ]) {
    if (found.length >= kSuggestionsShown) break;
    add(question, 'Algemeen', SuggestionReason.general);
  }
  return found;
}

String _capital(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
