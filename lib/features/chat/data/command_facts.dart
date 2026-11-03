/// What /workout, /week and /maand ask the coach about: the facts of their
/// geplande moment, as they stand now.
library;

import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../prompts/data/moment_facts.dart';
import '../../prompts/data/workout_facts.dart';
import '../../review/data/week_facts_builder.dart';
import '../domain/coach_commands.dart';

/// The facts a command asks about, and what went along in words - or why
/// there is nothing to ask about yet.
class CommandFacts {
  const CommandFacts({this.facts, this.sent = '', this.none});

  final Map<String, Object?>? facts;

  /// Shown under the answer, as what the coach looked up is.
  final String sent;

  /// Why nothing was asked; null when [facts] are there.
  final String? none;
}

/// The geplande moment whose prompt [command] asks with, or null for a
/// command that is not one.
CoachMoment? momentOf(CoachCommand command) => switch (command) {
  CoachCommand.workout => CoachMoment.workout,
  CoachCommand.week => CoachMoment.week,
  CoachCommand.maand => CoachMoment.month,
  _ => null,
};

/// The facts [command] asks about now: the last workout, the last seven
/// days, or this month next to the one before. Health Connect only when it
/// is shared with the coach.
Future<CommandFacts> commandFacts(
  AppDatabase db,
  CoachCommand command, {
  required DateTime now,
}) async {
  final health = (await db.settingsDao.getSettings()).coachSeesHealth;
  switch (command) {
    case CoachCommand.workout:
      final last = await db.workoutsDao.lastFinished();
      final facts = last == null
          ? null
          : await buildWorkoutFacts(db, last.id, health: health);
      if (last == null || facts == null) {
        return const CommandFacts(none: 'Je hebt nog geen workout afgerond.');
      }
      final day = Formatters.dayMonth(
        DateTime.fromMillisecondsSinceEpoch(last.startedAt),
      );
      return CommandFacts(
        facts: facts,
        sent: 'je laatste workout (${last.name}, $day)',
      );
    case CoachCommand.week:
      final week = await buildWeekFacts(
        db,
        DateTime(now.year, now.month, now.day - 6),
        now: now,
        healthConnect: health,
      );
      return CommandFacts(
        facts: week.forCoach(),
        sent: 'je laatste zeven dagen',
      );
    case CoachCommand.maand:
      final facts = await momentFacts(
        db,
        CoachMoment.month,
        MomentSubject.month(now),
        health: health,
        now: now,
      );
      if (facts == null) {
        return const CommandFacts(
          none:
              'Deze maand trainde je nog niet: er is niets om over te '
              'schrijven.',
        );
      }
      return CommandFacts(
        facts: facts,
        sent: 'je maand tot nu, naast de vorige',
      );
    default:
      throw ArgumentError.value(command, 'command', 'asks about no facts');
  }
}
