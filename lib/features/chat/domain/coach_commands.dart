/// What can be typed after a / in the coach, the way Claude Code has its
/// /compact: things the app does by itself, which send nothing, and
/// questions the coach answers in one go.
library;

/// A command of the app's own.
enum CoachCommand {
  nieuw('Een nieuw gesprek'),
  onthoud('Zet iets in het geheugen', argument: 'tekst'),
  geheugen('Wat de coach onthoudt'),
  kosten('Wat dit gesprek en vandaag kostten'),
  pin('Dit gesprek vastpinnen of losmaken'),
  map('Dit gesprek in een map', argument: 'naam'),
  help("Alle commando's"),
  samenvat('Vat samen, ga verder in een nieuw gesprek', asks: true),
  workout('Over je laatste workout, met je prompt', asks: true),
  week('Over je laatste zeven dagen, met je prompt', asks: true),
  maand('Over deze maand, met je prompt', asks: true),
  schema('Hoe je schema ervoor staat', asks: true, onlyInPlan: true);

  const CoachCommand(
    this.about, {
    this.argument,
    this.asks = false,
    this.onlyInPlan = false,
  });

  /// What it does, in a few words.
  final String about;

  /// What goes after it, by name; null when nothing does.
  final String? argument;

  /// It asks the coach: one question on your key. The others stay on the
  /// phone.
  final bool asks;

  /// Only where it means something: in the conversation of a schema.
  final bool onlyInPlan;

  /// How it is typed: `/nieuw`.
  String get typed => '/$name';
}

/// A command as it was typed.
sealed class TypedCommand {
  const TypedCommand();
}

/// One of the app's, with what came after it.
final class AppCommand extends TypedCommand {
  const AppCommand(this.command, [this.argument = '']);

  final CoachCommand command;
  final String argument;
}

/// One of your own questions, by the name you gave it.
final class OwnCommand extends TypedCommand {
  const OwnCommand(this.name, this.question);

  final String name;
  final String question;
}

/// Something after a / that is no command: nothing goes out for it.
final class NoCommand extends TypedCommand {
  const NoCommand(this.typed);

  /// As it was typed, with its /.
  final String typed;
}

/// [text] as a command, or null when it is a question. Whatever starts with
/// a / is meant as one: a question never does. [own] is your questions by
/// the name you gave them.
TypedCommand? readCommand(String text, {Map<String, String> own = const {}}) {
  final words = text.trim();
  if (!words.startsWith('/')) return null;
  final match = RegExp(r'^/(\S*)\s*([\s\S]*)$').firstMatch(words)!;
  final typed = match.group(1)!;
  final name = typed.toLowerCase();
  final argument = match.group(2)!.trim();
  for (final command in CoachCommand.values) {
    if (command.name == name) return AppCommand(command, argument);
  }
  if (own[name] case final question?) return OwnCommand(name, question);
  return NoCommand('/$typed');
}

/// The name being typed after a /, while it is still being typed: `wo` for
/// `/wo`, and empty for a / alone. Null once a space follows, or without a
/// / in front.
String? commandBeingTyped(String text) =>
    RegExp(r'^/([A-Za-z0-9]*)$').firstMatch(text)?.group(1)!.toLowerCase();

/// How long the name of a command of your own may be.
const int kCommandNameLength = 20;

/// [typed] as the name of a command of your own: without a / in front, in
/// small letters.
String commandName(String typed) =>
    typed.trim().replaceFirst(RegExp('^/+'), '').toLowerCase();

/// What is wrong with [name] for a command of your own, or null when it
/// will do. [taken] are the names your other questions have.
String? commandProblem(String name, {Iterable<String> taken = const []}) {
  if (!RegExp(r'^[a-z0-9]+$').hasMatch(name)) {
    return 'Alleen letters en cijfers, zonder spaties of accenten.';
  }
  if (name.length > kCommandNameLength) {
    return 'Hoogstens $kCommandNameLength tekens.';
  }
  if (CoachCommand.values.any((command) => command.name == name)) {
    return '/$name is al een commando van de app.';
  }
  if (taken.contains(name)) return '/$name heb je al voor een andere vraag.';
  return null;
}

/// What /samenvat tells the coach: the summary starts a new conversation,
/// which then goes on without sending the whole old one along every time.
const String kSummarySystem =
    'Je vat een gesprek samen tussen de gebruiker en de coach van FitLog, '
    'een logboek voor krachttraining. Je krijgt het gesprek. De samenvatting '
    'wordt het begin van een nieuw gesprek, dat daarmee verder moet kunnen '
    'zonder het oude. Schrijf in het Nederlands, in de je-vorm tegen de '
    'gebruiker, in hoogstens tien korte punten: waar het over ging, wat er '
    'besloten of aangeraden werd, de cijfers die ertoe doen (gewichten, '
    'sets, herhalingen, dagen), en wat nog open staat. Alleen wat in het '
    'gesprek staat: verzin niets.';

/// How much of a conversation /samenvat sends at most, in characters: a
/// few thousand tokens. Summing up is what a conversation that grew too
/// expensive is for, and it used to send all of it (DECISIONS 251).
const int kSummaryMaxChars = 24000;

/// A conversation as the coach reads it for /samenvat: who said what, in
/// order - the newest part, up to [maxChars], with a word on what was left
/// out.
String conversationText(
  String title,
  Iterable<({String role, String text})> messages, {
  int maxChars = kSummaryMaxChars,
}) {
  final lines = [
    for (final message in messages)
      '${message.role == 'user' ? 'Gebruiker' : 'Coach'}: ${message.text}',
  ];
  final kept = <String>[];
  var used = 0;
  for (final line in lines.reversed) {
    if (kept.isNotEmpty && used + line.length > maxChars) break;
    kept.insert(0, line);
    used += line.length;
  }
  final left = lines.length - kept.length;
  return [
    'Het gesprek "$title":',
    if (left > 0)
      '(${left == 1 ? 'Het eerste bericht is' : 'De eerste $left berichten zijn'} '
          'weggelaten; vat het deel hieronder samen.)',
    ...kept,
  ].join('\n\n');
}
