# Plan: wat hierna

Een plek om verder te zetten wat we hebben besproken. Het plan voor de coach staat apart in
[`AI-COACH-PLAN.md`](AI-COACH-PLAN.md); waarom iets werd gebouwd zoals het is, in
[`DECISIONS.md`](DECISIONS.md).

Stand op 28 oktober 2026, bij versie 1.66.1. De vier coachfuncties uit
`AI-COACH-PLAN.md` §3 (weekoverzicht, schema dat zich aanpast, check voor je training,
stilstand herkennen) zijn alle vier gebouwd.

---

## 1. De visie, als toets

Voor elk nieuw idee eerst deze vragen:

- **Blijft alles op de gsm?** Geen account, geen server, geen sync. De coach is de enige
  uitzondering, en die staat uit tot je hem zelf aanzet.
- **Rekent de app, en legt de AI alleen uit?** Wat te berekenen valt, doet FitLog zelf:
  gratis, meteen, en zonder dat er gegevens vertrekken.
- **Maakt het het logboek beter, of alleen voller?** Snel loggen, de vorige keer in
  beeld, zien of je sterker wordt en nooit gegevens verliezen gaan voor alles.

---

## 2. Richtingen die passen

In de volgorde waarin ze het meest opleveren.

### 2.1 Afwerken: een ronde langs elk scherm (aanbevolen)

Het Schema's-scherm en Lichaamsmetingen voelden verouderd tot ze naast de rest stonden
(DECISIONS 225 en 226). Andere schermen kunnen dat ook hebben.

Gedaan: Herstel en Gezondheid (227), Voortgang (228).

- Elk scherm nalopen op de emulator, op 360dp met tekstgrootte 1,3 en 1,4, in licht en
  donker.
- Per scherm noteren: wat dubbel staat, wat niet in de stijl van de rest past (kaarten,
  kleuren, knoppen), wat afgekapt wordt, wat een zwevende knop bedekt, wat weg mag.
- Een lijst opleveren; de gebruiker kiest wat aangepakt wordt, met mockups waar het om
  meer dan een detail gaat.

### 2.2 Betrouwbaarheid

Wat je niet merkt tot het misgaat.

- Een back-up terugzetten op een andere gsm, en een oude back-up op een nieuwe versie.
- Migraties van elke oude schemaversie (de tests dekken er veel; nagaan welke niet).
- Snelheid met jaren aan trainingen: een database met bijvoorbeeld 1.000 workouts
  genereren en Start, Voortgang, herstel en de coach-opzoekingen meten.

### 2.3 Wat je tijdens het trainen tegenkomt

FitLog een tijdje gebruiken zoals het is, en verbeteren wat in de zaal opvalt. De bugs van
1.65 en 1.66 kwamen allemaal zo boven.

### 2.4 De volgende stap uit het coachplan

`AI-COACH-PLAN.md` §12: na Health Connect komt Google Play, dan de coach zonder eigen
sleutel (tussenstation, vragenpakketten). Dat stelt FitLog open voor anderen, en vraagt
beslissingen die alleen de maker kan nemen: een ontwikkelaarsaccount bij Google Play, een
inschrijving als zelfstandige en btw, een betaalaccount bij Google. Niet beginnen voor die
keuze gemaakt is. Meertaligheid (§4) hoort bij dezelfde beslissing.

---

## 3. Bekeken en niet gekozen

Op 28 oktober 2026 rondgekeken bij Hevy, Strong, Fitbod, JEFIT, Boostcamp, Alpha
Progression, Liftosaur en apps die met je stem loggen. Wat FitLog al heeft: een oefening
vervangen in een workout, schijven en warming-up, records en 1RM, spierkaart en herstel,
deloads, een schema dat zich aanpast, je workout live bovenaan je gsm, Health Connect, de
vorige keer tijdens je set. Wat de anderen hebben en FitLog niet, en waarom het (voorlopig)
niet past:

| Functie | Bij wie | Waarom niet |
|---|---|---|
| Maand- en jaaroverzicht om te delen | Hevy | Een deelbare samenvatting is niet waar een privé logboek voor dient. Een maandoverzicht zonder delen staat wel in `AI-COACH-PLAN.md` §3.5, als het ooit nodig is. |
| Bibliotheek met bekende programma's | Boostcamp | De coach maakt schema's op maat; een bibliotheek is een ander soort app. Namen van programma's zijn soms van iemand. |
| Gymprofielen (materiaal per plek) | Fitbod | Kan, maar FitLog kent al materiaal per oefening en "waar je traint" in je profiel. Pas als het in de zaal echt mist. |
| Loggen met je stem | Bolo, RepTalk, Liftly | Spraak kan op de gsm zelf, maar ontleden in het Nederlands met namen van oefeningen is lastig, en twee tikken per set is al snel. |
| App op je horloge | Hevy, Fitbod, JEFIT (Wear OS) | Veruit het meeste werk; de lopende workout bovenaan je gsm vangt een deel op. |
| Sociale feed, Strava | Hevy | Vraagt een account en een server. FitLog schrijft trainingen al naar Health Connect. |

---

## 4. Meertaligheid: hoe moeilijk, en wat Google ervoor heeft

Onderzocht op 28 oktober 2026.

### 4.1 Hoe het er nu voor staat

- **Alle tekst staat rechtstreeks in de code, in het Nederlands.** 248 Dart-bestanden,
  ruwweg 2.700 regels met een zin tussen aanhalingstekens en 1.100 `Text(`-widgets. Er is
  geen `lib/l10n` en geen `.arb`-bestand. `flutter_localizations` en `intl` zitten er wel
  al in, en de app staat vast op `Locale('nl')` (`lib/app.dart`, `lib/main.dart`).
- **Zinnen worden in code gebouwd**: `'$done van $n gedaan'`, `Formatters.amount(n,
  'week', 'weken')`, `relativeDay` met "Vandaag" en "Gisteren", hoofdletters met de hand.
  Dat moet naar berichten met plaatsvervangers en meervouden (ICU), anders klopt de
  zinsbouw in een andere taal niet.
- **De oefeningencatalogus** (876 oefeningen) heeft al Engelse namen en uitleg. De
  spiergroepen en het materiaal zijn Nederlandse sleutels (`quadriceps`, `borst`,
  `lichaamsgewicht`) die rechtstreeks getoond worden: die blijven als sleutel en krijgen
  een naam per taal.
- **De coach**: de vaste prompts, de beschrijvingen van de tools en de JSON die hij krijgt
  (`datum`, `nacht`, `check_voor_training`) zijn Nederlands. Het model kan die lezen en in
  een andere taal antwoorden; wat moet veranderen is de opdracht in welke taal hij
  antwoordt, ook voor het ochtendrapport en het weekoverzicht.
- **Native Android-code**: een paar zinnen in Kotlin (de melding van de lopende workout,
  de mapkiezer). Die gaan naar `strings.xml`.
- **Tests**: 1.359 plekken zoeken een Nederlandse tekst. Ze blijven werken zolang de tests
  in het Nederlands draaien (`helpers.dart` zet `nl` al vast).
- **Documenten**: de handleiding, de privacyverklaring en de downloadpagina zijn
  Nederlands. De privacyverklaring per taal moet juridisch even juist zijn.

### 4.2 Wat Google ervoor heeft

- **Gratis machinevertaling van je Play-pagina** (Play Console → Gebruikers laten groeien
  → Vertalingen → Winkelvermeldingen en producten → Bestelling maken → Gratis
  machinevertaling). Volgens de help-pagina naar 10 talen, waaronder Frans, Duits,
  Italiaans en Spaans; de marketingpagina noemt er 29. Niet door mensen nagekeken: zelf
  nalezen voor je ze toepast.
- **App-teksten vertalen met Gemini in Play Console**, gratis: nieuwe app bundles worden
  automatisch vertaald, je kan elke vertaling bekijken in een ingebouwde emulator,
  aanpassen of uitsluiten, en je aanpassingen blijven bij volgende versies. **Maar het
  vertaalt `strings.xml`.** Een Flutter-app zet zijn teksten niet in `strings.xml` maar in
  Dart (via `.arb`-bestanden), dus voor de schermen van FitLog werkt dit niet; alleen voor
  de paar native zinnen (§4.1).
- **Professionele vertaling** via Play Console, betaald.
- **Android 13 en later** laat gebruikers per app een taal kiezen. In Flutter vraagt dat een
  `localeConfig` in het manifest en een lijst van de talen; nog na te gaan hoe dat samen
  gaat met een taalkeuze in FitLog zelf.
- **Voor de vertaling van de `.arb`-bestanden** zelf heeft Google geen Flutter-dienst. Dat
  kan met Gemini of Claude, daarna nagelezen door iemand die de taal kent; termen uit de
  krachtsport ("deload", "RPE", "set") vragen een vaste woordenlijst.

### 4.3 Hoeveel werk

| Stap | Wat | Omvang |
|---|---|---|
| 1 | `gen-l10n` aanzetten, `l10n.yaml`, een `app_nl.arb`, taalkeuze in Instellingen en per-app-taal van Android | klein |
| 2 | Alle teksten uit de code naar `app_nl.arb`, per feature, met ICU-meervouden in plaats van zinnen in code | groot: het meeste werk, ongeveer 2.000 teksten, best in 10 à 20 stukken met telkens de tests groen |
| 3 | Spiergroepen en materiaal een naam per taal geven | klein |
| 4 | De coach laten antwoorden in de taal van de app (chat, ochtendrapport, weekoverzicht) | klein tot middel |
| 5 | Engels: `app_en.arb` laten vertalen en nalezen; schermen nakijken op 360dp met grote letters (Engels en zeker Duits zijn langer) | middel |
| 6 | Handleiding, privacyverklaring en downloadpagina in het Engels; Play-pagina via de gratis machinevertaling, nagelezen | middel |
| 7 | Elke volgende taal | per taal vooral vertalen en nakijken |

Stap 2 is het echte werk en raakt bijna elk bestand. Daarna kost elke nieuwe taal weinig
code, maar wel nalezen.

### 4.4 Advies

- Niet nu: zolang FitLog voor Nederlandstaligen is, levert het niets op en kost het veel.
- Wel samen met de beslissing om FitLog op Google Play voor anderen open te stellen
  (§2.4): dan eerst Engels, en de Play-pagina met de gratis machinevertaling.
- Als het ooit gebeurt: stap 1 en 2 eerst, zonder nieuwe taal. Dan staat alles klaar, en
  kan een taal erbij zonder dat de schermen opnieuw open moeten.

### 4.5 Bronnen

- [Play Console: Translate and localize your app](https://support.google.com/googleplay/android-developer/answer/9844778?hl=en)
- [Play Console: translation services](https://play.google.com/console/about/translationservices/)
- [Flutter internationalization (gen-l10n), samengevat](https://theflutterk.it.com/blog/flutter-localization-i18n-complete-guide-2026)
