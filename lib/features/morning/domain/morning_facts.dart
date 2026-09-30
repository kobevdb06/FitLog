/// What a morning report says: the night, its score, the heart readings and
/// the muscles still recovering - worked out by the app, never by the coach.
///
/// The coach only puts it in words. Every number in a report comes from
/// here, so a report without a coach says the same things, just plainer.
library;

import '../../../core/calc/recovery.dart';
import '../../../core/calc/sleep_score.dart';
import '../../../core/db/database.dart';

/// How long after its session a ready muscle is still worth naming: the same
/// window the recovery screen asks about.
const Duration kReportRecentWindow = Duration(hours: 96);

class MorningNight {
  const MorningNight({
    required this.fellAsleepAt,
    required this.wokeAt,
    required this.fromWatch,
    this.lightMinutes,
    this.remMinutes,
    this.deepMinutes,
  });

  final DateTime fellAsleepAt;
  final DateTime wokeAt;
  final bool fromWatch;
  final int? lightMinutes;
  final int? remMinutes;
  final int? deepMinutes;

  Duration get length => wokeAt.difference(fellAsleepAt);
}

class MuscleLeft {
  const MuscleLeft({required this.muscle, required this.left});

  final String muscle;
  final Duration left;
}

class MorningFacts {
  const MorningFacts({
    required this.day,
    this.night,
    this.score,
    this.hrvDrop,
    this.restingHrRise,
    this.recovering = const [],
    this.ready = const [],
  });

  /// Midnight at the start of the morning this is about.
  final DateTime day;

  /// The night that ended this morning, if there is one.
  final MorningNight? night;

  /// Its score, 0 to 100, when there is a night.
  final int? score;

  /// This morning against your usual: HRV below it as a share, resting heart
  /// rate above it in beats. Null without a watch or without a usual.
  final double? hrvDrop;
  final double? restingHrRise;

  /// Still recovering, the longest to go first.
  final List<MuscleLeft> recovering;

  /// Trained in the last few days and ready again.
  final List<String> ready;

  Map<String, Object?> toJson() => {
    'day': day.millisecondsSinceEpoch,
    if (night case final n?)
      'night': {
        'asleep': n.fellAsleepAt.millisecondsSinceEpoch,
        'woke': n.wokeAt.millisecondsSinceEpoch,
        'watch': n.fromWatch,
        'light': ?n.lightMinutes,
        'rem': ?n.remMinutes,
        'deep': ?n.deepMinutes,
      },
    'score': ?score,
    'hrvDrop': ?hrvDrop,
    'restingHrRise': ?restingHrRise,
    'recovering': [
      for (final m in recovering)
        {'muscle': m.muscle, 'minutes': m.left.inMinutes},
    ],
    'ready': ready,
  };

  factory MorningFacts.fromJson(Map<String, Object?> json) {
    DateTime at(Object? millis) =>
        DateTime.fromMillisecondsSinceEpoch((millis! as num).toInt());
    final night = json['night'] as Map<String, Object?>?;
    return MorningFacts(
      day: at(json['day']),
      night: night == null
          ? null
          : MorningNight(
              fellAsleepAt: at(night['asleep']),
              wokeAt: at(night['woke']),
              fromWatch: night['watch'] == true,
              lightMinutes: (night['light'] as num?)?.toInt(),
              remMinutes: (night['rem'] as num?)?.toInt(),
              deepMinutes: (night['deep'] as num?)?.toInt(),
            ),
      score: (json['score'] as num?)?.toInt(),
      hrvDrop: (json['hrvDrop'] as num?)?.toDouble(),
      restingHrRise: (json['restingHrRise'] as num?)?.toDouble(),
      recovering: [
        for (final m in (json['recovering'] as List? ?? const []))
          MuscleLeft(
            muscle: (m as Map)['muscle'] as String,
            left: Duration(minutes: (m['minutes'] as num).toInt()),
          ),
      ],
      ready: [for (final m in (json['ready'] as List? ?? const [])) '$m'],
    );
  }

  /// What the coach is given: the same facts, in words a model reads
  /// without a legend. Local times, rounded numbers, nothing else.
  Map<String, Object?> forCoach() {
    String clock(DateTime at) =>
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    return {
      'datum':
          '${day.year}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}',
      if (night case final n?)
        'nacht': {
          'in_slaap': clock(n.fellAsleepAt),
          'wakker': clock(n.wokeAt),
          'minuten': n.length.inMinutes,
          'licht_min': ?n.lightMinutes,
          'rem_min': ?n.remMinutes,
          'diep_min': ?n.deepMinutes,
        }
      else
        'nacht': 'onbekend',
      'slaapscore': ?score,
      if (hrvDrop case final drop?)
        'hrv_tegenover_gewoon_pct': -(drop * 100).round(),
      if (restingHrRise case final rise?)
        'rusthartslag_tegenover_gewoon': rise.round(),
      'herstellen_nog': [
        for (final m in recovering)
          {'spiergroep': m.muscle, 'uren': _hours(m.left)},
      ],
      'klaar': ready,
    };
  }
}

int _hours(Duration left) => (left.inMinutes / 60).ceil();

/// Works the facts out for the morning of [now].
MorningFacts buildMorningFacts({
  required DateTime now,
  required List<SleepEntryRow> nights,
  required List<VitalsDay> vitals,
  required List<RecoveryEstimate> estimates,
}) {
  final day = DateTime(now.year, now.month, now.day);

  SleepEntryRow? last;
  for (final row in nights) {
    final woke = DateTime.fromMillisecondsSinceEpoch(row.wokeAt);
    if (DateTime(woke.year, woke.month, woke.day) == day) last = row;
  }

  final morning = morningAgainstUsual(day, vitals);
  int? score;
  if (last != null) {
    score = sleepScore(
      asleep: Duration(milliseconds: last.wokeAt - last.fellAsleepAt),
      deepMinutes: last.deepMinutes,
      remMinutes: last.remMinutes,
      hrvDrop: morning.hrvDrop,
      restingHrRise: morning.restingHrRise,
    ).value;
  }

  final recovering = [
    for (final e in estimates)
      if (!e.isReadyAt(now))
        MuscleLeft(muscle: e.muscle, left: e.remainingAt(now)),
  ]..sort((a, b) => b.left.compareTo(a.left));
  final ready = [
    for (final e in estimates)
      if (e.isReadyAt(now) && now.difference(e.trainedAt) < kReportRecentWindow)
        e.muscle,
  ];

  return MorningFacts(
    day: day,
    night: last == null
        ? null
        : MorningNight(
            fellAsleepAt: DateTime.fromMillisecondsSinceEpoch(
              last.fellAsleepAt,
            ),
            wokeAt: DateTime.fromMillisecondsSinceEpoch(last.wokeAt),
            fromWatch: last.source != null,
            lightMinutes: last.lightMinutes,
            remMinutes: last.remMinutes,
            deepMinutes: last.deepMinutes,
          ),
    score: score,
    hrvDrop: morning.hrvDrop,
    restingHrRise: morning.restingHrRise,
    recovering: recovering,
    ready: ready,
  );
}

/// The report in plain sentences, for when there is no coach - and as the
/// notification's text when there is no coach text.
String morningSummary(MorningFacts facts) {
  String length(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    return minutes == 0 ? '${d.inHours} u' : '${d.inHours} u $minutes';
  }

  final lines = <String>[];
  if (facts.night case final night?) {
    lines.add('Je sliep ${length(night.length)}, slaapscore ${facts.score}.');
  } else {
    lines.add('Van vannacht is er geen nacht bekend.');
  }

  final heart = [
    if (facts.hrvDrop case final drop? when drop > kHrvDropNoEffect)
      'je HRV ligt ${(drop * 100).round()}% onder je gewone',
    if (facts.restingHrRise case final rise? when rise > kRestingHrRiseNoEffect)
      'je rusthartslag ligt ${rise.round()} slagen hoger dan gewoonlijk',
  ];
  if (heart.isNotEmpty) {
    final sentence = heart.join(' en ');
    lines.add('${sentence[0].toUpperCase()}${sentence.substring(1)}.');
  }

  if (facts.recovering.isEmpty) {
    lines.add(
      facts.ready.isEmpty
          ? 'Geen spiergroep in herstel.'
          : 'Alles is hersteld: ${facts.ready.join(', ')}.',
    );
  } else {
    lines.add(
      'Nog in herstel: ${[for (final m in facts.recovering) '${m.muscle} (nog ${_hours(m.left)} u)'].join(', ')}.',
    );
    if (facts.ready.isNotEmpty) {
      lines.add('Klaar: ${facts.ready.join(', ')}.');
    }
  }
  return lines.join(' ');
}

/// The report's one-line title, for the notification.
String morningTitle(MorningFacts facts) => facts.score == null
    ? 'Ochtendrapport'
    : 'Ochtendrapport · slaapscore ${facts.score}';
