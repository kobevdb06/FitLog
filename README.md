# FitLog

Een krachttraining-logger voor Android en iOS. Routines maken, tijdens de set
loggen, voortgang zien.

**Alles blijft op het toestel.** Geen account, geen server, geen sync, geen
analytics, geen crash reporting, geen advertenties. De Android-release heeft
bewust geen `INTERNET`-permissie in het manifest, dus de app kán niet eens iets
versturen. De enige keer dat er netwerk aan te pas komt, is tijdens het bouwen:
pakketten ophalen en de oefeningencatalogus genereren.

- **Bundle id:** `be.fitlog.app`
- **UI-taal:** Nederlands. Code, identifiers, commits en commentaar: Engels.
- **Minimum:** Android 6.0 (API 23), iOS 15.

---

## Draaien

```bash
flutter pub get
dart run build_runner build
flutter run
```

Codegeneratie is nodig: drift en riverpod schrijven allebei part-bestanden.
Beide zijn gecommit, dus een verse checkout draait ook zonder `build_runner`.

Testen en analyseren:

```bash
flutter analyze
```

```bash
flutter test
```

Release-APK:

```bash
flutter build apk --release
```

De oefeningencatalogus opnieuw genereren (het enige script dat het internet
raakt, en het draait nooit in de app):

```bash
dart run tool/build_exercise_seed.dart
```

## Toolchain

De machine waarop dit gebouwd is had geen Flutter. Wat er geïnstalleerd is:

| Onderdeel | Versie | Hoe |
|---|---|---|
| Flutter | 3.47.2 stable | `git clone -b stable https://github.com/flutter/flutter.git C:\flutter`, `C:\flutter\bin` in PATH |
| Dart | 3.13.2 | meegeleverd met Flutter |
| JDK | OpenJDK 21 (JBR van Android Studio) | `flutter config --jdk-dir="C:\Program Files\Android\Android Studio1\jbr"` |
| Android SDK | platform 36.1 en 37, build-tools 37.0.0 | bestond al, aangevuld met `platforms;android-37` |
| Android cmdline-tools | 16111833 | ontbrak; los gedownload en in `Sdk/cmdline-tools/latest` gezet |
| Android NDK | 28.2.13676358 | `android sdk install "ndk;28.2.13676358"` |

Xcode en macOS zijn er niet, dus de iOS-build is **niet** geverifieerd. De
iOS-configuratie staat er wel volledig; zie `NOT_VERIFIED.md`.

## Architectuur

```
lib/
  main.dart, app.dart          MaterialApp.router, thema, locale, auto-lock
  core/
    app/                       AppController: wat mag het scherm tonen
    db/                        drift-schema, DAO's, migraties, seeding
    calc/                      pure rekenlogica, geen Flutter-import
    security/                  sleutelbeheer, Argon2id, herstelzin, biometrie
    theme/ formatting/ widgets/ util/ providers/
  features/<feature>/
    data/ domain/ presentation/
  routing/                     go_router, routes, tab-shell
```

Feature-first met een gedeelde core. Alles wat te testen valt zonder scherm
staat in `core/calc` en `core/security` als pure Dart: 1RM, volume,
PR-detectie, schijvenberekening, warming-up, streak, eenheden, sleutelwrapping,
herstelzin en de invoerlogica van het keypad.

### Waarom deze keuzes

**drift boven sqflite.** Type-veilige queries, en vooral: reactieve streams.
Het actieve-workout-scherm schrijft elke wijziging meteen weg en tekent zichzelf
opnieuw vanuit de database. Er is nergens een "opslaan"-knop en nergens een
tweede bron van waarheid, dus een crash of een gedwongen afsluiten kost niets.

**Eén lopende sessie, herkend aan `ended_at IS NULL`.** Geen aparte
"actieve sessie"-state die kan ontsporen. Bij de volgende start vindt de app de
sessie gewoon terug.

**De rusttimer is een eindtijdstip, geen `Timer`.** Een `Timer` is waardeloos
zodra de app naar de achtergrond gaat. Er wordt een tijdstempel bewaard en een
lokale melding gepland; het scherm rekent de resterende tijd bij elke frame
opnieuw uit de klok. Terugkomen uit de achtergrond vraagt daardoor geen enkele
correctie.

**Alles metrisch in de database.** Kilogram, centimeter, meter, seconde. De hele
omrekening naar lb of inch zit in `core/formatting/formatters.dart`. Een
gebruiker die van eenheid wisselt, verandert niets aan zijn data.

**Records worden herbouwd, niet bijgehouden.** Bij het afvinken van een set gaat
er een incrementele check overheen. Maar zodra een oude sessie bewerkt of
verwijderd wordt, wordt de hele geschiedenis opnieuw afgespeeld. Exact in plaats
van bijna goed, en snel genoeg.

**Een eigen numeriek keypad.** Dit is de grootste kwaliteitswinst in de app. Een
volledige workout van vijf oefeningen maal vier sets is te loggen zonder het
systeemtoetsenbord ook maar één keer te zien: grote toetsen, plus- en
min-stappen in de gewichten die je echt oplegt (±1,25 / ±2,5 / ±5 kg), en een
"volgende"-toets die van gewicht naar reps naar de volgende set springt.

**Dark mode als standaard.** Eén accentkleur, groen voor voltooid, amber voor
een record. Cijfers staan in tabular figures, zodat kolommen niet dansen terwijl
je typt. Raakvlakken zijn minstens 48 dp, de set-checkbox 56 dp.

## Het sleutelmodel, in gewone taal

Er is geen server, dus "inloggen" bestaat niet. Wat er wel is: het ontgrendelen
van een database die op je eigen toestel versleuteld staat.

1. Bij de eerste start maakt de app een willekeurige sleutel van 32 bytes: de
   **datasleutel**. Die sleutel is het wachtwoord van de SQLCipher-database.
   Zonder hem is het bestand een blok ruis, ook voor iemand die je telefoon
   uitleest.

2. De datasleutel wordt **nooit onversleuteld weggeschreven**. Wat er op schijf
   staat, zijn ingepakte kopieën:

   - **Onder je pincode.** Uit je zes cijfers wordt met Argon2id (64 MB
     geheugen, 3 rondes, 2 threads) een sleutel afgeleid, en daarmee wordt de
     datasleutel met AES-GCM ingepakt. Argon2id kost expres geheugen en tijd,
     zodat iemand die het bestand steelt niet in een dag door alle miljoen
     pincodes kan lopen. Het pakket komt in de Android Keystore of de iOS
     Keychain terecht.
   - **Onder je herstelzin.** Dezelfde constructie, met de twaalf woorden als
     geheim.
   - **Rechtstreeks**, als je geen pincode wilt of biometrie aanzet. De sleutel
     staat dan nog altijd achter de Keystore of Keychain van je toestel, maar er
     zit geen extra geheim voor.

3. **Je pincode wijzigen pakt alleen de sleutel opnieuw in.** De database wordt
   nooit opnieuw versleuteld: dat zou minuten duren en kan halverwege
   misgaan.

4. **De twaalf woorden zijn de enige weg terug.** Ze staan alleen bij jou. Er is
   geen server die ze kan opzoeken en geen achterdeur. Ze zijn ook de sleutel
   van je back-upbestand. Schrijf ze op papier.

5. **Een verkeerde pincode wist niets.** Vanaf de vierde poging komt er een
   wachttijd bij: 2, 4, 8, 16 en dan maximaal 30 seconden. Je trainingsdata
   kwijtraken door een nieuwsgierig kind is een erger resultaat dan een trage
   brute force op een sleutel die al achter Argon2id zit.

6. **De app weigert onversleuteld te draaien.** Bij het openen controleert ze
   `PRAGMA cipher_version`. Is die leeg, dan draait er gewone SQLite in plaats
   van SQLCipher en start de app niet, met een uitleg in plaats van stilzwijgend
   je trainingen in het open veld te zetten.

Auto-vergrendelen is instelbaar op meteen, 1, 5 of 15 minuten, of nooit. De
teller loopt vanaf het moment dat de app naar de achtergrond gaat. **Tijdens een
lopende workout vergrendelt de app nooit.**

## Back-up

Twee knoppen in Instellingen:

- **Een versleuteld `.fitlog`-bestand.** De databasesnapshot (via `VACUUM INTO`,
  dus consistent), alle foto's en de datasleutel gaan in één zip, en die zip
  wordt met AES-GCM versleuteld onder een uit je herstelzin afgeleide sleutel.
  Het bestand gaat naar het deelmenu van het systeem. Zonder de twaalf woorden
  is het niet te openen.
- **Een CSV-export** van alle workouts en sets, gewoon leesbaar, voor wie zijn
  data ergens anders wil bekijken.

Terugzetten vraagt het bestand, de herstelzin, en dan twee bevestigingen
waarvan de tweede het woord `HERSTEL` laat typen.

## Oefeningen

De catalogus komt uit [free-exercise-db](https://github.com/yuhonas/free-exercise-db),
vrijgegeven onder de Unlicense (publiek domein). 876 oefeningen worden bij de
eerste start in één transactie geïmporteerd.

`tool/build_exercise_seed.dart` haalt de bron op, houdt alleen de velden over
die FitLog opslaat, en vertaalt de spiergroepen en materiaalnamen naar het
Nederlands. De oefeningsnamen blijven Engels: "Barbell Bench Press" is in elke
Nederlandse zaal gangbaarder dan een vertaling. De afbeeldingen uit de bron zijn
bewust niet meegenomen; ze zouden de bundel tientallen megabytes zwaarder maken
voor weinig winst. In plaats daarvan krijgt elke spiergroep een eigen kleur.

Bron en licentie staan ook in de app, op het scherm "Over".

## Tests

```
test/calc/          1RM, volume, PR-detectie, schijven, warming-up, streak,
                    eenheden, keypad-invoer, rusttimer
test/security/      sleutelwrapping, herstelzin, sleutelbeheer, lockout
test/db/            SQLCipher werkt echt, verkeerde sleutel faalt, schema,
                    indexen, seeding
test/widget/        keypad, setrij afvinken, rusttimer na afvinken, onboarding
test/integration/   routine -> workout -> geschiedenis -> records
```

182 tests, allemaal groen.

## Verder lezen

- `docs/DATA_MODEL.md` - tabellen, relaties, indexen, conventies
- `docs/DECISIONS.md` - elke afwijking van de opdracht, met reden
- `NOT_VERIFIED.md` - wat er niet aangetoond is en waarom
