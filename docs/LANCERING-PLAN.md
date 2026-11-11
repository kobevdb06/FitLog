# FitLog in de wereld brengen

Plan van 11 november 2026, na het uitbrengen van 1.70.2. Twee delen:
hoe de app bij mensen komt (verspreiding), en hoe ze hem vinden
(marketing). Niets hiervan is al gestart.

## Waar we staan

- FitLog 1.70.2 staat op GitHub, met een downloadpagina op
  <https://kobevdb06.github.io/FitLog/>. Installeren gaat via een APK
  ("onbekende bronnen"), zonder automatische updates.
- De app is gratis, zonder account, zonder advertenties, versleuteld, en
  alleen in het Nederlands. De code is open source (MIT).
- Er is geen analytics in de app, en dat blijft zo.

## Deel 1: verspreiding

### Keuze: Google Play als hoofdkanaal, GitHub ernaast

Waarom Play:
- Daar zoeken mensen apps. Updates gaan er vanzelf, zonder waarschuwingen
  van Play Protect of "onbekende bronnen".
- Google voert verificatie van ontwikkelaars in. Sinds 30 september 2026
  in enkele landen, in 2027 overal. Een app van een niet-geverifieerde
  ontwikkelaar installeren kan dan alleen nog met adb of met een extra,
  omslachtige installatiestap. Het gratis hobby-account geldt voor maximaal
  20 toestellen. Een Play-ontwikkelaarsaccount is meteen geverifieerd,
  ook voor de APK's op GitHub.

### De grootste drempel: de gesloten test

Een nieuw persoonlijk Play-account mag pas publiceren na een gesloten test
met **minstens 12 testers, 14 dagen aan één stuk**. Testers die stoppen
zetten de teller niet terug; de test pauzeren wel. Kijk de actuele regels
na op de hulppagina van Google (bronnen onderaan).

De testers komen uit de eigen kring: de gym, vrienden, familie. Zij zijn
meteen de eerste fans (zie deel 2).

### Wat specifiek is voor FitLog

- **Health Connect.** De app vraagt 10 rechten: lezen van slaap, HRV,
  rusthartslag, hartslag, zuurstof, stappen, gewicht en workouts, en
  schrijven van workouts. Google wil per recht een uitleg, en die
  beoordeling duurt even. Rechten die weinig opleveren, schrappen we
  eerst.
- **Gegevensveiligheid.** De maker verzamelt niets. Alleen de coach
  stuurt gegevens naar Google of OpenAI, en alleen met de eigen sleutel
  van de gebruiker. Dat moet zo in het formulier staan.
- **AI-regels.** Google vraagt een manier om een AI-antwoord te melden.
  FitLog heeft die al (*Melden*).
- **App-ondertekening (belangrijk).** Bij Play App Signing de bestaande
  sleutel uit `~/.fitlog/` aan Google geven (via de exporttool van Play),
  niet een nieuwe laten maken. Dan passen GitHub-installaties en
  Play-updates op elkaar. Met een nieuwe sleutel moet wie van GitHub
  overstapt de app eerst verwijderen, en verliest die zijn gegevens. Een
  bijkomend voordeel: Google bewaart dan ook een kopie van de sleutel.
- **App bundle.** Play wil een AAB in plaats van een APK
  (`flutter build appbundle`). Een kleine aanpassing.
- **De naam.** "FitLog" bestaat waarschijnlijk al op Play. Nakijken voor
  de winkelpagina gemaakt wordt; desnoods een onderscheidende naam of een
  ondertitel.
- **Handelaar of niet (Europese regels).** Voor een gratis app zonder
  inkomsten kan je je als "geen handelaar" opgeven. Dan komt je adres
  niet op de winkelpagina. Nakijken bij het aanmaken van het account.
- **Taal.** Alleen Nederlands, dus Nederland en België. Engels is een
  aparte, grote stap (zie onderaan).

### Alternatieven, en waarom niet als hoofdkanaal

- **Alleen GitHub:** prima voor een kleine kring, maar met de drempels
  hierboven, en vanaf 2027 de verificatie.
- **F-Droid:** kan pas als de QR-scanner (Google ML Kit) eruit gaat. F-Droid
  weigert gesloten onderdelen. De MIT-licentie is wel in orde.
- **Obtainium:** een gratis app die updates van GitHub-releases zelf
  ophaalt. Nu al te vermelden op de downloadpagina, voor wie Play niet wil.

### Wie doet wat

Kobe (persoonlijk, kan niemand anders):
- [ ] Play-ontwikkelaarsaccount aanmaken (eenmalig 25 dollar) en de
      identiteit laten verifiëren.
- [ ] 12 testers zoeken en uitnodigen.
- [ ] Twee kopieën van de sleutel maken (USB-stick, wachtwoordmanager).

Developer (klaarzetten, Kobe beslist en verstuurt):
- [ ] De build als app bundle (AAB).
- [ ] Nederlandse teksten voor de winkelpagina (kort en lang).
- [ ] Antwoorden voor het formulier Gegevensveiligheid.
- [ ] Uitleg per Health Connect-recht, en welke rechten eruit kunnen.
- [ ] Schermafbeeldingen van de emulator, met een korte zin erop.

## Deel 2: marketing

### Wie, en waarom FitLog

Voor Nederlandstaligen die krachttraining doen en geen account, abonnement
of advertenties willen. De belofte staat al op de site:
*"Je trainingslogboek. Op je toestel, en nergens anders."*
Daar vertrekt elke tekst, video of post van:
- gratis, geen account, geen advertenties;
- versleuteld, achter je pincode;
- in het Nederlands;
- een set in twee tikken.

### 1. De winkelpagina is de belangrijkste reclame

De meeste installaties komen via zoeken in Play.
- Een naam die je terugvindt.
- Een korte en een lange beschrijving met de woorden waarop mensen zoeken:
  krachttraining, gym, workout, logboek, trainingsschema.
- Zes of zeven schermafbeeldingen met een korte zin: een set loggen, je
  records, je voortgang, je schema met de coach, en "alles blijft op je
  gsm".
- Geen medische beloftes: het herstel is een schatting, en zo staat het
  er ook.

### 2. De eerste gebruikers: de 12 testers

- Na de lancering vragen om een eerlijke review. Reviews tillen de app in
  de zoekresultaten.
- De eigen gym: met toestemming een QR-code aan de balie, of via een
  personal trainer die het aan klanten aanraadt.

### 3. De lanceringsweek

- **Tweakers:** een topic in het forum voor Android-apps. Dat publiek
  waardeert "geen account, geen tracking, open source".
- **Reddit:** r/thenetherlands, r/belgium, en privacygemeenschappen zoals
  r/privacy en r/degoogle. Eerst de regels over zelfpromotie lezen, en
  altijd zeggen dat je de maker bent.
- **Korte video's:** schermopnames voor TikTok, Instagram of YouTube Shorts.
  "Een set in twee tikken", "je data blijft hier". Je hoeft er zelf niet
  op te staan.
- **Een of twee Nederlandstalige Android-sites**, zoals Android Planet, met
  een korte pitch en een persmapje op de site.

Kobe post en mailt zelf, onder eigen naam. Dat is geloofwaardiger.

### 4. Daarna: een vast ritme

- Om de twee à vier weken een update, met duidelijke "Nieuw in"-notities.
- Op elke review antwoorden, ook op de kritische.
- Een korte video per week of per twee weken, over één functie.

### 5. Meten zonder de belofte te breken

Geen analytics in de app. Play Console toont installaties, hoeveel
mensen blijven en beoordelingen; GitHub toont downloads per release. Dat
volstaat.

### Wat de developer klaarzet voor marketing

- [ ] Zinnen op de schermafbeeldingen.
- [ ] Schermopnames van de emulator voor video's (`adb screenrecord`).
- [ ] Concepten voor de posts op Tweakers en Reddit, en een pitchmail.
- [ ] Een perspagina op de site (`docs/`).

## Volgorde

1. Account en verificatie (Kobe). Intussen de AAB, de teksten, de
   schermafbeeldingen en de Health Connect-uitleg (developer).
2. Gesloten test: 12 testers, 14 dagen. Feedback verwerken.
3. Lancering in Nederland en België. Testers vragen om een review.
4. Lanceringsweek: Tweakers, Reddit, video's, een of twee sites.
5. Vast ritme. Na een paar maanden beslissen over Engels.

## Open beslissingen

- **De naam** op Play, als "FitLog" bezet is.
- **Welke Health Connect-rechten** blijven.
- **Engels:** de Nederlandstalige markt is een fijn begin, maar ook een
  plafond. Pas beslissen na een paar maanden in Nederland en België. Het
  is een flinke klus: alle teksten staan nu in het Nederlands in de code.

## Bronnen

Opgezocht op 11 november 2026. Regels veranderen; kijk ze na voor je
begint.

- [Android developer verification: rolling out to all developers (Android Developers Blog)](https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html)
- [Android developer verification (developer.android.com)](https://developer.android.com/blog/posts/android-developer-verification-rolling-out-to-all-developers-on-play-console-and-android-developer-console)
- [Engadget: Android will hide some app sideloading behind a new one-time security process](https://www.engadget.com/apps/android-will-hide-app-sideloading-behind-a-new-one-time-security-process-184651171.html)
- [Bayton: what developer verification means](https://bayton.org/blog/2025/08/google-play-developer-verification/)
- [Google Play Console Help: testing requirements for new personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Choicely: the Google Play 12 tester rule](https://www.choicely.com/blog/google-play-12-tester-rule)
