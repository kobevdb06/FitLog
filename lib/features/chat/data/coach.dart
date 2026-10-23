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
import '../domain/coach_proposal.dart';

/// How much the coach may write in one answer - lookups included, and on a
/// model that thinks first, its thinking too.
const int kCoachMaxTokens = 1024;

/// The same in the conversation of a schema, and on its Sunday evening.
///
/// A whole schema is one lookup: five sessions of six exercises is thousands
/// of tokens before the model has said a word, and a Gemini 3 model thinks
/// it over first, within the same limit. At 1024 the answer was cut off
/// before the schema was written, and came back empty. Only what is written
/// is paid for; the limit costs nothing.
const int kPlanMaxTokens = 16384;

/// How often the coach may look something up while making or changing a
/// schema: its gym and history, every exercise by name, the schema itself,
/// and once more when a name was wrong. Four rounds - enough for a question -
/// ran out before the schema was written.
const int kPlanToolRounds = 8;

/// How many earlier turns ride along in the conversation of a schema.
///
/// Fewer than elsewhere: the state of the schema - its outline, and every
/// session made so far - goes along with the instructions every time, so
/// the turns are only needed for what was just said.
const int kPlanHistoryTurns = 6;

/// One turn of a stored conversation.
class CoachTurn {
  const CoachTurn({
    required this.role,
    required this.text,
    this.images = const [],
  });

  final String role;
  final String text;

  /// The photos that were sent with this turn, if they are still worth
  /// sending.
  final List<CoachImage> images;

  CoachMessage toMessage() => role == 'assistant'
      ? CoachMessage.assistant(text: text)
      : CoachMessage.user(text, images: images);
}

/// What came back, ready to be written down.
class CoachAnswer {
  const CoachAnswer({
    required this.text,
    required this.lookups,
    required this.usage,
    required this.requests,
    this.proposals = const [],
  });

  final String text;

  /// In Dutch, what the coach looked up in the database to answer.
  final List<String> lookups;

  final CoachUsage usage;

  /// What the coach offered to add. Offers, not changes: nothing exists until
  /// the user taps the card.
  final List<CoachProposal> proposals;

  /// How many calls to the service this one answer took.
  ///
  /// One question is not one request: every round of looking something up is
  /// another call, and a daily free tier counts calls.
  final int requests;
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

  /// Which model to ask, as the service names it. A plain string so a model
  /// this app has never heard of still works.
  final String model;
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

  /// [onText], when given, gets the answer while it is being written, piece
  /// by piece. Text of a round that then turns out to look something up is
  /// not the answer: [onLookup] says so, with what is being looked up, and
  /// whoever shows the text starts over.
  Future<CoachAnswer> ask({
    required List<CoachTurn> history,
    required String question,
    List<CoachImage> images = const [],
    void Function(String text)? onText,
    void Function(String lookup)? onLookup,
  }) async {
    final keep = tools.planId == null ? historyTurns : kPlanHistoryTurns;
    final trimmed = history.length > keep
        ? history.sublist(history.length - keep)
        : history;

    final messages = <CoachMessage>[
      for (final turn in trimmed) turn.toMessage(),
      CoachMessage.user(question, images: images),
    ];

    final lookups = <String>[];
    final proposals = <CoachProposal>[];
    var usage = CoachUsage.none;
    var requests = 0;

    final plan = tools.planId != null;
    final maxTokens = plan ? kPlanMaxTokens : kCoachMaxTokens;
    final rounds = plan ? kPlanToolRounds : maxToolRounds;
    var retried = false;
    for (var round = 0; round <= rounds; round++) {
      final reply = onText == null
          ? await client.send(
              system: system,
              messages: messages,
              tools: tools.offered,
              model: model,
              maxTokens: maxTokens,
            )
          : await client.sendStreaming(
              system: system,
              messages: messages,
              tools: tools.offered,
              model: model,
              onText: onText,
              maxTokens: maxTokens,
            );
      usage = usage.plus(reply.usage);
      requests++;

      // A lookup written in a shape nobody can read: the same question once
      // more, which nearly always comes back right. Twice is not luck.
      if (reply.malformed && !reply.wantsTools && reply.text.isEmpty) {
        if (retried || round == rounds) {
          throw const CoachException(
            'De coach schreef een opzoeking die de app niet kon lezen. Vraag '
            'het nog eens.',
          );
        }
        retried = true;
        continue;
      }

      // Stopped at the limit with nothing to show: saying "no answer" would
      // be wrong - there was one, too long to fit.
      if (reply.cutOff && !reply.wantsTools && reply.text.isEmpty) {
        throw const CoachException(
          'Het antwoord werd afgebroken: het was langer dan de coach in één '
          'keer mag schrijven. Vraag het in kleinere stukken.',
        );
      }

      if (!reply.wantsTools) {
        return CoachAnswer(
          text: reply.text.isEmpty
              ? 'Ik heb hier geen antwoord op gevonden.'
              : reply.text,
          lookups: lookups,
          usage: usage,
          requests: requests,
          proposals: proposals,
        );
      }

      // The last round is spent answering, not looking up: otherwise the loop
      // could end on a question nobody answers.
      if (round == rounds) {
        return CoachAnswer(
          text: reply.text.isEmpty
              ? 'Ik bleef in je logboek zoeken zonder eruit te komen. Stel de '
                    'vraag wat nauwer?'
              : reply.text,
          lookups: lookups,
          usage: usage,
          requests: requests,
          proposals: proposals,
        );
      }

      messages.add(
        CoachMessage.assistant(
          text: reply.text,
          toolCalls: reply.toolCalls,
          textSignature: reply.textSignature,
        ),
      );

      final results = <CoachToolResult>[];
      for (final call in reply.toolCalls) {
        final lookup = await tools.run(call.name, call.input);
        onLookup?.call(lookup.summary);
        if (!lookups.contains(lookup.summary)) lookups.add(lookup.summary);
        if (lookup.proposal case final proposal?) proposals.add(proposal);
        results.add(CoachToolResult(call: call, json: lookup.json));
      }
      messages.add(CoachMessage.results(results));
    }

    // Unreachable: the loop returns on its last round.
    throw StateError('coach loop ended without an answer');
  }
}
