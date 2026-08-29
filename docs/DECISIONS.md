# Afwijkingen van de opdracht, en waarom

Elke plek waar deze build afwijkt van de bouwopdracht, met de reden. Alles wat
hier niet staat, is gebouwd zoals gevraagd.

## Stack

### 1. `sqlcipher_flutter_libs` en `sqlite3_flutter_libs` zijn vervangen

De opdracht vraagt om `sqlcipher_flutter_libs`. Dat pakket is inmiddels
end-of-life: de laatste versie op pub.dev heet letterlijk `0.7.0+eol` met de
beschrijving *"Not used anymore, update to version 3.x of package:sqlite3
instead"*. Hetzelfde geldt voor `sqlite3_flutter_libs` (`0.6.0+eol`).

Sinds `package:sqlite3` 3.x bundelt dat pakket zijn eigen SQLite via Dart build
hooks, en kan je de SQLCipher-build kiezen. Dat staat in `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlcipher
```

Dit is de door de auteur van drift én sqlite3 aangewezen opvolger, dus geen
afwijking van de bedoeling, alleen van de pakketnaam. `PRAGMA cipher_version`
geeft `4.18.0 community`; `test/db/encryption_test.dart` controleert dat, en de
app weigert te starten als het leeg is.

### 2. `build.yaml` is nodig om drift en riverpod samen te laten werken

drift en riverpod leveren allebei een `SharedPartBuilder`. Die draaien in
dezelfde fase en zien elkaars output niet. Omdat een aantal providers
drift-rijtypes in hun signatuur hebben (`Stream<AppSettingsRow> settings(...)`),
loste `riverpod_generator` die types op als `InvalidType` en faalde met
`InvalidTypeException`.

De oplossing die drift daarvoor documenteert is de `not_shared` builder, die een
echt `.drift.dart` part-bestand schrijft. Samen met een expliciete
`runs_before` staat die output klaar voor `riverpod_generator` draait. Vandaar
`build.yaml`, en vandaar dat de drift-output `*.drift.dart` heet in plaats van
`*.g.dart`.

### 3. `riverpod_lint` en `custom_lint` zitten er niet in

Ze zijn niet oplosbaar naast riverpod 3 en `uuid` 4: `riverpod_lint` trekt een
`analyzer 6`-keten mee die `_macros` uit de SDK verwacht, en die bestaat niet
meer. Ze stonden ook niet in de gevraagde pakkettentabel. `flutter analyze`
draait schoon zonder.

### 4. Actie-only controllers zijn gewone klassen achter een `Provider`

`riverpod_generator` 4 kan geen `Notifier` met `void build()` genereren
(`InvalidTypeException`). `WorkoutController`, `RoutineActions`,
`HistoryActions`, `ExerciseEditor` en `PhotoActions` houden geen state, dus ze
zijn gewone klassen die via een `@riverpod`-functie geleverd worden. Providers
die wél state hebben (`RestTimer`, `ExerciseFilterController`, `AppController`)
zijn gewone Notifiers met codegen.

### 5. Riverpod 3 start providers pas als er naar geluisterd wordt

`WorkoutController.completeSet` las de lopende workout eerst via
`activeWorkoutProvider`. In Riverpod 3 blijft een `StreamProvider` hangen tot er
een luisteraar is, waardoor die read nooit terugkwam als het scherm de provider
toevallig niet volgde. De controller leest nu rechtstreeks uit de DAO. Dat is
ook los van riverpod het juiste niveau: een schrijfactie hoort niet van de
UI-laag af te hangen.

## Platform

### 6. iOS deployment target is 15.0, niet 14.0

Flutter 3.47 ondersteunt iOS 14 niet meer; `flutter create` zet zelf 15.0. Naar
14.0 verlagen zou niet compileren.

### 7. Er is geen Podfile en geen geverifieerde iOS-build

De hele build is op Windows gemaakt. `flutter build ios --no-codesign` vereist
macOS en Xcode; `ios/Podfile` wordt pas door `pod install` op macOS aangemaakt.
De iOS-map is verder wel volledig geconfigureerd (bundle id `be.fitlog.app`,
Nederlandse `NSFaceIDUsageDescription`, `NSCameraUsageDescription`,
`NSPhotoLibraryUsageDescription` en `NSPhotoLibraryAddUsageDescription`), maar
**of de iOS-build slaagt is niet aangetoond**. Zie ook `NOT_VERIFIED.md`.

### 8. De `INTERNET`-permissie staat wel in de debug- en profile-manifesten

`android/app/src/main/AndroidManifest.xml` heeft geen `INTERNET`-permissie: dat
is het manifest dat in de release-APK terechtkomt. Flutter genereert daarnaast
`src/debug/AndroidManifest.xml` en `src/profile/AndroidManifest.xml` met die
permissie, omdat de hot reload-verbinding van de tooling er anders niet bij kan.
Die manifesten worden niet in een release samengevoegd. Ze weghalen zou debuggen
onmogelijk maken zonder de release-app veiliger te maken.

### 9. Toolchain die geïnstalleerd moest worden

De map was leeg en er stond geen Flutter op de machine. Geïnstalleerd:

- Flutter 3.47.2 stable, via `git clone -b stable` naar `C:\flutter`, met
  `C:\flutter\bin` in de gebruikers-PATH.
- Android `cmdline-tools` (build 16111833), die ontbraken in de bestaande SDK.
- NDK `28.2.13676358` en `platforms;android-37`; die eerste eist de Flutter
  Gradle-plugin, die tweede eist `flutter_secure_storage` 11.
- Als JDK is de JBR van de bestaande Android Studio gebruikt (OpenJDK 21),
  vastgelegd met `flutter config --jdk-dir`.

## Beveiliging

### 10. `flutter_secure_storage` heeft `encryptedSharedPreferences` niet meer

De opdracht vraagt `AndroidOptions(encryptedSharedPreferences: true)`. Vanaf
versie 10 gebruikt het pakket altijd Keystore-gebaseerde versleutelde
preferences; die vlag bestaat niet meer. Op iOS is de gevraagde accessibility
`first_unlock_this_device` wel expliciet gezet.

### 11. Er is altijd een herstelzin, ook als de pincode wordt overgeslagen

De opdracht toont de twaalf woorden na het instellen van de pincode. Maar §39
maakt de herstelzin ook de sleutel van de back-up, en iemand die de pincode
overslaat moet nog steeds een back-up kunnen maken en terugzetten. De herstelzin
wordt daarom in beide paden gegenereerd, getoond en geverifieerd.

### 12. Een kopie van de herstelzin staat versleuteld onder de DEK

Scherm 38 vraagt "herstelzin opnieuw tonen". Met alleen de gewrapte DEK is dat
onmogelijk: uit `Argon2id(zin) → DEK` valt de zin niet terug te rekenen. Er
staat daarom een tweede kopie in de sleutelopslag: de zin zelf, versleuteld met
AES-GCM onder de DEK. Die is dus alleen leesbaar wanneer de database al open is,
en dat is precies wanneer het scherm hem mag tonen. Het maakt de zin niet
zwakker: wie de DEK heeft, heeft de data al.

### 13. Na het terugzetten van een back-up staat er geen pincode meer

De herstelde database is versleuteld met de DEK uit het archief, niet met de DEK
van dit toestel. Alle gewrapte kopieën hier zijn dan waardeloos en worden
gewist. De nieuwe DEK wordt onder de herstelzin gewrapt en rechtstreeks in de
Keystore gezet; het herstelscherm zegt erbij dat je een nieuwe pincode moet
instellen. Het alternatief - tijdens het herstellen ook nog om de huidige
pincode vragen - voegt een stap toe aan een flow die al twee bevestigingen
heeft.

## Data

### 14. De gezaaide oefeningen hebben een UUID v5, geen v4

`tool/build_exercise_seed.dart` leidt het id deterministisch af uit de slug van
free-exercise-db. Zo levert een herbouw van de seed dezelfde id's op en blijven
gelogde workouts naar dezelfde oefening wijzen. Zelfgemaakte oefeningen krijgen
gewoon een v4.

### 15. `assets/data/muscles/` met SVG's bestaat niet

De mappenstructuur in §4 noemt SVG's per spiergroep, maar §8 zegt "toon een
gekleurd icoon per spiergroep" en de pakkettentabel bevat geen SVG-renderer
(`flutter_svg` staat er niet in). De spiergroepen worden daarom weergegeven met
een kleurtoken per groep (`AppColors.muscleColors`), een gekleurde
`MuscleAvatar` in lijsten, en een met `CustomPainter` getekende voor- en
achterkant-silhouet op de workout-samenvatting
(`lib/core/widgets/muscle_map.dart`).

### 16. Geluiden zijn haptiek plus systeemgeluiden

§9 vraagt een klik bij het afvinken, een andere toon bij een PR en een aflopende
toon aan het einde van de rusttimer. In de toegestane pakkettenlijst zit geen
audiospeler, en er is bewust geen extra pakket toegevoegd. De feedback is
opgebouwd uit wat het platform zelf biedt: `HapticFeedback.mediumImpact` plus
`SystemSound.click` bij een set, een drievoudige `heavyImpact` bij een PR, en de
geplande lokale melding (met het systeemalarmgeluid) aan het einde van de rust.

### 17. Feedback blokkeert de flow nooit

Haptiek en geluid worden niet meer afgewacht voordat de rusttimer start. Op een
toestel zonder trilmotor of zonder die platform channel bleef de timer anders
uit. `FeedbackService` vangt bovendien zijn eigen fouten op.

### 18. Records worden opnieuw opgebouwd bij bewerken of verwijderen

Als een gelogde set achteraf verandert of een workout verwijderd wordt, kan een
bestaand record ongeldig worden en is er geen goedkope manier om te weten welk.
`RecordsDao.rebuildAllRecords()` speelt de hele geschiedenis opnieuw af. Bij een
paar duizend sets is dat een kwestie van milliseconden, en het resultaat is
exact in plaats van benaderend.

### 19. De warming-up rondt bij gelijkspel naar beneden af

87,5 kg × 90 % is 78,75, precies tussen 77,5 en 80. De calculator kiest dan het
lagere gewicht. Willekeurig, maar deterministisch en conservatief voor een
opwarmset.

## UI

### 20. De geschiedenis zit onder het tabblad Voortgang

De opdracht schrijft vier tabbladen voor (Start, Trainen, Voortgang, Profiel) en
beschrijft daarnaast een geschiedenisgedeelte. Kalender, sessielijst en
sessiedetail zitten onder Voortgang, met een snelkoppeling vanaf het overzicht,
zoals §10F ("snelkoppelingen naar de rest") suggereert.

### 21. Het eigen keypad wordt overal gebruikt, niet alleen in de sessie

§9 vraagt het eigen keypad voor het loggen. Omdat het systeemtoetsenbord voor
een getal nergens beter is, opent hetzelfde keypad ook als bottom sheet bij
routinedoelen, lichaamsmetingen, het stanggewicht en de rusttijd
(`lib/core/widgets/keypad_sheet.dart`). Vrije tekst (namen, notities) gebruikt
uiteraard wel gewoon een tekstveld.

### 22. `exercise_folders` is niet gebouwd

De opdracht markeert die tabel zelf als *niet in MVP*. Mappen bestaan alleen
voor routines.

## Proces

### 23. De git-historiek is per fase; de tussenliggende commits zijn geen
build-punten

`git init` kon pas na `flutter create`, en dat kon pas nadat Flutter zelf
geïnstalleerd was. Er is één commit per fase, in volgorde.

Voor fase 0 tot en met 2 (project, database, beveiliging) was de boom op elk van
die commits ook echt groen: `flutter analyze` schoon, de bijhorende tests
draaiend.

Voor fase 3 tot en met 10 gaat dat niet op. `lib/routing/router.dart` verwijst
naar alle schermen tegelijk, en de schermen verwijzen terug naar de router. Elke
knip daartussen levert een boom op die niet compileert. Die commits zijn dus wel
per fase gegroepeerd, maar de router, `app.dart` en `main.dart` zitten in de
laatste; de boom compileert vanaf dat punt. Elke fase is tijdens het bouwen wel
apart afgerond en gecontroleerd - alleen niet als los build-baar commit
vastgelegd. Wie de historiek gebruikt om te lezen wat er per fase bijkwam, heeft
er niets aan verloren; wie hem gebruikt om te bisecten, wel.


---

# Ronde 2

## 24. libwebp wordt als build-tool opgehaald in plaats van terug te vallen op GIF

De opdracht zegt: gebruik `img2webp` als het beschikbaar is, val anders terug op
GIF. Op deze machine stond libwebp er niet, en `package:image` kan wel WebP
lezen maar niet schrijven.

Terugvallen op GIF haalt het budget niet. Een GIF is palletgebaseerd met
maximaal 256 kleuren, wat op foto's van mensen in een zaal zichtbaar slecht
oogt, en de bestanden zijn een veelvoud groter: een ruwe schatting op basis van
de eerste tientallen oefeningen kwam op 60 MB en meer voor de animaties alleen,
tegen een budget van 35 MB. De opdracht noemt "WebP in plaats van GIF" zelf als
de eerste knop om onder dat budget te blijven.

De officiële libwebp-binaries van Google (1.6.0) worden daarom in
`.build_cache/tools/` gezet en van daaruit gebruikt. Dat is een
build-tijd-afhankelijkheid in dezelfde categorie als de Flutter SDK of de NDK,
en de tool zoekt eerst op PATH, zodat `brew install webp` of
`apt install webp` net zo goed werkt. Zonder libwebp doet de tool nog steeds
wat de opdracht voorschrijft: 2-frame GIF's, met een waarschuwing.

**Uiteindelijk resultaat: WebP, 873 van de 876 oefeningen geanimeerd, 15,0 MB
totaal.** Geen van de andere knoppen (280 px, 64 kleuren, alleen de top 300)
was nodig.

## 25. De ladderpercentages voor twee opwarmsets zijn een expliciete uitzondering

De opdracht beschrijft de percentages als "lineair verdeeld tussen 40% en 90%",
maar geeft voor twee sets expliciet 50% en 80%. Dat is geen lineaire verdeling
tussen dezelfde uiteinden. Voor acht sets zegt de opdracht juist wel "dezelfde
uiteinden".

`buildPrRamp` volgt daarom de lineaire regel van 40% tot 90% voor drie sets en
meer, en gebruikt 50% tot 80% als er maar twee zijn. Dat is ook inhoudelijk het
juiste gedrag: met maar twee opwarmers is 40% naar 90% een sprong waar je niets
aan hebt.

## 26. De rusttijden volgen de reps, niet het percentage

De opdracht zegt "rusttijden lopen op van 90 s naar 240 s, lineair verdeeld", en
geeft voor vier sets de tabel 90 / 120 / 180 / 240. Lineair verdelen over vier
sets geeft 90 / 140 / 190 / 240, dus de regel en de tabel spreken elkaar tegen.

`restForReps` leidt de rust af uit de reps: 5 of 4 reps → 90 s, 3 → 120 s,
2 → 180 s, 1 → 240 s. Dat reproduceert de tabel van de opdracht exact, loopt
netjes op van 90 naar 240 voor elke ladderlengte, en sluit aan bij hoe rust in
de praktijk gekozen wordt: naar de zwaarte van de set, niet naar een lineaire
interpolatie.

## 27. De ladder wordt niet apart opgeslagen

De opwarmrungen zijn gewone `workout_sets` van het type `warmup` en de poging is
de enige werkset. Daardoor gelden alle regels uit feature A automatisch: de
opwarmers tellen niet mee voor volume, niet voor records en niet voor de kolom
VORIGE. De rusttijden worden bij het afvinken opnieuw uit de reps afgeleid met
dezelfde functie die de ladder gebruikte, zodat er geen rust-per-set-kolom nodig
is.

Eén afwijking van het normale gedrag: opwarmsets binnen een PR-poging starten
wél een rusttimer. Een gewone warming-up doet dat niet, maar een ladder zonder
rust tussen 90% en de poging is nutteloos.

## 28. Schemaversies: de bugfix nam versie 2, dus PR-pogingen staan op 4

De opdracht schrijft voor feature B `schemaVersion = 2` voor. Die versie was op
dat moment al vergeven: bug 3 had een migratie nodig om de ontbrekende
`ON DELETE SET NULL` op `personal_records.workout_set_id` toe te voegen, en
feature A had er een nodig voor `default_warmup_sets`.

De volgorde uit de opdracht is leidend, dus: v2 voor de bugfix, v3 voor feature
A, v4 voor feature B. Een al vrijgegeven migratiestap achteraf uitbreiden zou
een database die v2 al gedraaid heeft stilzwijgend overslaan.

## 29. Nummering: drop- en failure-sets houden hun plaats in de reeks

De opdracht zegt dat werksets 1, 2, 3 genummerd worden met de warming-ups
overgeslagen, en dat dropsets `D` tonen en failure-sets `F`. Wat er niet staat,
is of een `D` een nummer opgebruikt.

`labelSets` laat ze hun plaats houden: `[normaal, normaal, drop, normaal]` wordt
`1, 2, D, 4`. Ze zijn werksets, ze tellen mee voor volume en records, dus ze
horen in de reeks; alleen de weergave is een letter. Alleen warming-ups worden
echt overgeslagen.

## 30. Een niet-leesbaar beeldbestand wordt omgezet, niet doorgeslikt

`package:image` probeert formaten af en laat op onzin-invoer een `RangeError`
ontsnappen uit het PSD-pad, nog voor `decodeImage` null kan teruggeven. Dat is
geen fout waar een aanroeper iets mee kan.

`PhotoStore.processBytes` vangt hem en gooit één getypeerde
`UnreadableImageException`. Dat is geen wegslikken: de import faalt nog steeds,
alleen met een fout die het scherm kan uitleggen. De originele fout blijft als
`cause` behouden.
