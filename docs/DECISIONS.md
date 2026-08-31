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

## 31. Het app-icoon wordt getekend, niet als bitmap bijgehouden

Het icoon op het beginscherm was tot nu toe het standaard Flutter-logo uit
`flutter create`: het handelsmerk van een ander project, en niet dat van deze
app. In de app stond daarnaast een materiaal-halter in een gekleurd vierkant.
Twee verschillende tekens, geen van beide van FitLog.

Er is nu één `FitLogMarkPainter`. `FitLogLogo` tekent hem live, en
`tool/render_app_icon.dart` tekent hem in de platformbestanden. Een bitmap als
bron zou betekenen dat het logo in de app en het icoon op het beginscherm los
van elkaar bijgewerkt kunnen worden; nu komt het uit dezelfde meetkunde en
bewaakt `test/widget/branding_test.dart` dat de uitgerenderde bestanden er nog
mee overeenkomen.

Het merkteken is een F die uit één lint gevouwen is: platte vlakken, geen
omlijning, alles op 45 graden, één kleur in drie tinten. Een eerdere versie
zette gewichtsschijven op de armen; op 48 px werd dat een vlek en op 512 px las
het als `F!`.

Elke schuine rand loopt dezelfde kant op - zowel de afgesneden uiteinden van de
armen als de vouwen waar ze uit de stam komen. Toen de vouwen er haaks op
stonden, stak de vouw van de korte arm zes eenheden voorbij de onderrand
daarvan uit; met alle diagonalen evenwijdig past een vouw per definitie binnen
zijn arm, ongeacht hoe lang die arm is.

De L van FitLog erin verwerken is geprobeerd en losgelaten. Een voetje aan de
stam maakt er onvermijdelijk een E van: drie evenwijdige armen op één stam
lezen als een E, welke tint de onderste ook krijgt. Een monogram waarin de F in
de hoek van een grote L zit werkt wel als vorm, maar leest LF in plaats van FL,
en twee letters naast elkaar worden op 48 px te druk. Het icoon is de plek waar
één herkenbare vorm meer waard is dan een volledige naam.

De achtergrond is wit: de drie tinten van het merkteken dragen de kleur, dus
een gekleurde laag erachter zou ze doodslaan. Het adaptive-icoon schaalt de F
tot zijn hoeken binnen de 72dp-cirkel vallen die een ronde launcher overhoudt,
niet binnen de striktere 66dp-veilige zone. Die
laatste zou het icoon zichtbaar kleiner maken dan alle andere op het
beginscherm, terwijl alleen de lege hoeken van het omhullende vierkant
erbuiten vallen.

## 32. De illustratie hoort bij de oefening, niet bij de catalogus

`ExerciseThumb` krijgt het manifest aangereikt. Dat is juist voor de catalogus,
die honderden rijen lang wordt en er beter één keer bovenaan naar kijkt, maar
het betekende ook dat elk ander scherm het manifest door drie widgets heen moest
doorgeven om bij de afbeelding te komen. Geen van die schermen deed dat: de
routine-editor, het routinedetail, de afgewerkte workout, de recordlijst en het
dashboard toonden allemaal de terugvalbadge met de beginletters.

`ExerciseAvatar` leest het manifest zelf, zodat een aanroepplek alleen de
oefening nodig heeft. De catalogus blijft het manifest expliciet doorgeven.

## 33. Een eigen oefening animeert in Dart, niet als bestand

De gevraagde uitkomst is dat twee foto's van een eigen oefening net zo bewegen
als de illustraties uit de catalogus. Die catalogusbeelden zijn geanimeerde
WebP's, gebouwd door `tool/build_exercise_images.dart` met libwebp - een
programma dat op de buildmachine draait en niet op de telefoon.

Er wordt dus geen bestand gemaakt. De twee foto's blijven twee JPEG's en
`ExerciseAnimation` wisselt ze af op dezelfde 700 ms als de gebouwde
animaties, met dezelfde tik-om-te-pauzeren. Het alternatief was op het toestel
een GIF encoderen; dat kan met `package:image`, maar een GIF is beperkt tot 256
kleuren en dat is op een foto direct zichtbaar. Beide beelden blijven gebouwd
in een `IndexedStack`, zodat het wisselen een hertekening is en geen decode -
decoderen op de tel zou als een hapering te zien zijn.

## 34. De beelden van een oefening staan bij de voortgangsfoto's

Ze hadden een eigen map kunnen krijgen. Dan had ook de back-up een tweede map
moeten inpakken en uitpakken, en had de opstartcontrole die wezen opruimt een
tweede keer geschreven moeten worden. Beide zijn dingen die je één keer goed
doet en daarna vergeet bij te werken.

In dezelfde map reizen ze mee in de back-up zonder extra code. De prijs is dat
`PhotoLibrary.cleanup` nu twee tabellen moet bevragen voor het antwoord op de
vraag welk bestand nog ergens bij hoort; staat een van de twee er niet bij, dan
verwijdert de opruiming het bestand van de ander. Dat is precies wat
`test/photos/exercise_frames_test.dart` vastlegt.

Verdwijnt het bestand toch, dan wordt alleen de verwijzing leeggemaakt. De
oefening zelf blijft staan: er kunnen workouts aan hangen, en die zijn meer
waard dan een plaatje.

## 35. Een afgebroken bewerking laat een bestand achter, en dat mag

De gekozen foto wordt meteen gekopieerd en verkleind, nog voor er iets in de
database staat: wat het scherm toont is dan het bestand dat bewaard wordt, en
niet het tijdelijke bestand van de kiezer, dat het systeem op elk moment mag
weggooien.

Sluit de gebruiker het scherm daarna zonder op te slaan, dan ligt dat bestand er
zonder rij. Het opruimen ervan bij het verlaten van het scherm zou vragen dat
het scherm overleeft dat Android het proces tijdens het kiezen afsluit, en dat
is precies het geval dat je niet kunt afvangen. De opstartcontrole ruimt zulke
wezen al op; dit is er een van.

Andersom wordt een vervangen foto pas bij het opslaan verwijderd. Tot dat moment
wijst de rij er nog naar, en kan de gebruiker de bewerking nog laten varen.

## 36. De herstelschatting vergelijkt je met jezelf, niet met een tabel

Absolute kilo's zeggen niets over herstel. Een squatsessie is tien keer het
volume van een sessie zijwaartse heffingen zonder dat schouders tien keer
sneller herstellen, en wat voor de een een zware dag is, is voor de ander een
warming-up.

Daarom wordt de belasting van een sessie voor een spiergroep afgezet tegen de
mediaan van wat diezelfde spiergroep bij deze gebruiker de laatste acht weken
kreeg. Die verhouding, begrensd tussen 0,6 en 1,5, schaalt een basistijd per
spiergroep. Eén uitschieter mag de schatting oprekken, niet verdrievoudigen.

Zolang een spiergroep minder dan drie eerdere sessies heeft, is er niets om mee
te vergelijken en is de schatting de basistijd. Dat wordt getoond als
*voorlopig* in plaats van weggelaten: iets tonen met een voorbehoud is
bruikbaarder dan een leeg vak.

De basistijden zelf komen uit vuistregels en zijn geen fysiologische claim. Ze
staan als één tabel bovenin `lib/core/calc/recovery.dart`, zodat ze te vinden en
te veranderen zijn zonder de rest te lezen.

## 37. De gebruiker beoordeelt de zwaarte, niet de kwaliteit

Gevraagd was een manier om na de workout te zeggen hoe goed de training was.
Wat de schatting kan gebruiken is hoe **zwaar** hij was; dat zijn twee
verschillende dingen. Een technisch uitstekende sessie kan licht zijn, en een
sessie waarin alles tegenzat kan slopend zijn. Alleen het tweede zegt iets over
herstel.

De vraag luidt daarom "Hoe zwaar was het?", met vijf antwoorden van *Heel
licht* tot *Alles gegeven*, die de geschatte tijd met 0,75 tot 1,3
vermenigvuldigen. Nog een keer op hetzelfde antwoord tikken maakt de sessie
weer onbeoordeeld, en onbeoordeeld telt als neutraal - niet als licht.

Dit is bewust het enige subjectieve dat meeweegt: het is ook het enige aan een
sessie dat de app onmogelijk kan meten.

## 38. Lichaamsgewicht telt mee, want anders telt een dip voor niets

Bij een lichaamsgewichtoefening staat er geen gewicht in het logboek. Volume is
dan nul, en een sessie van veertig dips zou net zoveel herstel vragen als geen
sessie. Het laatst gelogde lichaamsgewicht vult dat gat; bij een geassisteerde
machine wordt het gelogde gewicht er juist afgetrokken, want dat is wat de
machine overneemt.

Heeft de gebruiker nooit een gewicht gelogd, dan valt een vast getal in. Dat is
minder juist dan meten, maar veel minder verkeerd dan nul.

Sets zonder reps - cardio, een plank op tijd - leveren geen bruikbaar getal en
worden overgeslagen in plaats van als nul geteld. Een spiergroep die niets
meetbaars kreeg, hoort geen korte hersteltijd te krijgen maar helemaal geen.

## 39. De schatting adviseert niets

Ze staat op het samenvattingsscherm en op het dashboard, en verder nergens. Er
wordt niet gewaarschuwd bij het starten van een routine en er wordt geen
trainingsdag voorgesteld. Slaap, eten, stress, leeftijd en ziekte wegen
zwaarder dan het volume dat de app ziet, en van geen daarvan weet ze iets.

Onder elke schatting staat wat ze wel en niet meeweegt. Dat is geen sierlijke
disclaimer maar de reden dat het getal er mag staan.

## 40. Het back-upmoment staat in de back-up zelf

`last_backup_at` wordt weggeschreven voordat de databasesnapshot gemaakt wordt,
niet erna. Daardoor draagt een archief zijn eigen moment: zet je het terug op
een nieuw toestel, dan klopt de herinnering meteen, zonder dat de herstelcode
er iets extra's voor hoeft te doen.

De prijs is dat een mislukte back-up de tijd al aangepast zou hebben. Daarom
wordt de vorige waarde teruggezet als er daarna iets misgaat, en gaat de fout
gewoon door naar de aanroeper. Een back-up die niet gelukt is mag de
herinnering niet het zwijgen opleggen.

De herinnering zwijgt op een lege installatie. Zonder gelogde workouts valt er
niets te verliezen, en een app die zeurt voordat je iets gedaan hebt, leer je
negeren.

## 41. Een onderbroken fotokeuze laat eerst een briefje achter

`retrieveLostData` geeft na een herstart het bestand terug dat Android kwijtraakte
toen het de app uit het geheugen gooide. Wat het niet teruggeeft, is waar dat
bestand heen moest: bij welke pose, of bij welke oefening en welk vakje.

Daarom wordt dat vóór het openen van de camera in `app_settings` gezet en in een
`finally` weer weggehaald - of de keuze nu lukt, geannuleerd wordt of gooit. Het
alternatief was de gebruiker bij de volgende start vragen waar de foto hoorde,
maar dat is een vraag over iets wat hij misschien dagen eerder deed.

Het ophalen gebeurt nadat de database open is, want het briefje staat erin. Twee
gevallen blijven onherstelbaar en zeggen dat ook: een bestand zonder briefje, en
een beeld voor een oefening die nog niet opgeslagen was. Dat laatste is geen
onmacht maar een feit - het half ingevulde formulier is met het proces
meegegaan, dus er is geen rij om het beeld aan te hangen.

`PickRecovery` krijgt de lezer van het verloren bestand als argument. Dat is wat
het geheel testbaar maakt zonder platformkanaal; de echte lezer controleert
eerst of hij op Android draait, want elders gooit `retrieveLostData`.

## 42. Een routine past in één QR-code, mits gecomprimeerd

Een QR-code houdt 2.331 bytes bij middelmatige foutcorrectie. Rauwe JSON van een
routine van twaalf oefeningen is ruim 2,8 kB en past dus niet. Diezelfde JSON
met sleutels van één letter, door deflate gehaald, komt uit rond de 700 bytes -
herhaalde sleutels en gedeelde woordstukken in namen comprimeren hard.

De inhoud gaat als base64 de code in, wat een derde kost aan omvang. Rauwe
bytes zouden compacter zijn, maar dan hangt het ervan af of de scanner de bytes
teruggeeft in plaats van een string, en dat is niets om in de zaal achter te
komen. Zekerheid weegt hier zwaarder dan dichtheid; blijkt de code in de
praktijk te dicht om te scannen, dan is base45 met alfanumerieke modus de
volgende stap.

De uitleg van een catalogusoefening gaat niet mee. Die staat al in de
catalogus van de ontvanger, en het is precies wat de code liet klappen: de
mediane oefening uit de dataset draagt zo'n 600 tekens uitleg, en acht daarvan
zijn in hun eentje groter dan een QR-code. Alleen bij een oefening die de
ontvanger niet kan opzoeken reist de uitleg mee, en dan afgekapt.

Past het dan nog niet, dan valt de tekst helemaal weg en gaat de code er zonder
doorheen. Wat overblijft is waar het om gaat: oefeningen, sets en rusttijden.
Een routine helemaal weigeren omdat er te veel over de uitvoering geschreven
is, zou de verkeerde kant op falen.

Gewichten gaan niet mee. De ontvanger tilt zijn eigen getallen, en de
VORIGE-kolom vult zich vanzelf zodra hij de oefening een keer gedaan heeft -
dezelfde redenering als bij *Opnieuw doen*.

Catalogusoefeningen reizen als id, met hun naam ernaast. Die naam is geen
verspilling: staat het id niet in de catalogus van de ontvanger, bijvoorbeeld
omdat zijn versie een oudere seed heeft, dan is de naam het enige waarop nog te
matchen valt, en anders de beschrijving waarmee de oefening alsnog aangemaakt
kan worden.

## 43. Een gescande code is invoer van buiten

Alles wat uit een QR komt, wordt gecontroleerd in plaats van geloofd: een
maximum aan oefeningen, sets en tekstlengte, getallen die begrensd worden,
een terugval voor elk veld dat het verkeerde type heeft, en één getypeerde fout
voor de rest. Een code van een andere versie wordt geweigerd met een zin die
uitlegt waarom, niet met een ontleedfout.

Dat is geen achterdocht jegens je vriend. Het is dat de app niet kan weten van
wie de code komt.

## 44. De app koppelt zelf, en laat zien wat ze koppelde

Bij het importeren wordt per oefening in vier stappen bepaald of de ontvanger
hem al heeft: hetzelfde id, dezelfde naam nadat hoofdletters, accenten en
leestekens genegeerd zijn, voldoende gelijkend van naam mét dezelfde primaire
spiergroep en categorie, of echt nieuw.

De derde stap koppelt ook, in plaats van te vragen. Acht oefeningen zouden acht
vragen worden voordat er iets mag gebeuren, en de kosten van een verkeerde
koppeling zijn laag: het voorbeeldscherm toont per oefening wat er gaat
gebeuren, en één tik draait het terug.

Dezelfde naam telt zwaarder dan een afwijkende categorie: dat veld vullen twee
mensen verschillend in. Een afwijkende categorie bij een *gelijkende* naam telt
wel: een bench press met halters is een andere oefening dan een met een stang.

## 45. De scanner brengt twee permissies mee, en geen internet

De QR-scanner gebruikt de gebundelde barcode-bibliotheek van Google, niet de
variant die haar model via Play Services ophaalt - die zou bij eerste gebruik
downloaden en daarmee de belofte breken. De prijs is zo'n 8 MB APK.

Er komen twee permissies bij. `CAMERA` spreekt voor zich. `ACCESS_NETWORK_STATE`
komt uit die bibliotheek en laat alleen zien *of* er een verbinding is; zonder
`INTERNET` kan er niets overheen. Die laatste weghalen zou kunnen, maar als de
bibliotheek de status opvraagt zonder de permissie volgt een SecurityException
in een pad dat hier niet te testen is. Hem laten staan en erover vertellen is
eerlijker dan hem stiekem strippen en hopen.

Het release-manifest haalt `INTERNET` er wél weg met `tools:node="remove"`,
zodat een volgende afhankelijkheid die hem meebrengt de belofte niet stil kan
breken. `test/security/offline_test.dart` bewaakt beide manifesten en zoekt in
`lib/` naar netwerkcode.

## 46. De release-sleutel staat niet in de repository, en de debugsleutel telt niet

Tot nu toe werd een release-build ondertekend met de debugsleutel, met een
opmerking erbij dat dat vóór publicatie vervangen moest worden. Voor bouwen op
één machine werkt dat; weggeven mag het niet. De Android-debugsleutel is
publiek bekend met een vast wachtwoord, dus iedereen kan een APK bouwen die
zich `be.fitlog.app` noemt, en Android laat die er overheen installeren - bij
de versleutelde database.

De sleutel wordt nu gelezen uit `android/key.properties`, dat git negeert,
net als elke `.jks` en `.keystore`. Ontbreekt dat bestand, dan valt de build
terug op de debugsleutel zodat een verse checkout gewoon bouwt, maar hij zegt
er tijdens het bouwen bij dat de uitkomst niet weggegeven mag worden. Een
waarschuwing die je alleen in een logbestand ziet, is geen waarschuwing.

Die sleutel is onvervangbaar op een manier die de meeste projecten niet kennen:
Android weigert een APK waarvan de handtekening veranderde, en opnieuw
installeren kost hier álle gegevens, want er staat niets op een server. De
sleutel is daarmee even kostbaar als de herstelzin van een gebruiker.

## 47. Eén APK voor iedereen, zonder de emulator-architectuur

Voor de downloadknop wordt niet met `--split-per-abi` gebouwd maar met
`--target-platform android-arm,android-arm64`. Drie bestanden waarvan de
bezoeker de juiste moet raden is een keuze die je aan niemand hoort te vragen;
de verkeerde keuze eindigt in een installatie die weigert zonder uit te leggen
waarom.

`x86_64` blijft eruit. Dat is de architectuur van emulators, en hij doet 30 MB
bij een bestand dat toch al groot is. Wat overblijft, 88 MB, draait op elk
Android-toestel dat er in het wild is.

## 48. Een sessie bewaart de kleur waarin ze gedaan is

De kleur hoort bij de routine, niet bij de losse sessie: je wil hem één keer
kiezen, niet na elke training. Maar een workout bewaart wél een kopie, precies
zoals ze de naam van de routine kopieert.

Zou de geschiedenis de kleur live opzoeken bij de routine, dan verandert je
kalender met terugwerkende kracht zodra je een routine hernoemt of een andere
kleur geeft, en verliest ze hem helemaal als je de routine weggooit. De naam
werkte al zo; de kleur volgt die keuze.

Opgeslagen als plaats in een vast palet, niet als kleurwaarde. Zo kan er niets
in de database staan wat de app niet kan tekenen, blijft het werken als het
palet ooit verandert, en past de kleur zich aan het thema aan.

Staan er twee sessies op één dag met verschillende kleuren, dan wint de eerste.
Mengen zou een kleur opleveren die bij geen van beide hoort.
