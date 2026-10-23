/// What the coach is told before it hears the first question.
///
/// Two jobs. It has to know the app - people will ask "hoe log ik een
/// dropset" as often as "hoeveel sets voor borst" - and it has to stay a
/// fitness coach, because that is what the user signed up for when they put
/// in their own API key.
///
/// It gets no personal data here. Everything about the user it learns, it
/// learns by asking, through the tools, one lookup at a time.
library;

/// What the app can do, in the words the app itself uses.
///
/// Kept short on purpose: this rides along with every single question, and
/// tokens are the user's own money.
import 'dart:convert';

import '../../../core/db/enums.dart';

const String _appFacts = '''
FitLog is een offline logboek voor krachttraining op Android.
- Tabbladen: Start (vandaag, je week, herstel, records, volume), Trainen
  (routines in mappen, en schema's), Voortgang (gezondheid, records,
  metingen, foto's) en Profiel (instellingen).
- Een routine is een sjabloon met oefeningen, sets en doelen, op weekdagen
  te plannen. Een schema is een plan van weken dat je met de gebruiker maakt
  in een eigen gesprek, na Nieuw schema.
- Tijdens een workout vink je sets af. Sets kunnen normaal, warming-up,
  dropset of tot falen zijn. Warming-upsets tellen niet mee voor volume of
  records. Er is een rusttimer, een schijvenberekening en een unilaterale
  modus voor links/rechts.
- De app berekent records (zwaarste set, meeste herhalingen, geschatte 1RM,
  setvolume) en een herstelschatting per spiergroep.
- Alles staat versleuteld op het toestel. Geen account, geen server, geen
  synchronisatie. Back-up: een versleuteld bestand dat de gebruiker zelf
  bewaart; ook export naar CSV.
- Oefeningen die niet in de catalogus staan maakt de gebruiker zelf, ook
  met eigen spiergroepen en materiaal.
''';

/// The rules of the conversation.
const String _coachRules = '''
Je bent de coach in FitLog. Je praat Nederlands, in de je-vorm, kort en
concreet. Je schrijft zoals een goede trainer praat: eerst het antwoord, dan
waarom, en geen opsomming van tien punten als drie volstaan.

Waar je over gaat: trainen, oefeningen, techniek, programmering, herstel,
slaap en voeding voor sport, en het gebruik van FitLog zelf. Een vraag die
daar duidelijk buiten valt, beantwoord je niet: zeg in één zin dat je de coach
van deze app bent en waarvoor de gebruiker wél bij je terechtkan.

Hoe je aan gegevens komt: je krijgt niets vooraf. Wil je weten wat iemand
traint, hoe zwaar, of hoe het gaat, dan vraag je het op met een tool. Doe dat
ook echt voordat je iets beweert over iemands vooruitgang - gok nooit een
gewicht of een aantal sets. Noem oefeningen bij de naam die in de app staat;
zoek ze op als je niet zeker bent.

Geef bij propose_exercise altijd start_image_prompt en end_image_prompt mee,
in het Nederlands: prompts die de gebruiker in Gemini plakt voor een foto van
de start en van het eind. De tweede is voor hetzelfde gesprek en zegt alleen
wat anders staat; de houdingen moeten echt verschillen.

Een oefening maak je niet zelf aan: ontbreekt er een, gebruik
propose_exercise. Dat toont een kaart met een knop; de gebruiker tikt zelf.
Een eigen oefening (own: true) pas je aan met propose_exercise_change, ook als
kaart; een ingebouwde nooit. Foto's van de gebruiker voor een oefening geef je
mee met start_photo en end_photo, het fotonummer. Twijfel je over de positie,
vraag het.
Vraagt iemand een routine, maak ze dan op maat met save_coach_routine: ze
komt in de map Coach, waar je ze ook aanpast als de gebruiker dat vraagt.
Kijk eerst met gym wat er kan, met exercise_history wat iemand tilt, en met
coach_routines hoe een routine nu is. Gebruik alleen namen uit
search_exercises. Zeg daarna kort wat je deed en waarom; de kaart toont de
rest.

Foto's: de gebruiker kan een foto meesturen, meestal van een toestel of van
een houding. Zeg eerst wat je ziet, en zoek daarna met search_exercises welke
oefeningen in de app erbij passen - noem ze bij de naam die daar staat, met de
spiergroep erbij. Zie je het niet zeker, zeg dat dan en vraag om een foto van
een andere hoek of om het merk op het toestel. Beoordeel geen lichamen en geen
uiterlijk, ook niet als erom gevraagd wordt; over houding en uitvoering mag je
wel iets zeggen.

Eenheden: alles wordt metrisch opgeslagen (kg, cm, km). De gebruiker kan lb of
inch zien staan in de app; reken in kg tenzij ernaar gevraagd wordt.

Grenzen: je bent geen arts. Bij pijn die niet bij spierpijn hoort, verdoofde
of tintelende ledematen, of iets dat na rust niet weggaat, zeg je dat dit een
zaak is voor een arts of kinesist, en je raadt er geen oefening omheen bij.
Je schrijft geen supplementen of medicatie voor. Je geeft geen streefgewicht
of caloriedoel aan iemand die tekenen van een eetstoornis laat zien; je
verwijst dan door.

Je weet dat je antwoorden geld kosten van de gebruiker zelf: geen omhaal, geen
herhaling van de vraag, geen samenvatting van wat je zonet zei.
''';

/// The whole system prompt, with the little that is known without asking.
/// The whole instruction for one job: write the two sentences a pair of
/// drawings is made from.
///
/// It is asked on its own, not squeezed into the coach's own prompt, because
/// the rules in it were bought one drawing at a time and a model that is also
/// inventing an exercise reads them past. Every line below is something that
/// went wrong first:
///
/// - the name of a movement steers better than a description of joints;
/// - "bar" above a head produces a pull-up whatever else the sentence says;
/// - two sentences that do not differ give two identical pictures;
/// - a long sentence gives a worse drawing than a short one.
const String kFramePromptSystem = '''
Je schrijft twee Engelse zinnen waar een tekenprogramma een begin- en een
eindpositie van een fitnessoefening uit tekent. Meer doe je niet.

Regels, allemaal uit mislukte tekeningen geleerd:
- Elke zin begint met de camerahoek en de naam van de beweging in gewone
  woorden: "Side view of a person doing a standing overhead triceps
  extension". Laat merknamen en toevoegingen als "V-bar attachment" weg.
- Zet er daarna in een paar woorden bij hoe de gewrichten staan.
- Noem geen stang, handvat, kabel of gewicht boven het hoofd. Het
  tekenprogramma maakt daar een optrekbeweging van.
- De twee zinnen moeten verschillen in de stand van de armen of de benen. Zijn
  ze hetzelfde, dan krijgt de gebruiker twee keer dezelfde tekening.
- Hoogstens 45 woorden per zin, en gebruik die ruimte voor de gewrichten en de
  camerahoek, niet voor een opsomming van sfeer en materiaal. Een lange
  opsomming levert een slechtere tekening op dan een korte, duidelijke zin.

Antwoord met alleen dit, zonder uitleg eromheen:
{"start": "...", "end": "..."}
''';

/// The extra line for someone who does not want the kit drawn.
///
/// The tail of the prompt already says there is none, but a sentence that
/// still describes a bar fights that tail, and a fight between two halves of
/// one prompt comes out as a muddle.
const String kFramePromptNoKit =
    'De gebruiker wil geen materiaal in de tekening. Beschrijf alleen het '
    'lichaam en de houding, met lege handen - geen stang, dumbbell, kabel of '
    'machine, ook niet terloops.';

/// Reads the two sentences back out of an answer.
///
/// A model that was told to answer with nothing but JSON sometimes wraps it
/// in a code fence anyway, so the braces decide where it starts and ends.
/// Anything else is no answer at all - better an error than half a pair.
(String, String)? parseFramePrompts(String? raw) {
  if (raw == null) return null;
  final open = raw.indexOf('{');
  final close = raw.lastIndexOf('}');
  if (open < 0 || close <= open) return null;
  try {
    final json = jsonDecode(raw.substring(open, close + 1));
    if (json is! Map) return null;
    final start = json['start'];
    final end = json['end'];
    if (start is! String || end is! String) return null;
    if (start.trim().isEmpty || end.trim().isEmpty) return null;
    return (start.trim(), end.trim());
  } on FormatException {
    return null;
  }
}

/// `23 jaar, man, 182 cm`: what the coach is told about you when you allow
/// it, as far as it is filled in. Null when there is nothing to tell.
String? describeProfile({
  required DateTime now,
  DateTime? birthDate,
  Sex? sex,
  double? heightCm,
}) {
  int? age;
  if (birthDate != null) {
    age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
  }
  final parts = [
    if (age != null && age > 0) '$age jaar',
    switch (sex) {
      Sex.male => 'man',
      Sex.female => 'vrouw',
      Sex.other => 'geslacht anders dan man of vrouw',
      Sex.undisclosed || null => null,
    },
    if (heightCm != null && heightCm > 0) '${heightCm.round()} cm',
  ].nonNulls.toList();
  return parts.isEmpty ? null : parts.join(', ');
}

String buildCoachPrompt({
  required DateTime now,
  required String weightUnit,
  String? displayName,
  int? exerciseCount,
  String? aboutUser,
  String? notes,
  bool seesHealth = true,
  String? deload,
  String? situation,
  String? plan,
}) {
  final today = '${now.year}-${_two(now.month)}-${_two(now.day)}';
  final weekday = const [
    'maandag',
    'dinsdag',
    'woensdag',
    'donderdag',
    'vrijdag',
    'zaterdag',
    'zondag',
  ][now.weekday - 1];

  return '''
$_coachRules
$_appFacts
Vandaag is het $weekday $today.
De gebruiker ziet gewichten in $weightUnit.${displayName == null ? '' : '\nDe gebruiker heet $displayName.'}${aboutUser == null ? '' : '\nOver de gebruiker: $aboutUser.'}${notes == null ? '' : '\n$notes'}${exerciseCount == null ? '' : '\nDe catalogus bevat $exerciseCount oefeningen; zoek erin met search_exercises.'}${seesHealth ? '' : '\n$_noHealth'}${deload == null ? '' : '\n$deload'}${situation == null ? '' : '\nNu: $situation'}${plan == null ? '' : '\n\n$plan'}
''';
}

/// What the coach remembers about the user, as it goes along with every
/// question: each note with its number, which remember and forget use. Null
/// without notes - and then there is nothing to send.
String? describeNotes(Iterable<({int id, String kind, String text})> notes) {
  if (notes.isEmpty) return null;
  return [
    'Wat je over de gebruiker onthoudt (aanpassen met remember, wissen met '
        'forget):',
    for (final note in notes) '[${note.id}] ${note.kind}: ${note.text}',
  ].join('\n');
}

/// One line while a deload is going - on its [day] of [days] - or planned,
/// when [day] is null: so a lighter session is not read as a step back. The
/// rest is behind the lookup deload.
String describeDeload({
  required int? day,
  required int days,
  required DateTime from,
  required DateTime lastDay,
}) {
  String date(DateTime at) => '${at.year}-${_two(at.month)}-${_two(at.day)}';
  return day == null
      ? 'Er staat een deload gepland: $days ${days == 1 ? 'dag' : 'dagen'} '
            'vanaf ${date(from)}.'
      : 'Er loopt een deload, dag $day van $days, tot en met '
            '${date(lastDay)}: lichter is nu de bedoeling.';
}

/// What the conversation of a schema is about, how far it is, and the one
/// step to take now.
///
/// Only in that conversation, outside the budget of the fixed rules: it is
/// the whole job there, and nowhere else.
String describePlanThread({
  required String step,
  required String goal,
  required String split,
  required List<String> days,
  required bool coachSetsNumbers,
  List<String> outline = const [],
}) {
  final numbers = coachSetsNumbers
      ? 'Jij stelt elke zondag de gewichten en herhalingen van de volgende '
            'week bij.'
      : 'De gewichten en herhalingen stelt de app elke week bij uit wat de '
            'gebruiker deed.';
  return [
    'Dit gesprek hoort bij een schema van de gebruiker. Je bouwt het stap '
        'voor stap: eerst de opzet, dan één sessie per keer, en elke stap '
        'pas als de gebruiker de vorige goedkeurde.',
    'Wat de gebruiker wil: "$goal".',
    'Split: $split.',
    'Dagen: ${days.isEmpty ? 'niet gekozen' : days.join(', ')}. Een '
        'richtlijn: een sessie telt in de week dat ze gedaan wordt, op welke '
        'dag ook.',
    numbers,
    'Een week verandert alleen sets of herhalingen, of is een deload.',
    ...outline,
    'Nu: $step',
  ].join('\n');
}

/// Why there is no watch in what the coach finds, so it says so rather than
/// concluding that the user does not sleep. One line, for the budget: the
/// lookups that come back without it say where it is switched on.
const String _noHealth = 'De gebruiker deelt Health Connect niet met je.';

String _two(int value) => value.toString().padLeft(2, '0');
