/// One question, one answer, and the lookups in between.
///
/// The model may ask the app to look something up before it can answer. That
/// loop lives here: send, run whatever it asked for, send the results back,
/// repeat until it stops asking or until the ceiling is reached. The ceiling
/// matters - every round is another request the user pays for.
///
/// Which service is on the other end is the client's business, not this
/// file's: the conversation is kept in the app's own shape.
library;

import 'ai_client.dart';
import 'coach_tools.dart';

/// One turn of a stored conversation.
class CoachTurn {
  const CoachTurn({required this.role, required this.text});

  final String role;
  final String text;

  CoachMessage toMessage() => role == 'assistant'
      ? CoachMessage.assistant(text: text)
      : CoachMessage.user(text);
}

/// What came back, ready to be written down.
class CoachAnswer {
  const CoachAnswer({
    required this.text,
    required this.lookups,
    required this.usage,
  });

  final String text;

  /// In Dutch, what the coach looked up in the database to answer.
  final List<String> lookups;

  final CoachUsage usage;
}

class Coach {
  Coach({
    required this.client,
    required this.tools,
    required this.model,
    required this.system,
  });

  final AiClient client;
  final CoachTools tools;
  final CoachModel model;
  final String system;

  /// How many times the coach may look something up before it has to answer
  /// with what it has.
  static const int maxToolRounds = 4;

  /// How many earlier turns ride along with a new question.
  ///
  /// The whole thread is sent again every time, so a long conversation gets
  /// expensive quietly. Twenty turns is a real conversation and a bounded
  /// bill.
  static const int historyTurns = 20;

  Future<CoachAnswer> ask({
    required List<CoachTurn> history,
    required String question,
  }) async {
    final trimmed = history.length > historyTurns
        ? history.sublist(history.length - historyTurns)
        : history;

    final messages = <CoachMessage>[
      for (final turn in trimmed) turn.toMessage(),
      CoachMessage.user(question),
    ];

    final lookups = <String>[];
    var usage = CoachUsage.none;

    for (var round = 0; round <= maxToolRounds; round++) {
      final reply = await client.send(
        system: system,
        messages: messages,
        tools: CoachTools.definitions(),
        model: model,
      );
      usage = usage.plus(reply.usage);

      if (!reply.wantsTools) {
        return CoachAnswer(
          text: reply.text.isEmpty
              ? 'Ik heb hier geen antwoord op gevonden.'
              : reply.text,
          lookups: lookups,
          usage: usage,
        );
      }

      // The last round is spent answering, not looking up: otherwise the loop
      // could end on a question nobody answers.
      if (round == maxToolRounds) {
        return CoachAnswer(
          text: reply.text.isEmpty
              ? 'Ik bleef in je logboek zoeken zonder eruit te komen. Stel de '
                    'vraag wat nauwer?'
              : reply.text,
          lookups: lookups,
          usage: usage,
        );
      }

      messages.add(
        CoachMessage.assistant(text: reply.text, toolCalls: reply.toolCalls),
      );

      final results = <CoachToolResult>[];
      for (final call in reply.toolCalls) {
        final lookup = await tools.run(call.name, call.input);
        if (!lookups.contains(lookup.summary)) lookups.add(lookup.summary);
        results.add(CoachToolResult(call: call, json: lookup.json));
      }
      messages.add(CoachMessage.results(results));
    }

    // Unreachable: the loop returns on its last round.
    throw StateError('coach loop ended without an answer');
  }
}
