# Plan: het coachvenster

> **Afgerond.** Het coachvenster is gebouwd. De versie- en schemanummers
> hieronder zijn die van toen (1.69.1, schema 58); de app staat nu op schema 65.

Goedgekeurd op 3 november 2026, na een mockup met vier schermen (een schemagesprek met een
strook en "Over: Push A" boven het veld; het schemapaneel van rechts; Vastgepind en mappen in
het paneel met gesprekken; de lijst na een `/`). De maker: "zoals in de mockup is goed", de lijst
met commando's "is denk ik al goed", en "je mag alles klaarzetten om te bouwen".

## Stand vóór dit plan

- Geplande prompts zijn klaar: DECISIONS 233 en 234, commits `a6bac52` en `88ef6e5`, schema
  v58. Nog niet op de gsm, nog niet op GitHub. De gsm heeft 1.69.1.
- De maker wil het op zijn gsm testen. Na dit plan: 1.70.0 maken (zie onderaan) en vragen of
  GitHub meteen mag of pas na zijn test.

## Werkwijze (vast)

Eén commit per stuk hieronder, conventional commits, oorzaak in de body bij een fix. Een fix
begint met een falende test. `flutter analyze` schoon en de tests groen na elk stuk; de hele
suite op de achtergrond, geen code wijzigen terwijl ze loopt. Elke afwijking in DECISIONS
(volgende nummer: 235). Migraties alleen optellen. Alleen testen op de emulator, op 360dp
(`wm density 480`, `font_scale` 1.3 en 1.4) en daarna terugzetten. Geen echte coachvragen op de
emulator: zet vliegtuigmodus aan (`cmd connectivity airplane-mode enable`) en daarna weer uit.
Handleiding en privacyverklaring bijwerken waar iets verandert. Python-bewerkingen via de
Write-tool in de scratchpad, nooit `dart format lib` (alleen de aangeraakte bestanden).

## 1. Een bestaand gesprek opent op het laatste bericht (fix)

Wat de maker bedoelt: de coach opent bij het starten nog altijd op een leeg gesprek (zoals
DECISIONS 217). Maar open je zelf een gesprek uit het verleden - uit het paneel, een melding,
*Open het gesprek*, *Verder vragen* - dan moet het op het laatste bericht openen, niet bovenaan.

- Oorzaak: `lib/features/chat/presentation/coach_screen.dart`, de `ListView.builder` met
  `controller: _scroll` (rond regel 260) begint bovenaan; `_follow` en `_toBottom` springen alleen
  terwijl de coach schrijft.
- Aanpak: `reverse: true`, met de index omgekeerd (het nieuwste bericht is index 0, `_Writing`
  is index 0 terwijl er geschreven wordt). Dan begint de lijst onderaan zonder sprong, ook als
  foto's nog laden. `_follow` wordt overbodig (onderaan is positie 0); `_toBottom` wordt
  `animateTo(0)`. Let op `_questionBefore(messages, index)`: die rekent met de oude index.
- Eerst een falende widgettest: een gesprek met 30 berichten openen → het laatste bericht is te
  zien, het eerste niet.

## 2. Vastpinnen en mappen

- Schema v59, alleen optellen: tabel `chat_folders` (id, name, sort_order, created_at); op
  `chat_threads` de kolommen `folder_id` (tekst, null) en `pinned` (bool, standaard false). Geen
  verwijzing (zie de redenering in DECISIONS 220).
- `chat_dao.dart`: vastpinnen en losmaken, naar een map, uit een map, map maken, hernoemen,
  verwijderen (de gesprekken blijven, hun `folder_id` wordt null), mappen volgen als stroom.
- `coach_drawer.dart`, tabblad Chats: bovenaan *Vastgepind*, dan elke map inklapbaar (naam en
  aantal), dan *Nu*, *Vandaag*, ... zonder wat hierboven al staat. Het menu van een gesprek (⋮
  en lang drukken) krijgt *Vastpinnen* of *Losmaken*, *Naar map…* (een blad met de mappen en
  *Nieuwe map*) en *Uit map halen*. Het menu van een map: *Hernoemen*, *Verwijderen*. Zoeken
  blijft over alles. Schema's hebben hun eigen tabblad en krijgen dit niet.
- Tests: de DAO, een widgettest van het paneel, een migratietest v58 → v59.

## 3. Commando's na een `/`

- In het invoerveld (`_Ask` in `coach_screen.dart`): begint de tekst met `/`, dan staat er een
  lijst boven het veld, gefilterd op wat al getypt is. Per regel: de naam, een korte uitleg, en
  *gratis* of *1 vraag*. Een tik vult het commando in (met argument) of voert het uit.
- Gratis, op de gsm, er gaat niets naar Google:
  - `/nieuw` - een nieuw gesprek;
  - `/onthoud <tekst>` - `coachNotesDao.add`, met hetzelfde kaartje als wanneer de coach iets
    onthoudt; vol is vol, zoals daar;
  - `/geheugen` - opent *Wat de coach onthoudt* (`Routes.coachMemory`);
  - `/kosten` - dit gesprek (som van requests en tokens van zijn antwoorden) en vandaag
    (`usageSince`), als bericht van de app, niet van de coach;
  - `/pin` en `/map <naam>` - dit gesprek vastpinnen, of in een map (die desnoods eerst maken);
  - `/help` - alle commando's, ook je eigen.
- Eén vraag:
  - `/samenvat` - jouw `/compact`. De coach vat het gesprek samen met een eigen korte opdracht
    zonder tools (zoals de geplande prompts, via `askMoment`-achtig pad); er begint een nieuw
    gesprek met die samenvatting als eerste bericht ("Verder uit: <titel>"), het oude blijft.
    Waarom: elke vraag stuurt het hele gesprek mee, dus een lang gesprek wordt elke vraag duurder.
  - `/workout`, `/week`, `/maand` - dezelfde feiten en de prompt van dat geplande moment (ook als
    het uit staat), maar het antwoord komt in dit gesprek, als vraag en antwoord, om op door te
    gaan. Hergebruik `momentFacts` en `buildMomentSystem`.
  - `/schema` - alleen in een schemagesprek: een gewone vraag met tools, "Geef een stand van
    zaken van dit schema".
- Eigen commando's: `quick_questions` krijgt een kolom `command` (tekst, null; v59, samen met
  stuk 2). In de editor van de snelle vragen een korte naam (kleine letters en cijfers, uniek,
  niet gelijk aan een ingebouwd commando); `/naam` stelt die vraag.
- Een onbekend commando: een regel "Geen commando: /x", en er gaat niets weg.
- Tests: de parser (unit); de lijst verschijnt na `/`; gratis commando's sturen niets (een
  MockClient die telt: 0); `/samenvat` maakt een nieuw gesprek en laat het oude staan.

## 4. Het schemapaneel, zoals Cowork

Alleen in een schemagesprek (`chat_threads.plan_id`).

- Een strook onder de titel, altijd: "Week X van N · d van s gedaan", en een chip "n voorstel(len)"
  als er iets wacht (`planOpenChangesProvider` bestaat). Een tik op de strook, of op het icoon
  rechtsboven in de balk, opent het paneel.
- Het paneel komt van rechts over de chat, zoals het paneel met gesprekken van links komt
  (`coach_drawer.dart` als voorbeeld), met vier tabbladen: *Week*, *Sessies*, *Weken*, *Instellen*.
  Bovenaan, over de tabbladen heen, de wachtende voorstellen met *Aanvaarden* en *Houden* - met de
  logica die er al is in `plan_build_cards.dart` (aanvaarden zonder het model opnieuw te vragen,
  DECISIONS 220).
- *Week*: ‹ week › om te bladeren; per sessie de dag (`planWeekday`), gedaan, open of gemist
  (zoals `_RunningPlan` in `plans_view.dart` het rekent), wat die week verandert (de weken van
  het schema), en *Start* (`startSession`).
- *Sessies*: elke sessie (`plansDao.sessions`) met haar focus en het aantal oefeningen. *Bespreek*
  zet "Over: <naam>" als chip boven het veld (met ✕); bij versturen gaat de sessie mee zoals de
  coach een routine voorleest (gedeelde code met de controles van routines in de map Coach), zodat
  hij ze niet hoeft op te zoeken. *Openen* gaat naar de routine-editor.
- *Weken*: het verloop van het hele schema, de deloadweek gemarkeerd, de week van nu.
- *Instellen*: de dagen (kiezen zoals in `plan_new_screen.dart`), wie de cijfers bijstelt (FitLog
  of de coach), het doel (tekst), en *Stoppen* (de bestaande actie). Rechtstreeks opgeslagen,
  zonder vraag aan de coach.
- Testen op 360dp met tekst 1,3 en 1,4, licht en donker.

## Daarna: 1.70.0

- Bump `pubspec.yaml` (1.70.0+92), `about_screen` `appVersion`, `docs/index.html` (knop, datum,
  grootte, en "Nieuw in 1.70": geplande prompts - de coach op momenten die je zelf kiest, in je
  eigen woorden -, eigen snelle vragen en commando's, gesprekken vastpinnen en in mappen, het
  schemapaneel). Minor: handleiding "Beschrijft versie 1.70." en privacy "voor versie 1.70".
- Twee builds, controle met aapt2 en apksigner (`CN=Kobe Van den Berk, O=FitLog, C=BE`), alleen in
  de hoofdmap. Installeren op de gsm pas na "kabel hangt eraan"; GitHub (`gh release create`) en
  push volgens de afspraak met de maker.
