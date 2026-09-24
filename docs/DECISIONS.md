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

## 49. Links en rechts zijn twee sets, geen set met een vinkje

Een oefening één arm per keer doen kon op twee manieren gemodelleerd worden:
één set met een markering erop, of twee sets naast elkaar. Het zijn er twee
geworden, want de twee kanten halen zelden hetzelfde: links tien herhalingen,
rechts acht is de regel en niet de uitzondering. Met één rij was dat niet op te
schrijven.

Het gevolg is dat het volume vanzelf klopt. Beide kanten zijn echt gedaan en
worden allebei één keer geteld; er hoeft nergens met twee vermenigvuldigd te
worden, en de herstelschatting en de grafieken hoefden er niets voor te weten.

De schakelaar zit op de sessie, niet op de routine. Je zet hem aan wanneer je er
zin in hebt, en de volgende keer staat de routine weer op twee handen - precies
zoals gevraagd.

Een warming-up blijft één set. Een arm opwarmen is nog steeds één warming-up.

## 50. Twee handen en één hand hebben elk hun eigen verleden

De VORIGE-kolom kijkt naar de laatste sessie waarin de oefening in *dezelfde*
stand gedaan werd. Zet je hem om, dan verspringt de kolom mee.

Anders zou hij 30 kg tonen boven een set die je met één hand gaat doen, en dat
is geen richtlijn maar een valstrik. Dezelfde reden waarom een eenhandige set
geen persoonlijk record kan zetten of breken: 15 kg in één hand is geen mindere
dag dan 30 kg in twee, en in dezelfde lijst zou het zo lezen. `records_dao`
laat sets met een kant er daarom helemaal buiten, ook bij het herbouwen van de
records na het verwijderen van een workout.

## 51. Omschakelen laat staan wat al gelogd is

Wisselen van stand bouwt de sets opnieuw op, maar alleen de sets die nog leeg
zijn. Wat je al afgevinkt hebt blijft precies zoals je het gedaan hebt, met de
kant die het toen had.

De gewichten reizen niet mee. Wat je met twee handen tilde zegt niets over wat
je met één hand tilt, dus de nieuwe rijen beginnen leeg en de VORIGE-kolom vult
ze uit de juiste geschiedenis.

## 52. Een overgeslagen set is een eigen toestand, geen settype

De setknop kent er nu drie: leeg, gedaan, overgeslagen. Dat laatste staat in
een eigen kolom `is_skipped`, niet in `set_type`.

Overslaan is namelijk geen soort set. Een warming-up die je overslaat is nog
steeds een warming-up, en zou ik het in `set_type` proppen dan verlies ik het
type dat de set had én verspringt de nummering eronder - `labelSets` telt op
type. Twee losse velden houden de twee vragen uit elkaar: wát voor set is dit,
en wat is ermee gebeurd.

Het onderscheid dat het oplevert: leeg betekent "hier ben ik niet aan
toegekomen", overgeslagen betekent "die heb ik bewust laten staan". Alleen het
tweede is de moeite waard om mee te nemen, en daarom zegt de VORIGE-kolom de
volgende keer "Geskipt" in plaats van een streepje.

## 53. De tweede tik skipt, de lange druk wist

Vroeger was de tweede tik "toch niet gedaan". Dat is nu de derde. Wie zich
vergist heeft moet dus twee keer tikken in plaats van één, en dat is een echte
verslechtering voor de meest voorkomende correctie.

Daarom zit er een lange druk op de knop die in één gebaar terug naar leeg gaat,
vanuit beide andere toestanden. De cyclus blijft daarmee te doorlopen met één
vinger, en het ongeluk blijft één gebaar om terug te draaien.

De rusttimer blijft ongemoeid bij het skippen. Hij kan van een héél andere set
lopen, en die stilzetten omdat je elders een set wegstreept zou een timer
afbreken waar niets mis mee is.

## 54. Afronden mag een overgeslagen set nooit weggooien

"Verwijderen" bij het afronden wist elke set die niet is afgevinkt. Een
overgeslagen set is niet afgevinkt, dus die viel daar precies onder - en
daarmee zou het hele idee in rook opgaan voordat het ooit in de geschiedenis
belandde. De DELETE kijkt nu ook naar `is_skipped = 0`.

Om dezelfde reden telt hij niet mee in de vraag "x sets zijn niet ingevuld":
je hebt er al iets over gezegd, dus er valt niets meer over te vragen. En het
omschakelen naar één arm per keer laat hem staan, net als een afgevinkte set.

## 55. De settabel volgt de oefening, niet één vaste vorm

De kolommen waren altijd KG en REPS, wat je ook deed. Voor **137 van de 876**
oefeningen in de catalogus (123 op tijd, 14 cardio) betekende dat niets: een
plank log je in seconden, een loop in afstand en tijd. Die waarden stonden al
in de database (`duration_seconds`, `distance_m`) en de keypad kende ze al,
maar er was geen veld om ze in te tikken.

Nu bepaalt de categorie de kolommen: alles wat je in reps telt krijgt gewicht
en reps, iets op tijd krijgt TIJD, cardio krijgt AFSTAND en TIJD.

Gewicht hangt bewust aan `hasReps` en niet aan `hasWeight`. Op papier heeft een
lichaamsgewichtoefening geen gewicht, maar in de praktijk hang je een riem aan
een dip en een schijf op een push-up, en dat loggen mensen. Die kolom weghalen
zou 205 oefeningen iets afnemen dat vandaag werkt. Waar gewicht écht niets
betekent is het werk op tijd en op afstand - precies de categorieën die om iets
anders vragen.

Een kolom blijft ook staan zodra één set er al een waarde in heeft. Sessies van
vóór deze verandering zetten gewichten op van alles; die kolom verbergen zou
het getal onzichtbaar maken terwijl het in de database blijft staan, zonder
manier om het te corrigeren.

## 56. Een set wegvegen verwijdert meteen

Er heeft kort een undo-venster van vijf seconden op gezeten. Dat is er op
verzoek weer uit: een set terugzetten is één druk op "Set toevoegen", dus de
balk onderaan het scherm koste meer aandacht dan hij waard was.

Voor een sessie in je geschiedenis blijft de undo wél staan. Daar is het
verschil groot: een weggegooide workout is een uur werk en tientallen rijen,
een set is één regel.

## 57. Een houding wordt in seconden gelogd, niet in reps

De plank stond in de catalogus als lichaamsgewichtoefening en vroeg dus om
kilo's en herhalingen. Een plank heeft geen herhalingen.

De bron (free-exercise-db) markeert zulke oefeningen met `force: static`. Die
worden nu allemaal `duration`. Het raakt tien oefeningen: plank, side bridge,
de twee isometrische nekoefeningen, isometric chest squeezes, plate pinch,
standing olympic plate hand squeeze, crucifix, downward facing balance en prone
manual hamstring. De rest van de catalogus verandert geen letter, en de ids
blijven gelijk omdat ze uit een vaste namespace komen.

Bij drie ervan houd je ook gewicht vast (plate pinch, crucifix). Die krijgen nu
alleen een tijdkolom. Tijd is voor alledrie meer waar dan reps, maar
"gewicht én tijd" bestaat niet in het model; dat zou een vijfde categorie
vragen.

## 58. Een correctie aan de catalogus moet ook bestaande installaties bereiken

De catalogus wordt één keer geïmporteerd, bij de allereerste start, bewaakt
door `exercises_seeded`. Het asset repareren bereikt daardoor alleen nieuwe
installaties - iedereen die de app al had zou de plank in kilo's blijven
loggen.

`app_settings.seed_version` houdt daarom bij op welke bouw van de catalogus een
database staat. Staat hij achter, dan wordt bij het opstarten alléén het
*type* van catalogusoefeningen bijgewerkt. Zo smal gehouden met opzet: die ene
kolom is het enige dat ooit gecorrigeerd moest worden, en de pas kan zo geen
naam, uitleg, foto of zelfgemaakte oefening raken.

## 59. De tabbladen liggen naast elkaar, niet op elkaar

`StatefulShellRoute.indexedStack` zet een `IndexedStack` om de vier
taknavigators: eentje zichtbaar, drie achter een `Offstage`. Daar valt niet
tussen te vegen - je kan hoogstens een gebaar herkennen en dan springen, en dat
voelt als een schok.

De algemene `StatefulShellRoute` laat je die container zelf opmaken via
`navigatorContainerBuilder`. De vier takken liggen nu in een `PageView`, dus de
pagina volgt je vinger en valt op zijn plaats waar je loslaat. De router hoort
het pas als de pagina stil ligt: een veeg die je halverwege terugtrekt laat geen
spoor van takwissels achter.

Het loopt niet rond. Voorbij het laatste tabblad zit niets, en van het laatste
naar het eerste glijden zou aanvoelen als een fout.

Wat zelf zijwaarts scrollt - een grafiek, een rij chips, een sessie die je
wegveegt in je geschiedenis - pakt het gebaar eerst, omdat het dieper in de
boom zit. Die blijven werken zoals ze werkten.

## 60. Wat de pager loslaat, en wat hij vasthoudt

Twee dingen die ik gemeten heb in plaats van aangenomen, want ze bepalen of dit
een verbetering of een verslechtering is.

Een tabblad dat je verlaat verdwijnt uit de widgetboom - niet verstopt, weg. Ik
had er eerst een `TickerMode` omheen gezet om de animaties van verborgen
tabbladen stil te leggen, zoals de `IndexedStack` deed. Die laag deed niets:
wat er niet is, animeert ook niet. Eruit gehaald.

Je plek blijft wél bewaard. go_router bewaart de navigator van elke tak over
loslaten en weer oppakken heen, dus je scrollpositie en je half getypte notitie
staan er nog als je terugkomt. Dat had ik ook eerst zelf willen regelen met een
keep-alive; ook overbodig, en om het te bewijzen heb ik geteld hoe vaak een
tabblad opnieuw wordt opgebouwd. Eén keer.

Beide eigenschappen staan vast in `tab_pager_test.dart`, want ze leunen op
gedrag van go_router dat een volgende versie kan veranderen.

## 61. Een routine mag alleen mikken op wat je kan loggen

De routine-editor bood altijd gewicht en reps, ook voor een plank. De settabel
in je sessie volgt sinds versie 1.14 de oefening; de editor doet dat nu ook, met
letterlijk dezelfde regel - `setColumnsFor` staat op één plek en beide schermen
lezen eruit.

De kolom `target_duration_seconds` bestond al, werd al opgeslagen én al
gekopieerd naar je sessie. Alleen het invoerveld ontbrak. Er is nu ook een
`target_distance_m` bij gekomen, want zonder dat kon je voor cardio maar de helft
vastleggen.

Om die regel te kunnen delen leest hij niet langer een drift-rij maar vier losse
waarden. Een set in een sessie en een set in een sjabloon staan in verschillende
tabellen en betekenen hetzelfde; nu krijgen ze ook hetzelfde antwoord.

## 62. Je kan zelf zeggen hoe een oefening gedaan wordt

Bij de 876 oefeningen uit de catalogus stond geen manier om iets te wijzigen.
Toen de plank verkeerd getypeerd bleek kon de gebruiker niets: wachten tot ik
het asset repareerde én een correctiepas bouwde die bestaande databases
bereikt.

"Type wijzigen" staat nu in het menu van elke oefening, ook die uit de
catalogus. Er zullen meer van die gevallen zijn die ik niet ken, en dit is de
noodrem.

`exercises.category_overridden` onthoudt dat de keuze van jou was. De
cataloguscorrectie slaat zo'n oefening over - anders zou de volgende correctie
jouw keuze stilletjes terugdraaien, wat erger is dan het probleem dat de
correctie oplost.

## 63. Het workoutscherm luistert nu ook naar de oefeningentabel

Gevonden door de test die het typewijzigen moest bewijzen: hij faalde, en
terecht. De stream achter de lopende sessie keek alleen naar `workouts`,
`workout_exercises` en `workout_sets`. Het type van de oefening zelf staat in
`exercises`, en dat bepaalt sinds 1.14 welke kolommen de settabel toont.

Zonder deze regel kwam een typewijziging pas door bij de eerstvolgende
schrijfactie op een van de andere drie tabellen - dus meestal pas nadat je iets
anders had aangeraakt. Precies het soort bug dat je niet vindt door te kijken.

## 64. Zoeken vindt ook het materiaal en het type

Typ "barbell" en je krijgt alles wat je met een halterstang doet, niet alleen
wat het woord toevallig in zijn naam heeft.

De term wordt tegen drie dingen gehouden: de naam, het opgeslagen materiaal
(Nederlands: "halterstang", "kabel") en het type (Engels opgeslagen: `barbell`,
`cable`, `duration`). Dat laatste ook tegen het Nederlandse label dat de
filterchips tonen, zodat "tijd" de oefeningen op tijd vindt.

Twee namen voor hetzelfde is hier geen slordigheid maar de reden dat het werkt:
de gebruiker weet niet of hij "barbell" of "halterstang" moet typen, en met
allebei de kanten erin hoeft hij dat ook niet te weten.

De filterchips blijven bestaan. Zoeken is voor als je weet wat je zoekt;
filteren is voor als je aan het rondkijken bent.

## 65. Een snelle blik terwijl je een routine bouwt

Bij het kiezen van oefeningen kon je alleen aan- of afvinken. Welke van de vier
"row"-varianten je voor je had, zei de naam niet.

Elke rij heeft in de kiezer nu een ⓘ-knop: naam, bewegende afbeelding,
spiergroepen en uitvoering, in een blad over de lijst heen. Geen records, geen
grafieken, geen geschiedenis - je bent aan het kiezen, niet aan het studeren,
en alles meer is weer een scherm om van terug te komen.

De vraag was om op de *naam* te kunnen drukken. Dat heb ik niet gedaan, en dat
is een afweging waard: de naam is precies wat je aantikt als je een oefening
wíl kiezen. Dan zou de meest voorkomende handeling de zeldzame openen. Een
eigen knop is ondubbelzinnig en zichtbaar, en de rij blijft doen wat hij deed.

In de bibliotheek zelf staat de knop er niet. Daar is de volledige
oefeningpagina al één tik weg, en een tweede ingang zou alleen in de weg zitten.

## 66. Corrigeren vraagt wat de oefening kent

De bewerkdialoog in je geschiedenis vroeg altijd om gewicht en reps, wat de
oefening ook was. Voor een plank betekende dat: je kon de tijd - het enige
waarin hij gemeten wordt - helemaal niet corrigeren, en typte je toch iets in
die twee vragen, dan verdween de gelogde tijd achter een gewicht dat niets
betekent.

De oorzaak was van mezelf. In 1.14 heb ik het *loggen* per oefeningtype gemaakt
en het *corrigeren* laten staan. De dialoog loopt nu langs dezelfde
`setColumnsFor`-kolommen als de settabel.

Twee dingen die daarbij horen: `HistoryActions.updateSet` neemt nu per veld een
`Value`, zodat een veld dat niet gevraagd werd ook niet geschreven wordt. En
halverwege afbreken laat de hele set ongemoeid - een half doorgevoerde
correctie is erger dan geen.

## 67. Tijd en afstand tellen mee

Een plank loggen kon sinds 1.14, maar liep dood: geen record, geen lijn, niets
om te verslaan. Er zijn twee recordsoorten bij: **langste tijd** en **verste
afstand**.

Welke een set kan zetten hangt af van wat erin staat, niet van hoe de oefening
heet. Een tijd geeft een langste hold. Een afstand geeft een verste afstand -
en dan telt de tijd níét mee, want dezelfde afstand trager lopen is geen betere
loop. Een gewichtshold (plate pinch) zet allebei: het gewicht én de tijd.

De grafieken volgen nu de oefening, net als de settabel. Een plank krijgt één
lijn (langste tijd), cardio krijgt afstand en tijd, en alles wat je tilt houdt
de vier die het had. Vier lege grafieken tonen is erger dan er geen aanbieden:
je kan er niet aan zien of "geen data" betekent dat je het nog niet deed of dat
het niet bestaat voor deze oefening.

De vier `switch`-en die een recordwaarde opmaken waren exhaustief zonder
`default`. Daardoor wees de compiler precies de vier plekken aan die de nieuwe
soorten moesten leren opmaken, in plaats van dat ze stilletjes als kilo's op
het scherm waren gekomen.

## 68. Een ster bepaalt wat op je startscherm komt

Hou het app-icoon ingedrukt en je meest gedane routines staan er, klaar om te
starten. Welke dat zijn kies je niet apart: je zet een ster op de routines die
je echt doet, en het toestel neemt daaruit de drie die je het vaakst hebt
gedaan.

Dat aantal is Android, niet een keuze van mij: drie snelkoppelingen zijn
gegarandeerd, meer mag op papier en verdwijnt in de praktijk. Sterren mag je er
zoveel zetten als je wil; de volgorde erbinnen is het aantal sessies dat je
vanuit die routine hebt afgerond. Dat is de eerlijke maat voor "mijn gewone
workout" en de app heeft hem al, zonder ernaar te vragen. Gelijkspel gaat naar
de laatst gedane.

Een lopende sessie telt niet mee - die heb je nog niet gedaan.

## 69. Een tik op een snelkoppeling wacht netjes

Android geeft de tik door voordat de database open is, soms voordat je je
pincode hebt ingetikt. Hij wordt dus alleen genoteerd en pas uitgevoerd zodra
er iets is om mee uit te voeren.

Twee dingen die hij nooit doet. Een lopende sessie wordt niet weggegooid: je
komt in die sessie terecht, want dat is vrijwel zeker wat je bedoelde. En een
routine die je gesterd en daarna verwijderd hebt doet stilletjes niets - een
foutmelding over een snelkoppeling is erger dan er geen te krijgen.

De platformlaag vangt alleen `MissingPluginException` en `PlatformException`:
geen kanaal (een testmachine) en een launcher die weigert. Alles daarbuiten is
een fout van mij en komt gewoon naar boven.

## 70. De navigatiebalk beweegt mee met je vinger

De balk las tot nu toe de router, en die hoort het pas als de pagina geland is.
Je sleepte dus een tabblad in beeld terwijl de markering achterbleef, en dan
sprong hij.

Hij leest nu de positie van de pager: een breuk, waar 1,5 halverwege het tweede
en het derde tabblad is. Halverwege gaat de markering over, en trek je terug
voordat je daar bent dan is hij nooit verschoven.

Het is de markering die verspringt, niet die meeglijdt. Meeglijden vraagt een
eigen indicator in plaats van Material's `NavigationBar`, en dat is veel werk
voor een paar pixels. Tikken verandert niet: de positie springt, en de balk
speelt zijn eigen korte animatie af zoals altijd.

Die breuk staat bewust buiten de routerstate: hij verandert elk frame van een
sleepbeweging, en verder mag daar niets voor herbouwen.

## 71. De snelle blik hoort ook in de sessie

Het ⓘ-blad met de bewegende afbeelding en de uitvoering bestond alleen in de
oefeningkiezer. Tikte je tijdens een workout op de naam van een oefening, dan
kreeg je de volledige oefeningpagina: vier tabbladen met records, grafieken en
geschiedenis, en dan de weg terug zoeken.

Midden in een set wil je de foto en de uitvoering, niet je 1RM-verloop. Diezelfde
blad opent nu over de sessie heen. Onderin staat één regel naar de volledige
pagina voor wanneer je die wél wil - in de kiezer staat die er bewust niet,
want daar zou weglopen je selectie kosten.

## 72. De VORIGE-kolom doet nu iets

Hij stond er alleen maar te staan. Je las 80 kg × 8, en typte die 80 over om er
82,5 van te maken - terwijl het getal voor je neus stond.

Aantikken vult de rij. Geen knop: het blijft gewone tekst, want de kolom is in
de eerste plaats om naar te kíjken en een knop zou dat drukker maken dan nodig.
Aantikken vult alleen in; afvinken doe je zelf, want meestal wil je het getal
eerst nog bijstellen.

Alleen de kolommen die de oefening toont worden geschreven. Een verborgen
waarde overzetten zou erger zijn dan nutteloos: een opgeslagen gewicht laat de
gewichtskolom verschijnen, dus een vergeten kilogram op een plank zou die plank
een kolom geven die er niet hoort.

Is er niets te halen - geen vorige sessie, of een set die je toen oversloeg -
dan is er ook niets aan te tikken. Een tik die niets doet is erger dan geen
tik.

## 73. Terug met de keypad open sluit de keypad

De Android-terugknop en het terugveeggebaar liepen met de keypad in beeld
rechtstreeks de lopende sessie uit. Dat is ver van wat er gevraagd werd, en
makkelijk per ongeluk te doen terwijl je aan het loggen bent.

De keypad is het ding dat vóór je staat, dus terug betekent: leg dat weg. Een
tweede keer terug doet weer wat het altijd deed.

Geen extra sluitknop erbij. Het blauwe vinkje rechtsonder sluit de keypad al -
de waarden worden bij elke toets al weggeschreven, dus dat vinkje is niets
anders dan "klaar". Een derde manier zou de vraag "wat doet welke knop dan"
alleen maar oproepen.

## 74. De keypad komt op en gaat weer onder

Hij verscheen en verdween in één frame. Nu schuift hij op en neer, met een
sleepgreep bovenaan zoals elk ander blad in de app - en een veeg omlaag legt
hem weg, zonder dat je een klein knopje in de hoek hoeft te raken.

Niet de hoogte alleen en niet de positie alleen: allebei. De rusttimerbalk die
de keypad vervangt is veel lager, dus zonder de hoogte mee te animeren springt
het scherm op het moment dat de beweging begint - en dan is de animatie erger
dan geen.

De `AnimatedSwitcher` toont alleen het paneel dat aankomt. Ze overlappen laten
zou de doos voor de duur van de beweging op de hoogte van de langste zetten, en
dat is precies de sprong die we wilden wegwerken.

De veeg werkt alleen naar beneden. Omhoog vegen zou hier niets kunnen
betekenen - er is geen groter toetsenblok om uit te trekken - en er toch iets
mee doen voelt als een misser.

Wat de keypad níét wordt, is een echt `showModalBottomSheet`. Zo'n blad dimt
wat erachter ligt en vangt alle tikken op, terwijl je juist blijft tikken op de
setrijen erachter om van veld te wisselen. Hij ziet eruit als een blad en
beweegt als een blad, maar hij blokkeert niets.

## 75. Schermen met een pijltje omlaag komen ook van onderaf

De lopende sessie en de rusttimer sluit je met een pijltje omlaag in de hoek,
niet met een terugpijl. Ze gedragen zich als iets dat je over de app heen
trekt, dus bewegen ze nu ook zo.

De standaardovergang van Android is een zoom, bedoeld voor pagina's waar je
naartoe navigeert. Tegenover een pijltje-omlaag leest die als helemaal geen
animatie - wat precies de melding was.

## 76. De blauwe balk komt laat en gaat vroeg

Een sessie starten duwt haar eigen scherm omhoog over de schil. De blauwe balk
verscheen precies op dat moment, onder dat scherm - en omdat het scherm van
onderaf komt, is de strook waar die balk staat als laatste bedekt. Je zag hem
dus in beeld ploffen in de kier die er nog was.

Nu wacht hij tot dat scherm boven is. Tegen die tijd kan niemand hem zien
aankomen.

Stoppen is precies andersom: de balk gaat meteen, vóór het scherm wegzakt, dus
de strook die daaronder tevoorschijn komt toont nooit nog een balk voor een
sessie die er niet meer is.

Twee gevallen die het in de gaten hield. Gooi je de sessie weg tijdens dat
wachten, dan gaat de aankomst mee weg - anders zou er 260 ms later een balk
verschijnen voor iets dat al weg was. En de eerste waarde die de stream ooit
geeft is geen aankomst maar gewoon wat al waar was: open je de app op een
lopende sessie, dan staat de balk er direct.

De duur staat op één plek. De schil moet weten hoe lang dat scherm erover
doet, dus `kSheetRise` woont bij de paginaovergang en wordt daar gelezen - twee
losse getallen die toevallig gelijk moeten zijn, is een fout die pas opvalt als
iemand er één verandert.

## 77. Weggaan gaat eerst, opruimen daarna

Een sessie weggooien wachtte op de database en navigeerde daarna pas. Tussen
het sluiten van de bevestigingsdialoog en het bewegen van de pagina zat dus een
pauze van onbekende lengte - twee animaties met een gat ertussen, en dat is wat
als hakkelen leest. Het pijltje in de hoek had dat nooit, want daar gebeurt
niets in de database.

Nu vertrekt de pagina meteen en wordt er tijdens het wegschuiven opgeruimd. De
controller leeft langer dan het scherm, dus het verwijderen loopt netjes door
nadat het scherm weg is.

Daarmee wordt wél iets anders waar: de sessie verdwijnt uit de provider terwijl
het scherm nog in beeld schuift. De vertrekkende pagina bouwt dan opnieuw op en
zou "Geen lopende workout" tonen - een flits van het verkeerde ding, precies
waar je naar kijkt. Daarom houdt het scherm vast hoe de sessie er het laatst
uitzag zolang het aan het vertrekken is.

Die flits kostte moeite om vast te leggen. De eerste test slaagde ook zónder de
bewaking, omdat de pagina in die test geen tijd nodig had om te vertrekken en
het venster er dus niet was. Met een echte vertrekanimatie in de test faalt hij
op frame 0. Een test die niet kan falen bewijst niets, en deze bewees eerst
niets.

## 78. De samenvatting komt op dezelfde manier binnen

De sessie kwam van onderaf; de samenvatting nam haar plaats in met de zoom van
Android. Twee verschillende bewegingen in één stap, en de tweede begint voordat
de eerste is uitgewerkt. Nu rijst de samenvatting net zo.

## 79. Een pijltje naar rechts opent iets dat van rechts komt

Rijen die eindigen in een chevron - een routine, een oefening in de catalogus,
een sessie in je geschiedenis, een instelling - openen nu iets dat van rechts
binnenschuift, met de lijst die er een stukje onder wegschuift. Terug is
hetzelfde andersom.

De standaard van Android is een zoom. Die zegt niets over richting, en naast
een pijltje dat wél een richting aanwijst betekent dat pijltje dan niets meer.

Op één plek geregeld, in het thema, niet per route. Elke lijst in de app is
hetzelfde gebaar; lieten we elke route het zelf beslissen, dan lopen ze uit
elkaar zodra er één bijkomt. De schermen die van onderaf komen dragen hun eigen
pagina en blijven daarbuiten - die beweging betekent iets anders en moet anders
blijven.

Wat dit niet meebrengt is het terugveeggebaar vanaf de rand. Dat zit aan
`CupertinoPageRoute` vast, niet aan de animatie, en de rest van de app is
Material. De beweging alleen is wat gevraagd werd.

## 80. Elke route zegt zelf welke pagina hij gebruikt

Hier lag de echte oorzaak, en hij was groter dan de animatie waarvoor ik hem
zocht.

go_router leidt af of dit een Material- of een Cupertino-app is door de
widgetboom omhoog te kijken, en onthoudt wat het de eerste keer vindt. Hier
landt die gok op "geen van beide", en dan valt hij terug op een pagina **zonder
enige overgang** - voor de rest van de looptijd van de app. Elk scherm in
FitLog verscheen en verdween dus ogenblikkelijk.

Dat verklaart met terugwerkende kracht een eerdere melding: dat het pijltje
omlaag op de lopende sessie "meteen terug gaat zonder animatie of niets". Dat
was letterlijk waar. De schermen die ik daarna een eigen `CustomTransitionPage`
gaf bewogen wél, en dat maakte het verschil des te zichtbaarder.

Alle 27 gewone routes noemen nu hun eigen `MaterialPage`, met dezelfde velden
die go_router zelf invulde - paginasleutel, naam, herstel-id - zodat er niets
verandert behalve dat de gok weg is.

Een test leest `router.dart` en faalt zodra er weer een route in staat die het
aan de gok overlaat. Dat is de enige manier waarop dit terugkomt, en een
animatie die er niet is valt bij het lezen van code niet op.

## 81. De paginahelpers staan apart van de routetabel

`appPage` en `risingPage` wonen in `routing/pages.dart`, niet tussen de routes.
De schil leest `kSheetRise` daar ook uit. Een bestand dat alleen zegt "zo zien
pagina's eruit en zo bewegen ze" is makkelijker te controleren dan hetzelfde
verstopt boven een tabel van dertig routes.

## 82. De knop moet er al zijn om in de andere te kunnen veranderen

Het tabblad Trainen heeft "Routine toevoegen", een routine heeft "Start
workout", allebei zwevend in dezelfde hoek. Flutter laat de ene dan in de
andere overvloeien als je ertussen beweegt.

Dat lukt alleen als ze allebei bestaan op het moment dat de beweging begint. De
startknop wachtte tot de routine uit de database gelezen was, en tegen die tijd
had de binnenkomende pagina de andere knop al bedekt. Terugkomen zag er altijd
goed uit, want dan waren ze er allebei wel.

Hij staat er nu vanaf het eerste frame, ook terwijl er nog geladen wordt.
Starten heeft niets nodig behalve het id dat het scherm al had, dus vroeg tonen
belooft niets wat hij niet kan. Alleen als de routine er echt niet is - verwijderd,
of een fout - blijft hij weg, want dan valt er niets te starten.

De test moest het laadmoment vasthouden met een stream die nooit iets geeft. In
een test antwoordt de database sneller dan de eerste assertie, en de eerste
versie van de test slaagde daardoor ook met de fout er nog in.

## 83. Een hele oefening in één keer overslaan

Vier sets overslaan was vier keer dubbeltikken. Er staat nu "Oefening
overslaan" in het ⋮-menu, en als alles al overgeslagen is heet dezelfde regel
"Oefening toch doen".

Alleen de sets die nog openstaan bewegen mee. Een set die je al afgevinkt hebt
heb je gedaan, en de oefening achteraf overslaan maakt dat niet ongedaan.

De actie geeft terug hoeveel sets er bewogen. Was er niets te doen, dan zegt de
app ook niets - een bevestiging voor iets dat niet gebeurde is erger dan stilte.

## 84. De schijvenberekening zit waar je staat

Hij stond drie tikken ver in het ⋮-menu en ráádde je doelgewicht uit de
zwaarste set van de oefening. Op het moment dat je hem nodig hebt sta je met de
keypad open op een gewichtsveld, en dan weet de app precies welk gewicht je
bedoelt.

Er staat nu een knopje in de keypad, naast het wisknopje, dat het blad opent op
het getal dat je net getikt hebt. Alleen bij halterstang-oefeningen: bij
dumbbells, machines en kabels trekt de berekening een stanggewicht af dat er
niet is, en dan belooft de knop iets wat hij niet waarmaakt.

Het oude menu-item blijft staan voor wie er al aan gewend is.

## 85. RPE is een keuze, en vervangt de sessiebeoordeling

RPE lag half in de app: de kolom in de database, de keypadmodus, het
wegschrijven - alleen geen veld om hem in te tikken. Hij staat nu achter een
schakelaar in de workout-voorkeuren, uit als standaard. Het is een extra getal
per set en niet iedereen wil alles scoren.

Aan gezet verschijnt er een RPE-kolom, achteraan: het is een aantekening over
de set, niet een van de getallen die de set maken. Een set die er al een draagt
houdt de kolom ook als je de schakelaar weer uitzet, anders staat het getal
ergens waar je het niet kan zien of verbeteren.

Wat het doet met de hersteltijd:

Per spiergroep wordt het gemiddelde genomen van de sets die haar belastten,
**gewogen naar die belasting**. Een zware set op 9 zegt meer over wat de spier
doorstond dan een lichte op 6. Sets zonder score tellen niet mee in plaats van
als nul: de helft scoren middelt die helft.

RPE 8 is een gewone zware dag en verandert niets. Elk punt erboven of eronder
verschuift de schatting met 5%. Alles op 10 rekt hem dus met een tiende - zo'n
drie uur op een beendag. Bewust klein: een RPE is één indruk van één set,
gegeven terwijl je buiten adem bent. Dat verdient een duwtje, geen oordeel.

En het **vervangt** de beoordeling die je na de sessie geeft, in plaats van er
bovenop te komen. Allebei beantwoorden ze dezelfde vraag. Ze vermenigvuldigen
zou dezelfde indruk twee keer tellen; de RPE wint waar hij er is, want die is
per set en per spier, terwijl de sessiebeoordeling een hele avond dekt waarin
je benen zwaar waren en je armen een bijzaak.

## 86. RPE wordt gekozen, niet getikt

De invoer was een kaal cijferblok met het label "RPE": een getal op een schaal
die je nooit is uitgelegd. Dat is de slechtst denkbare invoer voor het cijfer
waar alle afgeleide berekeningen op leunen.

De vraag is nu "hoeveel had je er nog gekund?" met vijf antwoorden. Dat is iets
wat je telde terwijl je bezig was; "hoe zwaar voelde dat" is dat niet. Wat er
opgeslagen wordt is nog steeds de RPE, dus niets stroomafwaarts hoeft te weten
dat de vraag andersom gesteld werd.

Alles op of onder 6 is bewust één keuze. Het verschil tussen vier en zes reps
in reserve kan niemand inschatten; die twee apart aanbieden verzint data.

De bijschriften gaan over inspanning en noemen nooit "zwaar" of "pijnlijk".
Mensen halen die twee al door elkaar, en een label dat over zwaar spreekt
nodigt uit om een zere elleboog te scoren.

Eén ding dat de "volgende"-toets nu overslaat: RPE. Doorlopen naar een veld dat
een blad opent in plaats van cijfers aanneemt, is halverwege een rij van modus
wisselen.

## 87. Een 1RM uit hoe de set voelde

`estimatedOneRm` gebruikt Epley en gaat ervan uit dat élke set tot falen ging.
Bijna geen enkele set doet dat, dus 100 kg voor 5 levert hetzelfde getal of het
nu comfortabel was of je laatste rep. Dat is de reden dat die lijn heen en weer
springt.

`lib/core/calc/rpe.dart` leest in plaats daarvan een percentage van je maximum
af uit de tabel van Tuchscherer. Als aparte grafieklijn, niet als vervanging:
je hele bestaande geschiedenis heeft geen RPE, en aangepaste naast
onaangepaste waarden in één lijn is gewoon fout. Ook bewust geen recordsoort -
records zijn permanent en je eerste weken RPE zijn ongeijkt.

Wat er buiten blijft, en waarom niet geklampt wordt: reps boven 12 en RPE onder
6 vallen buiten de tabel. Daar de dichtstbijzijnde waarde pakken zou
zelfverzekerd antwoorden waar de tabel niets te zeggen heeft. Dus geen
schatting. Ook buiten: eenarmige sets, om dezelfde reden als bij de records, en
lichaamsgewichtoefeningen, die geen absolute belasting hebben om een percentage
van te nemen.

Per sessie een **gewogen gemiddelde** van de bruikbare sets, niet de beste.
Bij Epley zegt alleen de zwaarste set iets - een makkelijke set draagt geen
informatie over een maximum. Hier is elke gescoorde set al een schatting van
hetzelfde getal, dus luister je naar alle, en naar de betrouwbaarste het meest.
Sets ver van falen en lange sets wegen minder, want daar schat men slechter.

De lijn wordt pas aangeboden als er iets te tekenen valt. Vier lege grafieken
tonen is erger dan er geen aanbieden: aan een lege grafiek zie je niet of dat
"nog niet gedaan" of "bestaat niet" betekent.

## 88. Niet elke kolom is even breed

De RPE-kolom kreeg evenveel ruimte als KG en REPS, en die ruimte ging van de
VORIGE-kolom af - tot die "100 kg ..." toonde in plaats van wat je vorige keer
deed, het enige waar die kolom voor bestaat.

Een RPE is één of twee tekens en nooit meer; een gewicht kan er vier zijn. Dus
krijgt RPE een vaste 46 pixels en verdelen de andere de rest. Daarmee heeft
VORIGE met RPE aan ongeveer evenveel ruimte als zonder.

En de RPE-cel toont niets meer uit je vorige sessie. Dat grijze cijfer zag
eruit als een waarde die je zou overnemen door de set af te vinken - en
`completeSet` neemt gewicht, reps, tijd en afstand over, maar geen RPE. Precies
dezelfde leugen die de grijze gewichten ooit waren, voordat die wél gebruikt
gingen worden. Hoe zwaar een set voelde gaat bovendien over díe set, niet over
de vorige.

## 89. De overloopmenu's zijn kaarten geworden

Ze droegen als enige oppervlak nog de standaardstijl van Material: bijna
vierkant, getint in een kleur die verder nergens in de app voorkomt, en
uitgespreid alsof er een tablet onder lag.

Nu staan ze in het thema, één keer, met dezelfde rand en ronding als elke
andere verhoogde kaart. De regels zitten dichter op elkaar en hebben een
pictogram. Dat pictogram is geen versiering: tien regels die allemaal met een
werkwoord beginnen lees je woord voor woord, een kolom pictogrammen lees je in
één blik.

Verwijderen staat overal onder een scheidingslijn en in rood - het is de enige
regel in die menu's die je niet zomaar ongedaan maakt.

## 90. Twee keer dezelfde vraag stellen en er één gebruiken

Zet je RPE aan, dan vervalt "Hoe zwaar was het?" in de samenvatting.

Allebei vragen ze hetzelfde, en de herstelschatting luistert naar het cijfer
per set: in `lib/core/calc/recovery.dart` vervángt een RPE die beoordeling in
plaats van er bovenop te komen. Ze allebei blijven vragen betekent dus twee
keer vragen en er één gebruiken.

## 91. De app wist niet wat "vandaag" was

Bovenaan het startscherm stond "Workout van vandaag" boven de routine die je
het langst niet gedaan had. Dat is geen dagplanning, dat is een sortering - de
app had geen enkele manier om te weten dat jij op maandag borst doet.

Nu draagt elke routine zelf de dagen waarop ze staat, als zeven bits in
`routines.scheduled_days` (schema v16). Geen eigen tabel: zeven vaste waarden
zijn geen relatie, elke routine die haar eigen dagen draagt betekent dat één
dag vanzelf meerdere routines kan dragen, en één routine kan op meerdere dagen
staan.

Bewust géén veld op `RoutineDraft`. De editor schrijft de hele routine opnieuw,
dus een planning die in de draft zit zou verdwijnen zodra je een oefening
wijzigt. En een routine die je via QR van iemand krijgt hoort niet met diens
maandag aan te komen. Het is een eigen schrijfactie, net als de ster.

## 92. De ladder onder de kaart van vandaag

`buildTodayPlan` leest vijf sporten van boven naar beneden en stopt bij de
eerste die iets te zeggen heeft: wat vandaag gepland staat, anders "rustdag"
als er wél een schema is, anders je favorieten, anders de routine die je het
langst hebt laten liggen.

Die laatste sport is er met opzet. Zonder die zou iemand met routines maar
zonder sterren en zonder schema van een gevulde kaart naar een lege gaan - het
gedrag dat de app altijd had, weggehaald door een functie die alleen maar iets
toevoegde. Elke sport heeft een eigen kop, zodat de kaart nooit meer beweert
dan ze weet.

Een rustdag krijgt niets aangeboden. Een rustdag ís een antwoord, en er alsnog
een workout op duwen maakt het plan dat je zelf maakte ongedaan. Wat er wel
staat is wanneer de volgende dag is, plus een knop voor als je toch wil.

## 93. Een trainingsdag begint om vier uur, niet om middernacht

De kalender slaat om om twaalf uur; een trainingsdag niet. Wie om half één
's nachts nog in de sportschool staat bedoelt de sessie van vrijdag, en de app
was het daar al mee eens: de begroeting zegt tot zes uur "Goedenacht".

`kDayStartHour` staat op 4. Laat genoeg voor de late avond, vroeg genoeg dat
niemand er overheen traint. Het bepaalt welke dag van het schema gelezen wordt
én of een routine "vandaag al gedaan" is.

## 94. Het startscherm is een lijst geworden, geen vaste volgorde

De blokken op Start waren altijd al losse widgets; wat vastlag was de volgorde
waarin ze opgeschreven stonden. Die lijst zit nu in `app_settings.home_layout`
(schema v17), en daarmee kan iedereen zijn eigen eerste scherm hebben.

Alleen de begroeting en de back-upwaarschuwing staan vast, en die tweede is
daarmee naar boven verhuisd, direct onder de begroeting. Een waarschuwing die
je niet kunt uitzetten hoort een vaste plek te hebben, en als alles eronder kan
schuiven is halverwege geen plek meer.

Zet je alles uit, dan staat er geen leeg scherm maar één regel die zegt wat er
gebeurd is en waar je het terugdraait. De app die je keuze stilletjes overrulet
zou makkelijker zijn en minder eerlijk.

## 95. Verbergen is een naam op een lijst, geen afwezigheid

`home_layout` bewaart twee lijsten: `order` met alle blokken in jouw volgorde,
en `hidden` met wat uit staat.

Dat had korter gekund - alleen de zichtbare blokken opslaan - maar dan kan de
app niet zien of een blok uit staat of nog niet bestond toen je je scherm
indeelde. Een blok dat ik in een latere versie toevoeg zou dan onzichtbaar
blijven voor precies de mensen die ooit iets verzet hebben. Nu komt zo'n blok
achteraan en staat het aan, zonder migratie.

De hidden-blokken blijven ook op hun plek in `order` staan: zet je er een weer
aan, dan komt hij terug waar hij stond in plaats van onderaan.

Een waarde die stuk is levert de standaardindeling op, niet een uitzondering.
Het eerste scherm van de app is de slechtste plek om te falen.

## 96. Geen aparte instelling voor "schema of favorieten"

De vraag was: als ik én een weekschema én favorieten heb, wat komt er bovenaan?
Een schakelaar met drie standen zou dat oplossen, en zou daarna naast een
indeelbaar startscherm staan dat hetzelfde nog eens kan.

Dus is er geen schakelaar. "Favorieten" is gewoon een blok: zet je het aan, dan
staat het naast je planning; laat je het uit, dan zie je alleen je planning. Het
blok houdt zich stil wanneer "Vandaag" al op je favorieten is teruggevallen -
dezelfde drie routines twee keer is geen indeling die iemand kiest.

## 97. De PR-knop stond achter de data, en kon dus niet meevliegen

Een routine heeft "Start workout" en een oefening heeft "PR-poging", allebei
zwevend in dezelfde hoek, dus Flutter laat de ene in de andere overgaan als je
ertussen beweegt. Dat werkt alleen als beide er zijn op het moment dat de
beweging begint.

Op de oefeningpagina zat de knop binnen `exercise.when(data: ...)`, dus de
aankomende pagina landde zónder knop en die verscheen een frame later. Precies
dezelfde fout als op de routinepagina (beslissing over `routine_fab_test`), op
een andere plek.

Nu staat de hele Scaffold buiten `when` en is alleen de body nog afhankelijk
van de data. Zolang de oefening nog gelezen wordt is de knop er wel maar niet
aantikbaar: er valt nog niets aan te vallen. Is de oefening er niet meer, dan
is de knop er ook niet - er valt geen record te vestigen op iets dat niet
bestaat.

## 98. De dropdown bij een nieuwe meting is een sheet geworden

Bij een nieuwe meting koos je het type via een `DropdownButtonFormField`: een
grijze plaat met twaalf namen over de pagina, in een stijl die verder nergens
in de app voorkomt. Hij stond bovendien pal boven "Waarde" en "Datum", die
allebei wél een sheet openen als je erop tikt.

Nu is het hetzelfde veld met dezelfde sheet eronder, met de eenheid rechts op
elke regel - want de eenheid volgt je instellingen, en dezelfde meting is kg
voor de een en lb voor de ander.

Van type wisselen maakt het ingevulde getal leeg. 82 kg wordt geen 82 cm omdat
je van gedachten verandert over wat je aan het meten was.

Er staan er nog vijf elders: het type en de spiergroep van een eigen oefening,
je geslacht bij de eerste start, de map in de routine-editor, en de fotokiezer
bij het vergelijken. Die zijn hier bewust niet meegenomen - er is om deze
gevraagd - maar ze staan er nog, en dit is de plek waar dat opgeschreven
hoort. (Ze zijn intussen allemaal gedaan, zie 99 en 100.)

## 99. Een eigen oefening kiest nu met plaatjes

Categorie en primaire spiergroep waren de laatste twee dropdowns die je
tegenkomt als je iets nieuws maakt. Nu zijn het dezelfde velden met dezelfde
sheets als elders, via een gedeelde `PickerField` die ook de metingensheet
gebruikt - anders stonden er drie bijna-gelijke velden in drie bestanden.

Bij de categorie staat een pictogram. Material heeft precies één sportglyph en
dat is een dumbbell, dus de helft is geen portret van het materiaal maar zegt
wat het ding doet: iets dat je ondersteunt, een klok, een loper. De barbell
krijgt `linear_scale` - een staaf met gewicht erlangs, wat het dichtst in de
buurt komt.

Bij de spiergroep kan dat niet: die namen komen uit de catalogus, niet uit een
enum, dus er is geen tekening om naast te zetten. Wel heeft elke spier in deze
app al een kleur en twee letters - `MuscleAvatar`, te zien op elke oefeningrij.
Dezelfde markering in de kiezer betekent dat wat je kiest eruitziet als wat je
daarna overal terugziet.

## 100. En nu is er echt geen dropdown meer

De laatste drie: je geslacht bij de eerste start, de map in de routine-editor,
en de fotokiezer bij het vergelijken. Alle drie dezelfde `PickerField` met
dezelfde sheet eronder.

Twee dingen kwamen er anders uit dan de rest.

De map moest een wrapper terugkrijgen in plaats van een `String?`. "Geen map"
is een antwoord, de sheet wegklikken is dat niet, en allebei zijn ze null. Met
een kale `String?` kon de editor die twee niet uit elkaar houden en kon je een
routine nooit meer uit een map halen. De test daarvoor faalt ook echt als je
`pop()` in plaats van `pop((id: null))` schrijft.

De fotokiezer kreeg geen `PickerField` maar een compacte regel onder de foto -
een omkaderd formulierveld is te zwaar voor iets dat onder een afbeelding
hangt. In de sheet staat wel een miniatuur per regel. Een datum en een houding
vertellen je niet welke foto je gaat krijgen, en dat scherm bestaat om ernaar
te kijken.

Er staat nu ook een test die heel `lib/` afgaat op `DropdownButton`. Ze kwamen
één voor één terug en elke keer zag dat er los onschuldig uit; dit zegt het één
keer, voor alle schermen tegelijk - ook die waar je een hele flow voor moet
doorlopen om er te komen.

## 101. Op een foto tikken deed niets

Letterlijk niets. Alleen lang indrukken deed iets, en dat verwijderde hem. Een
raster van foto's waar je niet op kunt tikken is geen raster van foto's.

Een tik opent nu een sheet in de vorm van de oefeningvoorbeschouwing: de foto
op 42% van de schermhoogte, daaronder pose, datum, je notitie en de sessie
waar hij bij hoort. Een tik op de foto zelf gaat schermvullend, met knijpen om
in te zoomen, op zwart - een voortgangsfoto is grotendeels huid tegen een muur,
en het oppervlak van de app zit daar precies tussenin en laat allebei er
verkeerd uitzien.

De sheet leest de rij via `progressPhotoProvider` in plaats van hem doorgegeven
te krijgen. De bewerkpagina schrijft naar de database en deze sheet staat er op
dat moment nog onder.

## 102. Een foto bewaart nu ook wat je die dag deed

`note` bestond al als kolom maar was nergens in te vullen of te lezen. Nu wel,
samen met een koppeling naar een sessie: `progress_photos.workout_id`, schema
v18.

`ON DELETE SET NULL`, geen cascade. Je geschiedenis opruimen hoort je foto's
niet mee te nemen. De foto overleeft de sessie en vergeet alleen nog welke het
was. Er staat een test die faalt als iemand er ooit een cascade van maakt.

`updatePhoto` geeft alle vier de velden door bij elke aanroep, ook de lege. Met
een gedeeltelijke companion zouden "niet genoemd" en "leeggemaakt" hetzelfde
betekenen, en dan kon je een notitie nooit meer weghalen.

De sessies die de bewerkpagina aanbiedt komen van de dag zelf plus de dag
ervoor en erna. Je fotografeert jezelf voor of na het trainen, niet twee weken
later; een breder net zou vooral sessies aanbieden die niets met de foto te
maken hebben, en dat is erger dan er geen aanbieden.

## 103. Een maand was te grof

Vier foto's onder één kop "SEPTEMBER 2026", met de datum op elke tegel. Dat is
het raster dat vier keer hetzelfde zegt en je nog steeds laat uitzoeken welke
bij elkaar horen.

Nu is de maand de grote kop en de dag een regel daarboven: `zondag 13
september`. De datum is daarmee van de tegel verdwenen - de kop erboven zegt
het al, voor elke tegel eronder. Er staat nog wel "vandaag" of "3 dagen
geleden" naast de dag, maar alleen zolang dat iets toevoegt: verder terug valt
`relativeDay` terug op de datum, en de datum naast de datum zegt niets.

De tegel heeft er twee kleine tekens bij gekregen: een halter als er een sessie
aan hangt, een notitieblaadje als je iets geschreven hebt. Anders is wat je
opschreef onzichtbaar tot je hem opent.

## 104. Een voorkant tegen een achterkant is geen vergelijking

Het vergelijkscherm liet je elke twee foto's naast elkaar zetten. In de praktijk
leverde dat dit op: 7 september voorkant naast 7 september achterkant, met
"0 dagen ertussen" en "0 kg". De app hielp je daar actief bij.

De pose is nu de vergelijking, niet een van de twee helften. Bovenaan kies je
er een - met erachter hoeveel foto's je ervan hebt, zodat je vooraf ziet waar
iets te vergelijken valt - en daaronder kies je twee momenten van díe pose.
Standaard de oudste en de nieuwste, en het scherm opent op de pose waar je er
het meest van hebt. De pose staat daarmee niet meer onder beide foto's: de balk
erboven zegt het één keer en het is per definitie voor allebei hetzelfde.

Heb je van een pose minder dan twee foto's, dan zegt het scherm dat, met hoeveel
je er hebt. Een kapotte vergelijking aanbieden is slechter dan er geen
aanbieden.

Dat kost één ding: twee verschillende poses naast elkaar kan niet meer. Dat is
de bedoeling.

## 105. De posebalk liep van het scherm, en de foto's waren gesnoeid

Twee dingen die pas op een telefoon zichtbaar werden.

De drie posekeuzes stonden in een `Row` en die knipte de derde af tegen de
rechterrand. Nu is het een `Wrap`: past het niet, dan zakt er een naar de
volgende regel in plaats van te verdwijnen. Dat blijft ook kloppen bij een
grotere tekstgrootte, wat een `Row` nooit doet.

De foto's stonden op `BoxFit.cover`. Dat oogt netter en snijdt stilletjes de
zijkanten eraf - een halve telefoonbreedte is een smal raampje op een staande
foto, en sta je niet precies in het midden, dan vergelijk je twee muren. Nu is
het `contain`: de hele foto, kleiner. En een tik erop opent hem apart, waar wel
ruimte is.

## 106. Je kiest de foto's zelf

De posebalk is weg. Hij bestond om te voorkomen dat de app je een voorkant
tegen een achterkant liet zetten - maar dat probleem was dat de app die
combinatie *voorstelde*, niet dat je hem kon maken.

Nu ga je vanuit het raster in keuzestand: tegels krijgen een vinkje, onderaan
staat "Vergelijk (n)". Het begint niet leeg - de twee nieuwste van de pose waar
je er het meest van hebt staan al aan, precies de vergelijking die het scherm
vroeger voor je maakte. Alleen is het nu een startpunt in plaats van het enige
antwoord.

Kies je poses door elkaar, dan zegt het scherm dat bovenaan en verder niets.
Jouw vergelijking, jouw keuze.

Het maximum is vier. Daarboven is elke foto een postzegel en is het geen
vergelijking meer; dan kan je beter door het raster scrollen. Bij drie of vier
scrollt de rij zijwaarts in plaats van de breedte verder te delen.

Lang indrukken blijft verwijderen, ook al zit verwijderen nu ook in Bewerken.
Je hebt er spiergeheugen voor. Tijdens het kiezen doet het gebaar niets: één
vinkje naast een bevestiging om te verwijderen is te dichtbij.

De gekozen ids staan in het adres (`?fotos=...`), niet in een meegegeven
object. Android mag de app onder je vandaan opnieuw opbouwen; met een object
was de vergelijking dan weg.

## 107. Twee staande foto's naast elkaar blijven klein

Ook zonder bijsnijden. Daarom is er bij precies twee foto's een tweede
weergave: beide op volle breedte over elkaar, met een naad die je versleept.
Geen halvering en geen bijsnijden - maar het werkt alleen als de twee vanaf
ongeveer dezelfde plek genomen zijn, en dat kan de app niet weten. Dus is het
een knop en geen automatische keuze.

Bij drie of meer is er geen knop: een naad tussen drie foto's bestaat niet.

## 108. Het workoutscherm bouwde zichzelf te vaak opnieuw

Gemeten op het toestel, niet geraden: elke volledige build van dit scherm kost
17 tot 27 ms, en je budget is 16,7 ms per frame. Eén herbouw op het verkeerde
moment is genoeg om een animatie te laten haperen. Er waren er meer dan één.

**De vorige sessie.** `previousSets` en `previousNote` waren twee providers per
oefening per kant, en allebei deden ze `await ref.watch(activeWorkoutProvider
.future)` terwijl ze er alleen het id uit nodig hadden. Elke set die je afvinkte
draaide dus zes query's naar een sessie die onmogelijk veranderd kan zijn, en
elk antwoord bouwde het scherm opnieuw op.

Nu is het één `previousSession` voor de hele sessie, gesleuteld op welke
oefeningen erin zitten en hoe ze gedaan worden. Die bezetting is het enige dat
de geschiedenis kan veranderen: een oefening toevoegen moet haar verleden
meebrengen, en verder kan niets tijdens een sessie iets aan de vorige sessie
veranderen. Het is een string en geen lijst, want een lijst is nooit gelijk aan
de volgende lijst.

Gemeten effect: de builds bij het binnenkomen gingen van 14-31 ms naar 7-10 ms.

**De klok.** `Timer.periodic(1 seconde)` riep `setState(() {})` aan op het hele
scherm, en het enige dat veranderde was één regel tekst met de verstreken tijd.
Elke seconde werden dus alle zichtbare oefeningen en al hun setregels opnieuw
opgebouwd voor een klok - 17 tot 27 ms per seconde, de hele sessie lang, met
één kans op drie dat het midden in een paginaovergang valt. De klok heeft nu
haar eigen widget met haar eigen timer.

**Wat de kaarten niet meer doen.** Ze keken zelf naar vier tot vijf providers.
Nu krijgen ze alles doorgegeven. Een kaart die zelf kijkt is een kaart die op
haar eigen moment herbouwt, en er zijn er net zoveel als je oefeningen hebt.

## 109. Over meten

Twee instrumenten die ik onderweg heb weggegooid, opgeschreven zodat ik ze niet
opnieuw pak:

`dumpsys gfxinfo` en Choreographer meten de Android-viewpijplijn. Flutter tekent
naar zijn eigen Surface, dus die tellers rapporteren nul terwijl de app zichtbaar
hapert.

`debugPrint` is gesmoord: regels worden gebufferd en in bursts weggeschreven. De
duur die je zelf met een `Stopwatch` meet klopt, maar de tijdstempels in het
logboek zeggen niets over wanneer iets gebeurde. Ik heb daar een keer een
conclusie op gebaseerd die ik niet kon trekken. Wie het clusteren van gebeurte-
nissen wil meten moet ze in het proces verzamelen en in één keer wegschrijven.

## 110. Haperingen meet je op een toestel, niet in een widgettest

Er staat nu een `integration_test` die het workoutscherm op een emulator of
telefoon opent en telt hoeveel frames over hun budget gingen. Draaien:

```
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/workout_perf_test.dart -d <toestel> --profile
```

Waarom dit en niet iets eenvoudigers: een widgettest heeft geen rasterthread,
dus die kan per definitie niets over vloeiendheid zeggen. En de app echt
opstarten betekent door de onboarding heen, met een herstelzin die per
installatie verschilt - dus de test zet het scherm rechtstreeks neer met een
eigen database in het geheugen. Wat gemeten wordt is het scherm en zijn
overgang, niet het opstarten van de app.

Profielmodus is niet optioneel. Een debugbuild is niet AOT-gecompileerd en
bouwt widgets veelvouden trager; getallen daaruit zeggen niets.

Wat het opleverde, met een opwarmronde vooraf zodat eenmalige kosten er niet
doorheen lopen:

| oefeningen | frames te traag | ergste build |
|---|---|---|
| 4, koud   | 1 | 24,2 ms |
| 0, warm   | 0 |  3,4 ms |
| 1, warm   | 0 |  4,9 ms |
| 4, warm   | 1 |  9,2 ms |

Twee kosten die los van elkaar staan: een vaste koude start van ongeveer 24 ms
de allereerste keer dat het scherm getoond wordt, en daarbovenop zo'n 1,5 ms
per oefening. Op een telefoon is dat ruwweg het dubbele, wat overeenkomt met de
17 tot 27 ms die daar gemeten is.

## 111. Een dubbele layout die alleen een superset nodig had

Elke oefeningkaart zat in een `IntrinsicHeight`. Dat legt de hele inhoud van de
kaart twee keer door de layout - de kop, de notitie, elke setregel - en het was
er alleen voor het gekleurde streepje links van een superset, dat er bij de
meeste mensen nooit is.

Nu krijgt een kaart zonder streepje ook de `Row` niet meer. Dat moest samen: die
`Row` staat op `CrossAxisAlignment.stretch` en haalt zijn hoogte uit de
`IntrinsicHeight`. Alleen die laatste weghalen geeft een `Row` met onbegrensde
hoogte. In profielmodus staan asserties uit, dus dat leek in eerste instantie
een prachtige versnelling - het was een kapotte layout. De widgettest die erbij
hoort ving het meteen.

**Eerlijk over de winst: die heb ik niet kunnen meten.** Tien metingen met en
tien zonder, op de emulator, met vier oefeningen:

| | mediaan build | frames te traag |
|---|---|---|
| zonder | 9,0 ms | 1 van 108 |
| met    | 8,5 ms | 2 van 108 |

Dat valt binnen de ruis. De wijziging blijft omdat ze aantoonbaar minder werk
doet en het `IntrinsicHeight` nu staat waar het nodig is, niet omdat ze het
haperen oplost.

Wat op de emulator wél elke keer over het budget gaat is de allereerste keer dat
het scherm getoond wordt: 24 tot 27 ms build. Alles daarna is er ruim onder. Op
een telefoon is dat ruwweg het dubbele, en dat is precies één hapering per keer
dat je de app opent en je eerste workout start.

## 112. Gemeten op de telefoon zelf, en wat dat leerde

Hetzelfde harnas, ander toestel: `flutter drive ... -d <telefoon> --profile`.
Dat installeert tijdelijk een profielbuild over de release heen, wat alleen kan
als beide met dezelfde sleutel ondertekend zijn - anders weigert Android, en de
app verwijderen zou de database meenemen.

| oefeningen | frames te traag (van 12) | ergste build |
|---|---|---|
| 0 | 1 | 18,3 ms |
| 1 | 1 | 44,2 ms |
| 4 | 3 | 53,3 ms |
| 8 | 4 | 54,3 ms |

Drie tot vier van de twaalf frames van de overgang vallen weg. Dat is wat er te
zien is. De emulator liet daar één van de honderdacht zien: vijf keer sneller,
en dus geen vervanging voor de echte hardware.

De tijdlijn op de telefoon wijst niet naar onze widgets. Grootste posten:
afval ophalen (`ConcurrentMark` 68 ms, `Scavenge` 48 ms), Vulkan-pijplijnen
aanmaken (41 ms) en de glyph-atlas (23 ms) - dat laatste twee zijn eenmalige
grafische kosten. `ActiveWorkoutScreen` zelf staat op 12 ms over drie builds.

En de belangrijkste les: **de ruis is even groot als het signaal.** Drie
identieke metingen met één oefening gaven 39,5 / 18,4 / 32,9 ms. Op de emulator
was het niet beter. Een winst van vijf milliseconden is in deze opstelling niet
aan te tonen, hoe vaak je ook meet.

Dat sluit een hele aanpak uit: stukje bij beetje optimaliseren en per stap
meten of het hielp. Wat wel te bewijzen valt is een verandering die het werk
buiten de animatie legt in plaats van het goedkoper maakt - dan hoort het aantal
te trage frames tijdens de overgang naar nul te gaan, en dat is een verschil dat
boven de ruis uitkomt.

## 113. De lijst wacht tot de pagina stilstaat

Het bouwen van de oefeningenlijst kost op de telefoon 36 tot 44 ms, en een
frame is 16,7 ms. Gebeurt dat terwijl de pagina naar binnen schuift, dan gaan er
twee frames van de overgang verloren - elke keer opnieuw.

`_AfterTheSlide` wacht op `ModalRoute.of(context)?.animation` en bouwt de lijst
pas als die klaar is. Niets wordt goedkoper; het gebeurt alleen niet meer
terwijl er iets beweegt. De balken boven- en onderaan staan er vanaf het eerste
frame, alleen de lijst komt na.

Alleen voorwaarts. Dezelfde animatie loopt achteruit als je de pagina verlaat,
en de lijst dan leeghalen zou een flits van niets zijn. En zonder route - in een
widgettest, of ingebed in een ander scherm - is er geen animatie om op te
wachten en verschijnt de lijst meteen; wachten zou daar eeuwig duren.

Gemeten op de telefoon, vier herhalingen met vier oefeningen, alleen de frames
van de overgang zelf:

| | frames te traag | ergste build |
|---|---|---|
| zonder | 2, 2, 2, 2 | 35,8 / 40,8 / 44,4 / 38,0 ms |
| met    | 0, 0, 0, 0 |  7,6 /  9,5 / 12,0 /  6,3 ms |

Vier van de vier keer nul. Dit is precies het soort verschil dat wél boven de
ruis uitkomt, en het is waarom deze aanpak gekozen is boven het goedkoper maken
van de build: dat laatste bleek niet aantoonbaar (zie 111).

De prijs is zichtbaar: de oefeningen verschijnen een fractie na de rest van het
scherm.

## 114. Android maakte een back-up van de database naar Google

Het manifest zei niets over `android:allowBackup`, en dat staat standaard op
`true`. Android zette de hele app-map dus in het Google-account van de
gebruiker - inclusief de versleutelde database. De app belooft bij de eerste
start letterlijk: "Je gegevens blijven op dit toestel en worden nergens naartoe
gestuurd." Dat was niet waar.

Nu staat er `allowBackup="false"`, met `backup_rules.xml` voor Android 11 en
ouder en `data_extraction_rules.xml` voor nieuwere versies, allebei met alles
uitgesloten - ook overdracht naar een nieuw toestel.

Er is nog een tweede reden. De sleutel zit in de Android Keystore en gaat nooit
mee in een back-up. Een teruggezette database is dus per definitie niet te
openen, en dat is precies wat er gebeurde: na een herinstallatie zette Android
gegevens terug, de sleutel paste er niet bij, en de app bleef hangen op
`WrongDatabaseKeyException` met `hmac check failed for pgno=1` in het logboek.
Een back-up die niet te herstellen valt is alleen een kopie op een plek waar de
gebruiker hem niet wilde hebben.

## 115. Uit het foutscherm kwam je niet meer weg

Het scherm bood alleen "Opnieuw proberen". Een database waar de sleutel niet op
past gaat nooit open, hoe vaak je het ook vraagt, dus wie daar belandde zat er
voorgoed. De enige uitweg was de app verwijderen - wat alles weggooit, alleen
zonder het te zeggen.

Er staat nu "Opnieuw beginnen" naast, in rood, met dezelfde twee bevestigingen
als het wissen in de instellingen: eerst een vraag, dan het woord WISSEN
uittypen. Ook als opnieuw proberen niet eens aangeboden wordt, want juist dan is
er geen andere weg.

## 116. Spiergroepen en materiaal die de app niet kende

De kiezers boden alleen wat de meegeleverde catalogus toevallig bevatte:
`distinctPrimaryMuscles()` is een `SELECT DISTINCT` over de oefeningen. Een
spiergroep die nergens in voorkwam kon je dus niet kiezen, en eentje die je
zelf verzon bij een oefening verdween weer zodra die oefening gearchiveerd werd.

Nu is het de vereniging van twee bronnen: wat de catalogus gebruikt plus twee
kleine tabellen met wat je zelf toevoegt (schema v19). Die laatste blijven
bestaan zonder dat iets ze gebruikt - dat is precies waar ze voor zijn.

Weghalen mag alleen als niets het meer gebruikt. Een oefening die naar een naam
wijst die verder nergens bestaat is erger dan een lijst met één regel te veel.

Toevoegen kan ook vanuit de kiezer zelf, niet alleen via de instellingen: je
merkt dat er iets ontbreekt terwijl je de oefening aan het maken bent die het
nodig heeft.

## 117. Een eigen spiergroep is niet grijs

`AppColors.forMuscle` gaf alles wat niet in de vaste lijst stond dezelfde grijze
kleur - dezelfde die "geen spier" betekent. Met eigen spiergroepen erbij zouden
die allemaal op elkaar en op niets lijken.

De naam kiest nu zelf een kleur: een simpele som over de lettertekens, modulo
een palet. Dezelfde naam geeft overal en altijd dezelfde kleur.

Bewust niet `hashCode`: Dart belooft niet dat die tussen twee keer starten
hetzelfde is, en een spier die van kleur verschiet als je de app heropent is
slechter dan grijs.

Het palet is dat van de routines mín het grijs, want daar landen zou precies de
verwarring opleveren die dit moest oplossen.

Wat een eigen spiergroep niet krijgt: een plek op het lichaamsmodel, want dat
tekent vaste vormen. En de herstelschatting rekent met de standaardwaarde van
48 uur. Allebei staan ze in het scherm zelf, zodat je het weet voor je er een
toevoegt in plaats van erna.

## 118. Het startscherm indeel je op het startscherm

De indeling zat in een instellingenscherm: een lijst met schakelaars waar je de
tekst "Deze week" boven de tekst "Herstel" sleepte en pas daarna zag wat dat
opleverde. Je deelde iets in dat je niet kon zien.

Nu houd je een blok vast op Start zelf - hetzelfde gebaar als op je
telefoonstartscherm. De blokken gaan schuin staan, je sleept ze op hun plek en
je ziet het resultaat terwijl je bezig bent, want het zijn de echte blokken.

Twee maten: breed is de volle breedte, klein de helft, en twee kleine passen
naast elkaar. Tikken wisselt. Meer maten zouden op een telefoon nauwelijks van
elkaar te onderscheiden zijn, en elk blok moet elke maat kunnen tekenen.

Want dat is de andere helft: een klein blok is niet hetzelfde blok
uitgeknepen. "Deze week" laat breed drie cijfers zien en klein alleen je
volume; "Herstel" wordt "3 spieren herstellen"; bij "Volume" vallen de datums
onder de grafiek weg omdat die op halve breedte over elkaar zouden vallen.

De kop van een blok is verhuisd van een `SectionHeader` over de hele breedte
naar een regel binnen de kaart. Dat moest wel: twee blokken naast elkaar kunnen
hun naam niet boven zich delen.

Een blok dat je wegklikt heeft geen plek meer op het raster om het vandaan te
slepen, dus verborgen blokken wachten als chips bovenin, in de balk waar de
begroeting stond.

De opgeslagen indeling kreeg er één lijst bij: `small`. Een indeling van voor
de maten kent die sleutel niet en leest als alles breed - precies hoe het
scherm er stond. Niemands scherm verandert van vorm door een update.

## 119. Een kruisje dat buiten zijn blok hangt kan je niet aanraken

De wegklikknop stond op `top: -6, left: -6`, half buiten de kaart. Dat ziet er
goed uit en werkt niet: een `Stack` doet geen hit-test buiten zijn eigen grenzen,
dus de bovenste hoek van die knop was dood. De widgettest zag het meteen - een
tik die "miste" terwijl hij toevallig nog wel iets raakte - en nu staat het
kruisje binnen de kaart.

## 120. Het instellingenscherm voor de startpagina is weg

Er waren even twee manieren om de startpagina in te delen: het raster op de
startpagina zelf, en de oude lijst met schakelaars onder Instellingen. Die
lijst kon niet wat het raster wel kan (maten), en toonde nooit wat het scherm
ervan werd - precies de klacht die tot het raster leidde. Twee plekken met
verschillende mogelijkheden voor hetzelfde is erger dan één.

De rij *Instellingen → Startscherm* is gebleven, want zonder die rij moet je
weten dat lang indrukken bestaat. Hij brengt je nu naar het starttabblad in de
indeelstand. Dat gaat via een kleine provider (`homeArrangeRequest`) die het
tabblad afluistert: het tabblad staat al in de pager, dus het hoort het en zet
zichzelf aan. `Standaard` verhuisde mee naar de indeelbalk.

## 121. Een leeg blok krijgt geen plek op het raster

`Herstel`, `Records` en `Favorieten` tekenen niets als er nog niets is. In een
lijst viel dat niet op; in een `Wrap` wel, want een kind van nul hoog krijgt
nog altijd zijn rij en zijn tussenruimte. Op een verse installatie stond er
een gat tussen *Deze week* en *Volume*.

Of een blok gevuld is, is nu één provider (`homeBlockFilled`). Het raster
vraagt het voor het ruimte maakt, en het blok zelf vraagt het voor het tekent,
zodat de regel op één plek staat. In de indeelstand blijft elk blok staan - je
kan niets verslepen dat er niet is - met zijn naam en "Nog niets te tonen".

## 122. Het raster is een kolom met rijen, geen `Wrap`

Een `Wrap` zet twee halve blokken naast elkaar met hun bovenkanten gelijk en
hun onderkanten waar ze uitkomen. Dat is precies hoe je ziet dat iets een
lijst is die toevallig omslaat, en niet een raster. Nu bouwt het scherm de
rijen zelf - een breed blok krijgt een eigen rij, twee smalle delen er een -
en een rij met twee blokken staat in een `IntrinsicHeight`, zodat ze even hoog
zijn.

De breedtes komen daarmee uit `Expanded` in plaats van uit een berekening op
`MediaQuery`. Een half blok dat alleen in zijn rij staat blijft half: het
groeit niet stiekem de lege plek in.

## 123. Een eigen categorie leent een van de acht

Spiergroepen en materiaal zijn namen: je zet er een bij en er verandert verder
niets. Een categorie is dat niet. De acht ingebouwde zijn gedragingen - ze
bepalen welke kolommen een set heeft, welke records kunnen bestaan, en of de
schijvenberekening iets te zeggen heeft. Een categorie die de gebruiker
verzint kan onmogelijk een negende gedrag meebrengen.

Dus vraagt het toevoegen twee dingen: een naam, en welke van de acht ze
meerekent. In de database staat dat als `custom_categories(name, base)`, en op
de oefening blijft `category` de ingebouwde waarde terwijl de nieuwe kolom
`custom_category` de naam draagt. Alles wat over sets, records, delen en
matchen redeneert leest nog altijd `category` en merkt niets van dit hele
scherm. Alleen wat een label toont, toont de naam.

Filteren op een eigen categorie zoekt op die naam, niet op de basis: wie op
*Slee* filtert wil geen planken erbij. Filteren op *Tijd* geeft ze wel
allebei, want zo worden ze allebei gelogd.

Wat een routine deelt via QR draagt de ingebouwde categorie, niet de naam. Een
telefoon die *Slee* niet kent kan er ook niets mee; de oefening komt daar
binnen zoals ze gemeten wordt, en dat is het enige wat aan de overkant klopt.

Het scherm heet daarom niet langer "Eigen spieren en materiaal" maar "Eigen
keuzelijsten": het gaat over alles wat in een keuzelijst terechtkomt.

## 124. De app mag nu wél het internet op, en dat kost de belofte

FitLog kon niet online. Dat was geen instelling maar een eigenschap: de
release-build haalde de `INTERNET`-permissie uit het manifest, dus er viel
niets te versturen, ook niet per ongeluk.

De AI-coach breekt dat. Een Android-permissie wordt vastgelegd wanneer de app
gebouwd wordt, niet wanneer een gebruiker beslist dat hij een coach wil, dus
de permissie staat er voor iedereen — ook voor wie nooit een sleutel invult.
De harde garantie is weg en er is geen manier om ze te houden en de functie
te hebben.

Wat ervoor in de plaats komt is smaller en controleerbaar: precies één bestand
in `lib/` mag een HTTP-client importeren of `api.anthropic.com` noemen, en
`test/security/offline_test.dart` faalt zodra er een tweede bijkomt. De
sleutel van de gebruiker is de schakelaar: zonder sleutel wordt er geen client
gebouwd, bestaat het coach-blok op het startscherm niet, en gaat er geen byte
weg.

Twee schermen beloofden het oude verhaal letterlijk — de onboarding en het
Over-scherm. Die zijn herschreven vóór de permissie erin ging, niet erna. Een
app die op haar eigen beginscherm iets belooft dat niet meer waar is, is erger
dan een app zonder coach.

## 125. Wat de coach over je mag weten, vraagt hij zelf

De vraag was: sturen we een samenvatting van iemands training mee met elke
vraag? Dat geeft betere antwoorden en stuurt ook gegevens mee als de vraag
"hoeveel rust tussen sets" is.

Het is een tussenweg geworden. De coach krijgt niets mee; hij kan zeven
read-only opzoekingen doen (catalogus, laatste sessies, geschiedenis van één
oefening, records, routines, weekcijfers, lichaamsmetingen), elk met een
plafond op het aantal rijen. Alleen wat een vraag nodig heeft, vertrekt.

Elke opzoeking laat een zin Nederlands achter — "je laatste 5 sessies" — die
onder het antwoord staat én bij het bericht bewaard wordt. "Wat heeft dat ding
over mij gezien" is daarmee ook volgende maand nog te beantwoorden.

Datums gaan als dag de deur uit, nooit als tijdstip: het uur waarop iemand
traint zegt meer over die persoon dan over zijn training, en beantwoordt geen
enkele fitnessvraag.

De lus is begrensd: maximaal vier rondes opzoeken voor er geantwoord moet
worden, en maximaal twintig eerdere beurten die meegaan met een nieuwe vraag.
Allebei gaan ze over geld — het is de sleutel van de gebruiker.

## 126. De sleutel staat in de database, niet in de Keystore

De Keystore is de plek voor sleutels, maar deze sleutel is van Anthropic en
niet van het toestel: hij moet een herstel overleven, anders mag de gebruiker
hem gaan terughalen bij een dienst waar hij misschien niet meer bij kan. In de
versleutelde database staat hij achter dezelfde pincode als de rest, en hij
gaat mee in de back-up die de gebruiker zelf bewaart.

`setApiKey` is de enige plek die hem aanraakt, en de fouten van de client
gaan door een redactor: een API die je verzoek terugkaatst zou de sleutel
anders op het scherm zetten.

## 127. Twee diensten, herkend aan de sleutel

De coach was op Anthropic gebouwd; de eerste gebruiker had een sleutel van
Google. Een dienst schrappen die werkt en getest is, is waarde weggooien, dus
kan de client nu allebei.

Niet twee clients: één bestand, twee vormen. De deurtest zou anders zijn punt
verliezen — "precies één bestand in `lib/` mag netwerken" is controleerbaar,
"twee bestanden" is het begin van een lijst. Het bestand noemt beide adressen
letterlijk, één keer elk, en de test leest ze eruit.

Welke dienst een sleutel hoort, wordt van de sleutel afgelezen: `sk-ant-` is
Anthropic, `AIza` is Google. Niemand hoeft twee keer te zeggen wat hij al weet.
Iets onherkenbaars wordt Anthropic, en het instellingenscherm toont wat er
herkend is, zodat een verkeerde gok zichtbaar is vóór de eerste vraag in plaats
van erna.

Het gesprek staat nu in de vorm van de app zelf (`CoachMessage`), niet in die
van Anthropic. De lus die opzoekingen draait weet niet meer met wie ze praat;
de client vertaalt op de drempel. Dat is ook waar de verschillen zitten:
Anthropic koppelt een resultaat aan zijn vraag met een id, Google op naam;
Google wil `contents` met `parts` en een aparte `systemInstruction`, en weigert
een functiebeschrijving met een leeg `parameters`-object.

Modellen horen bij een dienst. Wie zijn sleutel vervangt, houdt een
modelkeuze die niet meer bestaat — `CoachModel.resolve` valt dan terug op de
standaard van de nieuwe dienst in plaats van een 404 te laten ophalen.

## 128. De dienst raden mag, beslissen niet

De eerste echte sleutel was er een van Google die begon met `AQ.`, en die
herkende de app als Anthropic: ik kende alleen `AIza`. De vraag was niet
alleen "welk prefix vergeten we nog" maar "wat doen we als een dienst morgen
weer iets nieuws uitdeelt".

Twee dingen veranderd. Het raden zelf is omgedraaid: alleen `sk-ant-` is
onmiskenbaar, dus dat beslist, en al de rest wordt Google — dat is de dienst
waarvan de sleutelvormen variëren. En er is een instelling bijgekomen
(`app_settings.chat_provider`, schema 22) waarmee de gebruiker het rechtzet.
Null blijft "leid het af uit de sleutel", wat elke bestaande installatie krijgt
en wat in bijna alle gevallen klopt.

Het scherm zegt nu welke van de twee het is: "Afgeleid uit je sleutel. Klopt
dat niet, tik hier" tegenover "Door jou gekozen". Een gok die zich voordoet als
een feit is het probleem; een gok die zegt dat hij er een is, niet.

## 129. Een foto bij je vraag, en wat dat kost

De coach kan nu een foto krijgen: meestal een toestel in de zaal waarvan je
niet weet hoe het heet. Hij zegt wat hij ziet en zoekt er met `search_exercises`
oefeningen uit de catalogus bij, zodat de naam die hij noemt ook echt in de app
bestaat.

Drie afwegingen.

De foto wordt kleiner bewaard dan een voortgangsfoto: 768 pixels in plaats van
1440. Dit is de enige foto in de app waar per token voor betaald wordt, en een
hometrainer is bij 768 nog altijd een hometrainer.

Ze gaat maar één keer de deur uit. Alleen de nieuwste foto van een gesprek gaat
mee met een vervolgvraag; oudere niet. Elke foto opnieuw meesturen bij elke
beurt is precies wat een lang gesprek stil duur maakt, en de vraag gaat bijna
altijd over de laatste.

En ze staat in dezelfde fotomap als de rest, met dezelfde opruiming. Dat is
geen detail: die opruiming gooit bij het opstarten weg waar niets naar wijst,
dus zonder deze regel was een foto uit een gesprek de volgende ochtend
verdwenen. `PhotoLibrary.cleanup` kent nu drie soorten verwijzing in plaats van
twee.

Onder het antwoord staat "de foto die je meestuurde" bij de opzoekingen. Het is
het meest persoonlijke dat vertrekt; dan hoort het ook in dat lijstje.

De coach mag wel iets zeggen over houding en uitvoering, en niets over lichamen
of uiterlijk - ook niet als erom gevraagd wordt.

## 130. Een stream lezen waar niemand naar luistert geeft niets terug

Twee keer nu dezelfde fout gemaakt. Eerst met de API-sleutel, en daarna met de
lijst gesprekken: `ref.read(ietsStreamProvider).value` op een provider waar op
dat moment niemand op geabonneerd is, geeft niet de inhoud maar "nog aan het
laden" — en dat las ik als leeg. Het instellingenscherm toonde "1 gesprek",
want dat scherm keek wél naar diezelfde lijst; het chatscherm bood alleen
"Nieuw gesprek" aan.

`.future` erbij halen lost het niet op: zonder luisteraar wordt de provider
weggegooid terwijl hij nog laadt, en dan gooit hij.

De regel is dus: wat een scherm nodig heeft, kijkt dat scherm in `build` aan,
en een callback krijgt die waarde mee in plaats van er zelf naar te grijpen.
Waar dat niet kan, gaat de vraag rechtstreeks naar de DAO — zoals de sleutel
nu uit `settingsDao.apiKey()` komt.

## 131. De balk telt wat de app verstuurde, niet wat je nog over hebt

De vraag was een balk met je dagelijkse tegoed. Het eerlijke antwoord: dat
tegoed is niet op te vragen. Noch Google noch Anthropic geeft een client een
endpoint dat zegt hoeveel er van een gratis laag over is; je merkt het pas aan
een 429. Een balk die doet alsof hij het weet, is erger dan geen balk.

Wat er wél is, is een telling van wat deze app zelf deed: het aantal calls en
de tokens komen met elk antwoord mee terug van de dienst. De balk zet dat af
tegen een getal dat de gebruiker zelf instelt (250 om mee te beginnen), en het
scherm zegt met zoveel woorden dat dit de eigen telling is.

Twee dingen die het verschil maken tussen een nuttige en een misleidende balk.

Hij telt **calls**, geen vragen. Een vraag waarbij de coach eerst iets in je
logboek opzoekt is er minstens twee, en een gratis laag telt ook calls. Daarom
staat er nu bij elk antwoord hoeveel calls het kostte (schema 24); een antwoord
van voor die kolom telt als één, het minimum dat het geweest kan zijn.

En de dag begint waar de dienst hem laat beginnen. De gratis laag van Google
springt terug om middernacht in Californië — hier rond negen uur 's ochtends.
Per lokale kalenderdag tellen zou om acht uur 's ochtends "3 vandaag" tonen
terwijl Google nog tweehonderd van gisteren op de teller had staan, precies op
het moment dat iemand hierop kijkt. Voor Anthropic, waar geen daglimiet
bestaat, is het een budget van jezelf en dus je eigen middernacht.

## 132. De coach stelt voor, de gebruiker maakt aan

De vraag was of de coach zelf oefeningen kan aanmaken. Technisch: ja, een
schrijftool erbij en klaar. Maar een model dat in je logboek mag schrijven kan
het ook stilletjes vervuilen - een oefening met de verkeerde spiergroep, een
dubbel van iets dat al bestond - en dat vind je pas maanden later terug in je
eigen cijfers.

Dus schrijft de coach niets. `propose_exercise` en `propose_routine` maken een
kaart in het gesprek met de details en een knop. Tik je, dan wordt het
aangemaakt; tik je niet, dan is er niets gebeurd. Dezelfde regel als bij de
foto: alles wat het logboek in gaat of de deur uit, is een handeling van jou.

Drie dingen die dat werkbaar houden:

Een routine mag alleen oefeningen bevatten die echt bestaan. Een naam die de
app niet kent komt terug als fout met de lijst erbij, zodat het model het kan
rechtzetten in plaats van een routine voor te stellen die half uit verzinsels
bestaat.

Een oefening die al bestaat wordt geen tweede: de tool antwoordt met de naam
die er al staat.

En als je een voorstel aanneemt met een spiergroep of materiaal dat de app nog
niet kende, worden die er meteen bij gezet - anders wijst de nieuwe oefening
naar een naam die nergens anders in de app bestaat.

Wat je aannam blijft op de kaart staan ("Toegevoegd", met een knop om het te
bekijken). Tweemaal tikken maakt geen twee.

## 133. De lijst met modellen komt van de dienst, niet uit deze app

De vraag was om Gemini 3 te kunnen kiezen. De eerste neiging is een naam
bijzetten in de enum — en dat is precies de verkeerde oplossing: modelnamen
veranderen sneller dan deze app uitkomt, en een naam die ik hier gok en die
niet blijkt te bestaan is een 404 die de gebruiker op zijn scherm krijgt voor
iets dat hij nooit gekozen heeft.

Dus vraagt de app het. `GET /v1beta/models` bij Google en `GET /v1/models` bij
Anthropic, met dezelfde sleutel als de vragen zelf, en de kiezer toont wat er
terugkomt: precies de modellen die die sleutel mag gebruiken, vandaag. Van
Google's lijst valt weg wat deze app toch niet kan gebruiken — embeddings,
beeld, spraak, de live-modellen — en de rest staat nieuwste eerst, voor zover
een naam dat kan zeggen.

Het gekozen model is daarom geen enum-waarde meer maar een tekst. De enum
blijft bestaan voor twee dingen: het standaardmodel per dienst, en de
terugvallijst wanneer er geen verbinding is — met de reden erbij op het scherm.

Dat zijn twee adressen erbij, allebei op hosts die al toegestaan waren en
allebei in hetzelfde ene bestand. De deurtest leest ze nu alle vier uit dat
bestand en controleert dat er geen derde host tussen staat.

## 134. De handtekening van Google gaat onveranderd terug

Met een Gemini 3-model brak elke vraag waarvoor de coach iets moest opzoeken:
"Function call is missing a thought_signature in functionCall parts."

Die modellen sturen bij een `functionCall` een `thoughtSignature` mee, en die
hoort er onveranderd bij te zitten wanneer je die beurt terugstuurt met het
resultaat. Wij gooiden ze weg, dus kwam de tweede ronde zonder terug en werd
ze geweigerd — precies de rondes waar deze app op draait, want elke vraag over
het eigen logboek is er twee.

De handtekening hoort bij het deel waarop ze binnenkwam, dus zo wordt ze ook
bewaard: eentje per `functionCall` en eentje voor het tekstdeel. Verder doet
de app er niets mee — niet lezen, niet interpreteren, alleen dragen. Bij
Anthropic bestaat ze niet en blijft het veld weg.

Het viel pas op met een echte sleutel en een echt model. De namaak-API in de
tests antwoordde netjes zonder handtekening, want ik wist niet dat ze bestond.
Nu staat ze in de testantwoorden, en een test faalt zodra ze onderweg
verdwijnt.

## 135. Eén dienst tegelijk: Anthropic staat uit als keuze

Twee diensten ondersteunen betekent twee vormen, twee foutafhandelingen en
twee manieren waarop iets stuk kan zijn dat je niet allebei kan uitproberen.
Met een gratis Gemini-sleutel in de hand is Google de dienst die er werkelijk
toe doet, dus staat Anthropic uit als keuze.

Niet weg: `kOfferedProviders` is één lijst met één element, en die regel
uitbreiden brengt hem terug. De client, de vormen en hun tests blijven staan;
wat weg is, is de mogelijkheid om er een sleutel voor in te vullen.

Twee dingen volgen daaruit.

Een sleutel die onmiskenbaar van een andere dienst is (`sk-ant-`) wordt
geweigerd bij het invullen, met de reden. Anders mislukt pas je eerste vraag,
met een foutmelding van een server die niets weet van deze keuze.

En de client krijgt de dienst nu mee in plaats van hem uit de sleutel af te
leiden. De app beslist wat ze aanbiedt; de client hoort daar niet stilletjes
van te mogen afwijken.

De schermtests praten nu ook Gemini: de namaak-API antwoordt in Google's vorm,
want dat is de enige vorm die de app nog spreekt.

## 136. Aanbevolen is een regel, geen lijstje namen

De lichte Gemini 3-modellen staan bovenaan in de modelkiezer, onder
"Aanbevolen". Niet omdat ze de slimste zijn, maar omdat ze in de gratis laag
veruit de meeste ruimte per dag hebben — en dat telt hier zwaarder dan elders,
want één vraag waarbij de coach iets opzoekt kost twee of drie aanvragen.

Welke dat zijn, staat niet als namenlijst in de app. Dat zou dezelfde fout zijn
als de modellenlijst zelf hardcoderen: `gemini-3.5-flash-lite` en
`gemini-3.1-flash-lite` zijn de twee die bestaan terwijl ik dit schrijf, en er
komen er meer. De regel is daarom "een gemini-3-model met flash-lite in de
naam", wat ook een `-preview`- of `-001`-variant vangt.

Ze verschijnen alleen als de sleutel ze werkelijk kan gebruiken, want de lijst
komt van Google. Heeft de sleutel er geen, dan staat er ook geen kopje
"Aanbevolen" boven een lijst waarin niets aanbevolen is - dan is het gewoon één
lijst.

## 137. Een beeldmodel is geen coach, ook al praat het hetzelfde

"Nano Banana 2 Lite" stond in de lijst, en zelfs onder Aanbevolen: het heet
iets met flash-lite, het is een gemini-3-model, en het antwoordt op
`generateContent` — alleen antwoordt het met een plaatje.

Het filter keek naar losse woorden in de id (`imagen`, `veo`, `tts`) en miste
zowel `image` als de naam waaronder Google die modellen uitbrengt. Nu kijkt het
naar de id én de weergavenaam, en vallen `image`, `banana` en `audio` er ook
onder. De aanbevelingsregel bouwt daarop voort in plaats van ernaast te staan:
wat geen chatmodel is, kan nooit aanbevolen zijn.

Het blijft raden op namen, en dat is eerlijk gezegd broos — Google zegt in die
lijst niet met zoveel woorden "dit levert beeld op". Beter dan het alternatief:
een model aanbevelen dat op elke vraag een plaatje terugstuurt.

## 138. Tekenen mag, maar alleen waar het iets kost dat je zelf koos

De coach kan nu een illustratie laten tekenen bij een oefening die je maakt.
Dat is de eerste functie in deze app die geld uitgeeft bij één tik, en dat
bepaalt de hele vorm ervan.

Drie grenzen, en ze zitten alle drie in de code, niet in een goede gewoonte:

Zonder token gebeurt er niets. Het is een eigen sleutel (`image_api_key`),
los van de Gemini-sleutel, en zonder die sleutel bestaat de knop niet en wordt
er geen client gebouwd. Wie de coach gebruikt maar dit niet wil, heeft het
vanzelf niet.

Alleen bij het maken van een oefening. Niet in de chat, waar één zin "teken
eens" een tekening zou kosten, maar in het scherm waar je een eigen oefening
invult - daar heeft een plaatje een plek om te landen.

En de tekening ging eerst over het materiaal, uitdrukkelijk zonder mensen -
omdat een model juist daar het overtuigendst fout is. Dat was verkeerd gedacht:
de twee afbeeldingen bij een oefening zijn een begin- en een eindpositie, en
zonder iemand die de beweging uitvoert tonen ze niets. Er staat nu dus wel een
persoon in, en het waarschuwingslabel doet het werk dat het weglaten van mensen
moest doen.

Wat er getekend is, wordt onthouden (`exercises.images_generated`) en het
detailscherm zegt het: "getekend door AI, geen foto van de uitvoering". Bij het
proberen kwam er een keurige machine uit die niet bestaat - een bench, een
staander en losse schijven door elkaar. Dat is precies waarom die regel er moet
staan.

Technisch: derde host in het ene netwerkbestand, met zijn eigen adres in de
deurtest. Hugging Face stuurt de call door naar wie het model nog draait
(nscale, fal, wavespeed) en rekent af op het token. Google's eigen
beeldgeneratie viel af: die is in België niet beschikbaar via de API, wat de
test met een echte sleutel uitwees - `FAILED_PRECONDITION: Image generation is
not available in your country`.

## 139. De coach schrijft de beschrijving van zijn eigen tekeningen

Twee plaatjes bij een oefening zijn geen twee plaatjes: het zijn een begin- en
een eindpositie, en het verschil tussen die twee is de hele inhoud. Een
sjabloon in de app weet dat verschil niet. Het model dat de oefening zonet
bedacht, weet het wel.

`propose_exercise` geeft daarom `start_image_prompt` en `end_image_prompt` mee,
in het Engels, en die woorden leiden de tekening. De app hangt er alleen een
vaste staart aan: één persoon, sportkleding, hele lichaam in beeld, zelfde
achtergrond. Dat is wat een paar tot een paar maakt - zonder die staart krijg
je twee tekeningen in twee stijlen en zie je het verschil in de stijl in plaats
van in de houding.

Op de kaart staat daarvoor een tweede knop, niet een schakelaar: "Toevoegen"
en "Toevoegen mét tekeningen" met eronder wat het kost. Het verschil tussen de
twee knoppen is precies waar je ja tegen zegt. De knop verschijnt alleen met
een token, en alleen als de coach ook echt beschrijvingen meestuurde.

De systeemprompt groeide hierdoor over zijn budget van 4000 tekens. Die grens
is opgehoogd naar 4300 én de tekst is ingekort: hij rijdt mee met elke vraag en
de gebruiker betaalt hem per keer, dus dat moet een beslissing zijn en geen
ongeluk.

## 140. Het merkteken "getekend door AI" hangt aan de foto, niet aan de oefening

De oefening onthield dat ze ooit getekend was en bleef dat zeggen, ook nadat de
tekeningen eruit gehaald waren. Dan staat er een waarschuwing onder een naam
waar niets meer bij hoort - of erger: onder een echte foto die je er zelf bij
gezet hebt.

Het scherm houdt nu per vak bij of wat er hangt getekend is. Een vak leegmaken
of er een foto in zetten haalt dat weg; laten tekenen zet het terug. Wat er
bewaard wordt is "er hangt nog minstens één tekening". Zo praat het merkteken
altijd over iets wat er ook echt staat.

## 141. Een korte zin tekent beter dan een goede beschrijving

De tekeningen bij een machine-oefening klopten niet: bij "Diverging seated
row" kwam er een man op een krukje uit die zijn biceps spande, zonder machine.
De eerste verdenking was het model - `FLUX.1-schnell` is de uitgeklede versie
die in vier stappen tekent - dus is het uitgezocht in plaats van aangenomen,
met een echte sleutel.

Wat de test uitwees, in deze volgorde:

`size` wordt aanvaard. De tekening komt nu staand binnen (768x1024), de vorm
van het vak waar ze in hangt, dus er wordt niets meer weggesneden.

Het zwaardere model is niet de oplossing. `FLUX.1-dev` bestaat wel bij fal-ai,
maar alleen via hun eigen adresvorm, en het antwoord is een link naar
`v3b.fal.media` - een tweede vreemde host, waar nscale de afbeelding zelf
meestuurt. En met onze lange prompt tekende dat duurdere model iets dat er
nog minder op leek: een zijwaartse heffing met twee dumbbells.

De lengte van de prompt was het probleem. Dezelfde `schnell`, met één zin van
92 tekens - "A man seated at a rowing machine pulls two handles back to his
ribs, elbows behind his body" - tekende wel iemand op een roeitoestel met de
ellebogen naar achter. Vier stappen zijn te weinig om veel details tegen
elkaar af te wegen; wat zo'n model niet kan wegen, middelt het weg.

Dus: de coach wordt om één korte zin gevraagd in plaats van om een volledige
beschrijving, en de app knipt wat er binnenkomt af op 160 tekens, op een zin
of anders op een woord. Het sjabloon voor een oefening die je zelf maakt is
even kort geworden. Wat de app erachter hangt blijft staan - die staart zat
ook in de geslaagde test.

Tegen de verleiding in om dit "op te lossen" met een duurder model: het model
was niet stuk, de vraag was te lang.

## 142. Twee tekeningen van één oefening horen dezelfde persoon te zijn

Bij een overhead triceps extension kwamen er twee tekeningen terug: links een
man met een wit hemd en een pet in een squatrek, rechts een man in een grijs
hemd bij een kabelmachine. Allebei met de armen gestrekt. Wat je eruit zou
moeten lezen - het verschil tussen begin en eind - was het verschil tussen
twee vreemden in twee zalen.

Twee oorzaken, allebei van ons.

Het waren twee losse opdrachten, elk met hun eigen toevalsgetal. Die krijgen
nu hetzelfde `seed` mee, en de kleding staat in de staart ("a grey tank top
and black shorts"). Met een echte sleutel getest: dezelfde persoon, dezelfde
schoenen, dezelfde achtergrond, en alleen de armen bewegen. Precies wat een
paar moet zijn.

En de coach beschreef tweemaal dezelfde houding, omdat er "beschrijf de
startpositie" gevraagd werd en een model dan de oefening beschrijft in plaats
van de houding. De opdracht vraagt nu naar de stand van armen en benen, met de
eis dat de twee zinnen van elkaar verschillen en met dit geval als voorbeeld:
begin met gebogen ellebogen, eind met gestrekte armen.

Het zaad zit per bewerkscherm en per voorstel, niet in de database. Teken je
een vak opnieuw dat er al een had, dan rolt er een nieuw getal: je tikte een
tweede keer omdat je iets anders wou zien. Daarmee valt het paar uit elkaar
tot je het andere vak ook opnieuw laat tekenen - dat is de prijs van opnieuw
mogen proberen, en die is het waard.

## 143. De zin die getekend wordt is van de gebruiker, niet van de app

Een overhead triceps extension kwam er als een optrekbeweging uit. Vier keer
dezelfde oefening gevraagd, met een echte sleutel en hetzelfde toevalsgetal,
alleen de woorden anders:

- van achteren, "elbows bent, holding a bar behind his head" -> een man die
  een barbell boven zijn hoofd houdt;
- van opzij, met boven- en onderarm netjes beschreven -> iemand die zijn
  biceps spant;
- van opzij, "arms straight above his head, holding a bar" -> het negeerde
  "van opzij" en tekende weer een optrekbeweging;
- van opzij, mét de naam van de beweging en zonder stang -> klopt.

Twee dingen staan daarmee vast. De naam van een beweging stuurt beter dan een
beschrijving van gewrichten. En het woord "bar" boven een hoofd roept een
optrekbeweging op die sterker is dan de rest van de zin.

Allebei zijn ze nu in de opdracht aan de coach verwerkt. Maar dat is niet de
echte les. De echte les is dat geen enkele vaste formulering elke oefening
goed krijgt, en dat wie de oefening kent - de gebruiker - het woord dat in de
weg staat er zo uit haalt. Bij "Laten tekenen" verschijnt daarom eerst de zin
zelf, in te vullen zoals je wil, met "Tekenen" eronder. Het sjabloon is nog
altijd het voorstel; alleen is het nu een voorstel en geen besluit.

Daarom ook `describe()` naast `promptFor()`: wat de gebruiker te zien krijgt
is de zin zonder de staart van de app. Die staart is een besluit van de app
over hoe een paar eruitziet, geen tekst om aan te rommelen.

## 144. Ook bij de coach lees je eerst wat er getekend wordt

De oefening die de coach aanmaakte heette "Triceps Overhead Extension - V-Bar
Attachment", en die naam gaat mee in de tekenopdracht. Het woord waarvan in
143 vaststond dat het een optrekbeweging oproept, stond dus in de naam die de
coach zelf koos - geen instructie aan het model haalt dat er nog uit.

De knop "Toevoegen mét tekeningen" opent daarom nu hetzelfde vakje als het
eigen scherm, maar dan met de twee zinnen van de coach erin: start en eind
naast elkaar, in te vullen, met "Tekenen" eronder. Pas daarna gaat er tegoed
op.

Dat is dezelfde keuze als 143, doorgetrokken naar de plek waar ze het hardst
nodig was: het model is niet bij te sturen met nog een regel in de
systeemprompt, wie de oefening kent wel. En het scheelt ook geld - je ziet nu
waar je voor betaalt voor het betaald is.

## 145. Dezelfde coach, maar met maar één ding voor zijn neus

De twee zinnen onder "Wat moeten de tekeningen tonen?" komen van de coach,
maar hij schrijft ze terloops: hij is op dat moment een oefening aan het
bedenken, met negen tools en een systeemprompt vol andere regels. De regels
die we uit mislukte tekeningen geleerd hebben - noem de beweging, geen stang
boven het hoofd, laat de twee houdingen verschillen - leest hij dan voorbij.
Dat is precies wat er gebeurde: hij noemde de oefening zelf "Triceps Overhead
Extension - V-Bar Attachment".

Er staat nu een knop in dat vakje die hem opnieuw vraagt, met alleen die ene
opdracht ervoor (`kFramePromptSystem`) en zonder tools. Hij krijgt de naam,
het materiaal en de uitvoering, en antwoordt met twee zinnen in JSON.

Wat het kost wordt bijgeschreven op het antwoord waar het voorstel in stond.
Anders zou de dagbalk in de instellingen minder tonen dan er werkelijk de deur
uitging, en die balk bestaat juist om dat te weten.

Het blijft een voorstel: het vult de twee velden in, het tekent niets. Tekenen
doe je pas als er staat wat jij wil.

## 146. Een grens uit twee metingen is een gok met cijfers erbij

De beschrijving werd afgekapt op 160 tekens. Dat getal kwam uit 141: een zin
van 92 tekens tekende goed, een opsomming van 450 tekende niets bruikbaars.
Tussen die twee is nooit gekeken, en het plafond is op het lage punt gelegd.

Twee dingen mankeerden eraan. De zin die in de test het beste werkte - de
beweging bij naam, dan hoe de gewrichten staan - loopt tot een stuk of 140
tekens, dus er was nauwelijks ruimte om die gewrichten er nog bij te zetten.
En wat er niet in paste werd stil weggeknipt: in het vakje stond iets anders
dan wat er verstuurd werd.

De grens staat nu op 320 - ruimte voor de gewrichten, niet voor een lijst - en
beide vakjes tellen mee terwijl je typt, zodat je ziet wanneer je eraan komt.
De coach mag 45 woorden gebruiken in plaats van 25, met erbij waarvoor die
ruimte bedoeld is.

Wat overeind blijft uit 141: meer woorden maken de tekening niet beter. Ruimte
om precies te zijn is iets anders dan ruimte om alles te zeggen.

## 147. Waar de tekeningen voor bedoeld zijn, en waar niet

Na zes rondes staat vast wat dit model kan: het tekent een houding die je
beschrijft, herkenbaar en in een vaste stijl, en het kent geen enkel echt
apparaat. Voor een stang-, dumbbell- of lichaamsgewichtoefening levert dat
iets bruikbaars op; voor een kabel- of machineoefening een aannemelijke
benadering met het verkeerde apparaat erbij.

Daarmee is de plek van deze functie afgesproken: een tijdelijke invulling voor
wie op dat moment geen foto kan nemen in de zaal. Niet de eindfoto, wel beter
dan een leeg vak. Het label "getekend door AI, geen foto van de uitvoering"
zegt precies dat, en de twee vakjes blijven vervangbaar door een echte foto
met één tik.

Dat bepaalt ook wat er níet meer moet gebeuren: nog een ronde prompts
bijschaven om een machine kloppend te krijgen. Het model is niet stuk en de
zin is niet fout - het weet gewoon niet hoe jouw toestel eruitziet.

## 148. Een tweede tekenaar naast de eerste, niet in de plaats ervan

Cloudflare draait FLUX.2 Klein 9B, en dat model tekent wel wat de zin zegt.
Met een echte sleutel naast elkaar gezet, dezelfde woorden, hetzelfde zaad:
schnell maakte er een optrekbeweging van, Klein zette bij de start de
ellebogen omhoog naast de oren met de onderarmen achter het hoofd, en bij het
eind de armen gestrekt. Dat is het paar waar zes rondes prompts bijschaven
niet in slaagden. Leonardo Lucid Origin tekent mooier maar deed dezelfde fout
als schnell: twee keer een gestrekte arm.

Wat het gratis maakt is ook anders van vorm. Hugging Face geeft een gratis
gebruiker $0,10 per maand - een stuk of dertig tekeningen, en dan is het op.
Cloudflare geeft 10.000 neurons per dag, die elke dag terugkomen: met Klein 9B
ongeveer zeven tekeningen per dag, drie oefeningen.

Het is een toevoeging geworden, geen vervanging: `image_provider` staat naast
`image_api_key` en null blijft Hugging Face, dus wie al een token had merkt
niets. In de instellingen kies je eerst wie er tekent en pas daarna wordt
gevraagd wat die dienst nodig heeft - één token bij de een, een token en een
account-ID bij de ander. Vragen voor de keuze gemaakt is naar het verkeerde
vragen.

Overstappen wist de sleutel van de vorige. Een token van Hugging Face is bij
Cloudflare niets waard, en laten staan zou de app laten tekenen met iets dat
daar geweigerd wordt - een mislukking die op niets lijkt behalve op een bug.

Technisch: FLUX.2 neemt geen JSON aan ("required properties at '/' are
'multipart'"), dus dat is een multipart-verzoek met velden; het antwoord zit
in `result.image` waar Hugging Face `data[0].b64_json` zegt. Allebei base64 in
het antwoord zelf, allebei in hetzelfde ene netwerkbestand, en de deurtest
kent nu twee tekenadressen.

## 149. Een opgebruikte dagportie is geen geweigerde sleutel

Bij een 429 zei de app "je tegoed is op" en zette ze de sleutel als geweigerd
weg. Allebei mis. Het gaat om de portie van die dag, die om middernacht UTC
terugkomt, en het token mankeerde niets - wie die melding leest gaat zoeken in
zijn instellingen naar een fout die er niet is, terwijl hij alleen moest
wachten.

402 blijft wat het was: tegoed dat echt op is. 429 zegt nu wat het is, per
dienst, en laat de sleutel met rust.

Hoe het gevonden is: het dagpotje van 10.000 neurons ging op aan het
vergelijken zelf - drie tekeningen van Leonardo (elk ~1.900) en vier van
Klein 9B (elk ~1.364) is al meer dan tienduizend. Dat is geen fout in de
schatting maar wel het bewijs dat 9B er zeven per dag zijn en niet honderd.

## 150. De dienst mag zelf zeggen wat er mis is

Cloudflare weigerde met code 4006 - "you have used up your daily free
allocation of 10.000 neurons" - terwijl het dashboard "0/10k gebruikt vandaag"
toonde. Die twee tellers lopen niet gelijk; bij Cloudflare zelf staan daar
meldingen over. Niets van dat alles kwam op het scherm: de app gokte "je
tegoed is op" omdat ze de vorm van dat antwoord niet kende, en dan sta je je
eigen instellingen te controleren terwijl er niets aan mankeert.

Twee dingen daarom veranderd. De foutlezer kent nu ook de lijstvorm met een
nummer erin, en dat nummer gaat mee naar het scherm - het scheidt "wacht tot
morgen" (4006, 3036) van "probeer het zo opnieuw" (3040). En de boodschap
wordt eerst ontdaan van wat er niet voor de lezer bij staat: het label
"AiError:" dat er tweemaal voor stond, en het tracenummer erachter.

Wat overeind blijft: wat de dienst zegt is waar, ook als het dashboard iets
anders zegt. De app geeft het door in plaats van het te vervangen door een
gok.

## 151. Materiaal in de tekening is een keuze, geen aanname

Met Cloudflare erbij tekent het model de houdingen wel goed, en dan valt op
waar het nog misgaat: het materiaal. Een machine die het niet kent wordt er
een die niet bestaat, en de armen volgen dan die verzonnen machine in plaats
van de beweging.

Daar valt geen goed antwoord voor iedereen op te geven. Een tekening zonder
stang laat een deadlift op een rekoefening lijken; een tekening met een
verkeerde stang is gewoon fout. Dus is het een schakelaar geworden in
Instellingen - Afbeeldingen, niet een regel van ons.

Staat hij uit, dan wordt er niet alleen gezwegen over het materiaal: er staat
uitdrukkelijk bij dat er geen is ("No gym equipment, no weights, no machine,
empty hands"). Zwijgen is niet genoeg - gevraagd om een triceps extension
pakt het model uit zichzelf een stang, en dat is precies hoe die optrekbeweging
ontstond.

De schakelaar geldt overal waar getekend wordt: in het sjabloon van de app, in
een zin die jij zelf typt, en in de zinnen die de coach schrijft - die krijgt
er een regel bij zodat zijn zin niet vecht met de staart die erachter hangt.
Uit twee helften van één prompt die elkaar tegenspreken komt een warboel.

Standaard staat hij aan, want dat is wat elke tekening tot nu toe probeerde.

## 152. Een RPE die opgeslagen wordt maar nergens te zien is

RPE per set bestond al: een kolom in `workout_sets`, een vak op het toetsenpaneel,
en een schakelaar "RPE bijhouden" in de workout-instellingen die standaard uit
staat. Dat laatste is nog altijd juist - het is een extra getal bij elke set en
niet iedereen wil elke set een cijfer geven.

Wat niet klopte: als je hem aanzet en je scoort je sets, staat dat cijfer
daarna nergens waar je terugkijkt. Het detailscherm van een oefening en dat van
een workout tonen per set alleen gewicht, reps, tijd of afstand. De ene
aantekening die zegt of die 100 kg × 5 een opwarmer of je laatste rep was,
zat in de database en nergens anders.

`setSummary` schrijft de RPE er nu achter zoals ze uitgesproken wordt:
100 kg × 5 @8. Dat is één regel per set in beide terugkijkschermen en in de
tekst die je deelt. Een set zonder getallen maar mét een RPE toont "@9" in
plaats van een streepje: dat je hem zwaar vond is ook iets.

Niet gedaan: de kolom "vorige" tijdens een workout. Daar past het niet zonder
de rest af te kappen, en een afgekapt gewicht is erger dan een ontbrekende RPE.

## 153. Vermoeidheid van gisteren verdwijnt niet omdat je vandaag weer traint

De schatting keek per spier alleen naar de laatste sessie. Train je maandag en
woensdag benen, dan was maandag op woensdag nog niet verwerkt - er stond nog
een dag open - en de schatting van woensdag wist daar niets van. Ze rekende
alsof je fris begon.

Nu wordt elke sessie van die spier op volgorde berekend, en neemt elke sessie
mee wat de vorige nog niet af had: de helft van wat er openstond
(`kCarryoverShare`). Niet het geheel, want twee herstelperiodes die elkaar
overlappen lopen deels samen op; niet niets, want dat was de fout. De helft is
een beginpunt, geen meting.

Het plafond van 96 uur blijft staan. Drie zware dagen na elkaar mogen de
schatting rekken, niet laten weglopen. Wat er door de opstapeling bijkwam
staat als `carryover` bij de schatting, zodat het scherm kan zeggen waarom het
langer duurt.

## 154. Het herstelscherm, en het enige wat de app echt meet

Alles in de herstelschatting was afgeleid: volume, RPE, falen, een nieuwe
oefening. Allemaal redenen om spierpijn te verwachten, niets over of die er
ook was. Het herstelscherm vraagt het: per spiergroep die je de laatste vier
dagen trainde drie knoppen, Fris, Stijf en Pijnlijk. Eén antwoord per spier
per dag; een tweede antwoord die dag vervangt het eerste, nog eens tikken
neemt het terug.

Een antwoord gaat voor op de rekensom, in beide richtingen. Pijnlijk houdt de
spier nog minstens 24 uur tegen, stijf 12, wat de tabel ook zei. Fris zet ze
op klaar - maar pas een dag na de sessie, want iedereen voelt zich fris op
de avond zelf en spierpijn komt meestal de dag erna. Een antwoord mag
buiten de 24-96 uur van de rekensom vallen: dat is een grens voor
rekenwerk, niet voor wat je zelf voelt.

En de app leert eruit. Elk antwoord wordt naast de voorspelling gelegd van de
sessie ervoor, en alleen gelezen in de richting waarin het iets kan zeggen:
na het voorspelde moment bevestigt fris, en zeggen stijf of pijnlijk dat het
te kort was; ervoor zeggen stijf of pijnlijk niets (dat verwachtte de tabel
al) en zegt fris dat je sneller was - weer pas na een dag. Het midden van de
laatste acht antwoorden wordt een factor per spier, tussen 0,75 en 1,5, en
pas vanaf drie antwoorden. Eén slechte nacht mag niet herschrijven hoe de app
naar je benen kijkt.

Waarom het een eigen scherm is en geen instelling: je beantwoordt het naast
de schatting die het verandert. Het opent vanaf het blok op het startscherm
(beide maten) en vanaf een rij in Voortgang, en staat daarom op de wortel van
de router - vanuit twee takken pushen is precies hoe er ooit een wit scherm
ontstond. Een test via de echte router loopt beide wegen af.
