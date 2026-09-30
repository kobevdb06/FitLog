# Plan: een AI-coach voor iedereen in FitLog

*Opgesteld op 30 september 2026 en bijgewerkt met het onderzoek naar concurrentie,
prijzen en Health Connect. Bedragen, regels en voorwaarden veranderen: kijk ze na voor
je een stap zet. Waar dit plan over belastingen en recht gaat, is het een oriëntatie en
geen advies. Laat die delen nakijken door een boekhouder (en voor de privacy eventueel
een jurist).*

---

## 0. In het kort

- **Het doel:** elke gebruiker kan de coach gebruiken zonder zelf een sleutel aan te
  maken. Een klein deel gratis, de rest betaald.
- **De grootste les uit het onderzoek:** mensen betalen niet voor een chatvenster.
  Google verkoopt sinds mei 2026 zelf een AI-coach voor $9,99 per maand, en Hevy en
  Strong geven voor $3 à $5 een hele app. **FitLog moet verkopen wat die niet doen:
  coaching die krachttraining in detail kent, zonder dat je privacy inlevert.**
- **Wat we daarom verkopen:** vier functies die resultaat opleveren in plaats van een
  chat: een **weekoverzicht**, een **schema dat zich aanpast**, een **check voor je
  training** en **stilstand herkennen met uitleg** (§3).
- **Wat gratis blijft:** de hele app, en ook de koppeling met **Health Connect** (slaap,
  hartslag, HRV, gewicht, loopsessies van je horloge). Die draait op de gsm zelf en kost
  niets (§4).
- **Hoe het technisch werkt:** de app stuurt de vraag naar een klein **tussenstation**
  (een Cloudflare Worker) dat jouw sleutel bewaart en de vraag doorgeeft aan **Gemini,
  betaalde laag**. Het tussenstation bewaart niets (§5).
- **Geen eigen model trainen.** Een bestaand model met goede tools en een goede opdracht
  doet het beter en kost bijna niets.
- **Kostprijs:** ongeveer **0,1 tot 0,4 cent per vraag**. De vier functies samen kosten
  minder dan **€0,10 per abonnee per maand**, omdat de app het rekenwerk zelf doet en de
  AI alleen uitlegt.
- **Verkopen:** eerst **vragenpakketten** (eenmalig, bijvoorbeeld €1,99 voor 100),
  omdat een onbekende maker moeilijk meteen een abonnement verkoopt. Later eventueel een
  abonnement: **€2,99 voor 300 vragen per maand** of **€4,99 voor 500**.
- **Wanneer het winst maakt:** hangt vooral af van de verhouding tussen betalers en gratis
  gebruikers. Neemt minder dan **1 op 22** (4,6%) iets af, dan verlies je geld, hoeveel
  gebruikers je ook hebt. Met een lage gratis limiet haal je de opstartkosten terug met
  ongeveer **20 betalers** (§11).
- **Wat je moet regelen:** een betaalaccount bij Google AI Studio; een
  ontwikkelaarsaccount bij Google Play ($25); vóór de eerste betaalde verkoop een
  inschrijving als zelfstandige (KBO, btw, sociaal verzekeringsfonds); een
  privacyverklaring en een toestemmingsscherm.
- **Wat er verandert aan de belofte van de app:** van *"geen server, geen account"*
  naar *"geen account, en een tussenstation dat niets bewaart"*. De coach blijft
  uitgeschakeld tot de gebruiker hem zelf aanzet.
- **Volgorde:** Health Connect (gratis) → Google Play → gedeelde coach met de vier
  functies → vragenpakketten → eventueel abonnement (§12).

---

## 1. Waarom zou iemand betalen?

### 1.1 Wat er al bestaat

| App | Prijs | Wat je krijgt |
|---|---|---|
| **Google Health Premium** | $9,99/maand of $99,99/jaar | Een Gemini-coach met de gegevens van je horloge: slaap, herstel, aangepaste plannen. Sinds mei 2026. |
| **Fitbod** | ~$7,99/maand of $95,99/jaar | Trainingen die zich automatisch aanpassen aan je herstel |
| **Strong Pro** | $4,99/maand, $29,99/jaar of $99,99 eenmalig | De volledige app zonder beperkingen |
| **Hevy Pro** | $2,99/maand, $23,99/jaar of $74,99 eenmalig | De volledige app zonder beperkingen |

Wie €3 à €5 uitgeeft, vergelijkt met Hevy en Strong: daar krijgt hij een hele app.
Wie een AI-coach wil, kiest Google: bekende naam, gegevens van zijn horloge. **Een losse
chat van een onbekende maker verliest van allebei.** Slimme gebruikers maken bovendien
zelf een gratis Gemini-sleutel aan, want dat kan nu al in FitLog.

### 1.2 Waar FitLog sterker is

- **Krachttraining in detail.** De coach kent elke set, je RPE, je records en het herstel
  per spiergroep. Google's coach denkt vanuit je horloge: stappen, hartslag, slaap.
  Krachttraining is daar bijzaak.
- **Privacy.** Geen account, alles versleuteld op je gsm, open broncode op GitHub. Dat
  kan geen van de concurrenten zeggen.
- **Prijs.** Onder Google, in de buurt van Hevy.

### 1.3 Waarvoor mensen wél betalen

Mensen betalen voor **resultaat**: sterker worden zonder te gissen, weten wanneer ze
moeten doorduwen of rusten. Daarom verkoopt FitLog geen chat, maar vier functies die dat
opleveren (§3). De chat blijft erbij, als manier om door te vragen.

### 1.4 Vertrouwen als onbekende maker

- **Wees open over het waarom.** *"De app is gratis en blijft gratis. Je betaalt alleen
  wat de AI ons kost."* Samen met de open broncode is dat geloofwaardiger dan een groot
  merk.
- **Laag instappen.** Eerst **vragenpakketten** in plaats van een abonnement (§11.5). Geen
  "levenslang" voor de AI: elke vraag blijft geld kosten, dus eenmalig betalen voor
  onbeperkt gebruik gaat niet.
- **Eerst proeven.** Een paar gratis vragen per maand en een gratis maandoverzicht, zodat
  mensen de waarde zien voor ze betalen.
- **De eigen sleutel blijft gratis.** Dat toont dat je niemand opsluit.

---

## 2. Wat we bouwen, en wat niet

**Wel:**

- **Health Connect**, gratis voor iedereen (§4).
- Een **gedeelde coach** die iedereen kan gebruiken, via jouw Gemini-sleutel die veilig
  op het tussenstation staat.
- Vier **proactieve functies** (§3).
- **Limieten**: een klein gratis deel, een limiet per maand voor betalers, en een harde
  maandlimiet op jouw kosten.
- **Vragenpakketten**, later eventueel een abonnement, via Google Play.
- De huidige optie **"eigen sleutel"** blijft bestaan en blijft gratis. Wie zijn eigen
  Gemini-sleutel gebruikt, gaat rechtstreeks naar Google zoals nu, en krijgt ook de vier
  functies.

**Niet:**

- **Geen eigen model trainen.** Een model vanaf nul trainen kost miljoenen. Bijtrainen
  (fine-tuning) is niet nodig: de kracht van de coach zit in zijn tools en zijn opdracht.
- **Geen accounts, geen wachtwoorden, geen e-mailadressen.**
- **Geen opslag van logboeken of gesprekken op een server.** Gesprekken blijven op de gsm.
- **Geen levenslange aankoop voor de AI** (§1.4).

---

## 3. De betaalde coach: vier functies

**Het principe: de app rekent, de AI legt uit.** Wat berekend kan worden, doet de app
zelf op de gsm: gratis, snel en zonder dat er gegevens vertrekken. De AI krijgt alleen
een **samenvatting in cijfers** en maakt daar begrijpelijke uitleg en advies van. Dat houdt
de kosten laag en stuurt zo weinig mogelijk gegevens weg.

### 3.1 Weekoverzicht

- **Wat:** elke zondagavond (instelbaar) een overzicht, zonder dat de gebruiker iets hoeft
  te vragen: wat ging goed, welke oefening staat stil, hoe waren slaap en herstel, en
  **2 à 3 concrete aanpassingen voor volgende week**.
- **App doet:** het volume per spiergroep, records, stilstand (§3.4), gemiddelde slaap en
  HRV van de week (via Health Connect, §4) en aantal trainingen berekenen.
- **AI doet:** er een leesbaar overzicht met advies van maken.
- **Kost:** één aanroep per week, ~$0,005 → **~€0,03 per maand**.
- **Waarom het verkoopt:** de gebruiker voelt de waarde zonder iets te doen. Dit is de
  etalage van de betaalde coach.

### 3.2 Een schema dat zich aanpast

- **Wat:** de coach maakt een plan van 4 à 6 weken (welke oefeningen, sets, herhalingen,
  gewichten, met een rustweek) en stuurt het **elke week bij** op basis van wat je echt
  deed en hoe je herstelde. Zoals Fitbod, maar met uitleg waarom.
- **App doet:** de bestaande routines en voorstellen (de coach kan nu al oefeningen en
  routines voorstellen), je prestaties tegenover het plan vergelijken.
- **AI doet:** het plan opstellen en de wekelijkse aanpassing uitleggen. Elke wijziging
  blijft een **voorstel** dat de gebruiker zelf aanvaardt, zoals nu.
- **Kost:** één aanroep bij de start, één per week → **~€0,03 per maand**.

### 3.3 Check voor je training

- **Wat:** als je een workout start: *"Je benen zijn nog niet hersteld en je sliep 5 uur.
  Vandaag liever bovenlichaam, of houd het licht."*
- **App doet:** herstel per spiergroep (bestaat al), slaap van vannacht en HRV tegenover
  je eigen gemiddelde (Health Connect, §4).
- **AI doet:** één korte aanbeveling. Bij een duidelijk "alles in orde" hoeft er geen AI
  aan te pas te komen: dan toont de app gewoon groen.
- **Kost:** een kleine aanroep per training, ~$0,0013 → **~€0,02 per maand** bij 12
  trainingen.

### 3.4 Stilstand herkennen, met uitleg

- **Wat:** *"Je bench press staat al 4 weken op 80 kg × 5. Je sets zitten steeds op RPE 9
  à 10, en je traint borst maar één keer per week. Probeer…"*
- **App doet:** stilstand opsporen. Dat is rekenwerk op het logboek (geschatte 1RM die
  een aantal weken niet stijgt) en is **gratis voor iedereen**: de app toont het gewoon.
- **AI doet:** uitleggen **waarom** het vastzit en wat je eraan kan doen. Dat is het
  betaalde deel.
- **Kost:** alleen als de gebruiker op "waarom?" tikt; telt als een vraag.

### 3.5 Wat gratis is en wat betaald

| | Gratis | Met een pakket | Abonnement |
|---|---|---|---|
| De hele app, Health Connect, herstel | ✔ | ✔ | ✔ |
| Stilstand **zien** | ✔ | ✔ | ✔ |
| Vragen aan de coach | 20 per maand | uit je tegoed | 300 of 500 per maand |
| Maandoverzicht | ✔ (1 per maand) | ✔ | ✔ |
| Weekoverzicht | eerste gratis | 1 tegoed per overzicht | inbegrepen |
| Schema dat zich aanpast | – | 1 tegoed per week | inbegrepen |
| Check voor je training | – | 1 tegoed per check | inbegrepen |
| Stilstand **uitgelegd** | – | 1 tegoed | inbegrepen |
| Foto meesturen | – | ✔ | ✔ |
| Model | Gemini 2.5 Flash-Lite | Gemini 3.1 Flash-Lite | Gemini 3.1 Flash-Lite |

Bij de optie **eigen sleutel** krijgt de gebruiker alles gratis: hij betaalt Google zelf.

---

## 4. Health Connect: de gratis basis

### 4.1 Wat het is

**Health Connect** is het centrale punt op Android waar gezondheids- en fitnessapps hun
gegevens delen: Samsung Health, Google Health, veel horloges en weegschalen. Het zit
ingebouwd in Android 14 en hoger; op oudere toestellen is het een aparte app. Welke app
precies wat deelt, verschilt per app.

**Het draait volledig op de gsm.** Lezen uit Health Connect vraagt geen internet en geen
server. Het past dus perfect bij "offline eerst", en kost niets.

### 4.2 Wat FitLog eruit haalt

| Gegeven | Wat het oplevert |
|---|---|
| **Slaap, met fasen** | Slaap komt automatisch binnen in plaats van ze zelf in te typen. De handmatige invoer blijft als terugval. |
| **Rusthartslag en HRV** | De beste meetbare aanwijzing voor herstel die er is. Gebruikt tegenover je **eigen** gemiddelde, als extra signaal in de herstelschatting en de check voor je training. |
| **Gewicht** | Van een slimme weegschaal, voor je lichaamsgewicht en voor lichaamsgewichtoefeningen. |
| **Loop- en fietssessies** | Tellen mee voor het herstel van je benen. Dat lost een gat op dat we eerder vonden: een loop na een beendag telde niet mee. |
| **Stappen** | Als context in het weekoverzicht. |

**Terugschrijven:** FitLog kan je krachttrainingen ook **naar** Health Connect schrijven,
zodat ze in Google Health of Samsung Health verschijnen.

### 4.3 Waarom gratis

1. **Het kost je niets**: alles gebeurt op de gsm.
2. **Het maakt de hele app beter**, ook voor wie nooit betaalt. Dat trekt gebruikers aan,
   en zonder gebruikers valt er niets te verkopen.
3. **Het maakt de coach vanzelf beter**, of die nu betaald is of met een eigen sleutel
   werkt.

### 4.4 Wat erbij komt kijken

- **Toestemming per gegevenstype.** De gebruiker kiest zelf welke gegevens FitLog mag
  lezen, en kan dat altijd intrekken in de instellingen van Health Connect.
- **Google Play:** voor elk gezondheidsgegeven dat je leest, vraagt Play Console een
  verklaring waarom. Samen met de Health apps declaration en een privacyverklaring.
- **Technisch:** het Flutter-pakket `health` ondersteunt Health Connect. Per gegevenstype
  een `READ_...`- of `WRITE_...`-toestemming in het manifest.
- **Privacy:** de gegevens blijven op de gsm. Ze gaan alleen naar een AI als de gebruiker
  de coach gebruikt, en dan alleen als samenvatting (§3).
- **Onafhankelijk van de coach.** Health Connect kan als eerste gebouwd worden, zonder dat
  er iets van de AI-coach bestaat.

---

## 5. Hoe het technisch werkt

```
 ┌──────────────┐    HTTPS     ┌──────────────────────┐    HTTPS    ┌───────────────────┐
 │  FitLog-app  │ ───────────► │    Tussenstation     │ ──────────► │  Gemini API       │
 │  (gsm)       │ ◄─────────── │ (Cloudflare Worker)  │ ◄────────── │  (betaalde laag)  │
 └──────────────┘              └──────────────────────┘             └───────────────────┘
        │                                 │
        │ Play Integrity-bewijs           │ controleert bewijs, tegoed en aankopen
        ▼                                 ▼
 ┌─────────────────────────────────────────────────────┐
 │  Google Play (installatie, Integrity, aankopen)     │
 └─────────────────────────────────────────────────────┘

 Health Connect staat hier niet in: dat blijft volledig op de gsm.
```

### 5.1 Waarom een tussenstation?

Een sleutel die in de app zit, is **niet geheim**. Iedereen kan een APK uit elkaar halen en
de sleutel eruit halen, en dan betaal jij voor zijn gebruik. Het tussenstation houdt de
sleutel bij zich en stuurt alleen door.

### 5.2 Wat het tussenstation doet

1. **Controleert** of de vraag van een echte FitLog-installatie komt (Play Integrity, §5.4).
2. **Telt** per installatie: gratis vragen per maand, pakkettegoed, of de abonneelimiet.
3. **Bewaakt jouw maandlimiet.** Is die bereikt, dan stopt de gedeelde coach tot de
   volgende maand. Misbruik kan je dus nooit meer kosten dan die limiet.
4. **Geeft de vraag door** aan Gemini, met jouw sleutel, en kiest het model (§3.5).
5. **Controleert aankopen** bij Google Play (§7.6).

### 5.3 Wat het tussenstation nooit doet

- Geen vragen, antwoorden of logboekgegevens opslaan.
- Geen inhoud loggen. Alleen tellers: welke installatie hoeveel verbruikte, en het
  tegoed.
- Geen namen, e-mailadressen of telefoonnummers ontvangen.

**Waarom Cloudflare Workers?** Je hebt al een Cloudflare-account voor de tekeningen. Het
gratis plan geeft 100.000 verzoeken per dag. Het betaalde plan kost $5 per maand als het
ooit nodig is.

### 5.4 Gebruikers herkennen zonder accounts

- **Installatienummer:** bij de eerste keer maakt de app een willekeurig nummer aan. Dat
  zegt niets over wie je bent, en is genoeg om per toestel te tellen.
- **Play Integrity:** Google geeft de app een bewijs dat het een echte, onaangepaste
  FitLog-installatie is. Het tussenstation laat dat bewijs controleren.
  - **Dit werkt alleen voor installaties via Google Play.** Een APK van GitHub krijgt het
    oordeel "niet via Play geïnstalleerd" en kan dus geen gedeelde coach gebruiken.
    GitHub-gebruikers houden de optie "eigen sleutel".
- **Tegoed en aankopen** zijn gekoppeld aan het Google-account van de aankoop (via Google
  Play), niet aan een eigen account. "Aankopen herstellen" op een nieuwe gsm werkt daardoor
  zonder dat FitLog iets van de gebruiker weet.

### 5.5 Limieten

| | Gratis | Pakket | Abonnement €2,99 | Abonnement €4,99 |
|---|---|---|---|---|
| Vragen | 20 per maand | zoveel als je tegoed | **300 per maand** | **500 per maand** |
| Proactieve functies | maandoverzicht | 1 tegoed per gebruik | inbegrepen, tellen niet mee | inbegrepen, tellen niet mee |

**Waarom per maand en niet per dag:** soepeler voor de gebruiker (een drukke dag kan,
zolang het over de maand klopt) en voorspelbaarder voor jou (het grootste bedrag dat één
abonnee je kan kosten, ligt vast). **Waarom niet meer:** zie §11.3.

**Jouw maandlimiet** voor de gedeelde coach: voorstel **€10**, in te stellen op het
tussenstation, bovenop de limiet van Google zelf (§6.5).

---

## 6. Google AI Studio en de Gemini API: alles over betalen

### 6.1 Waarom het de betaalde laag moet zijn

De voorwaarden van de Gemini API zeggen letterlijk:

> *"You may use only Paid Services when making API Clients available to users in the
> European Economic Area, Switzerland, or the United Kingdom."*

De gratis laag mag je dus **niet** gebruiken om de coach aan Belgische en Europese
gebruikers aan te bieden. Daar komt nog bij: op de gratis laag mag Google je vragen
gebruiken om zijn producten te verbeteren, en mogen menselijke beoordelaars ze lezen.
Op de betaalde laag gebeurt dat niet.

*Nu mag het wel, omdat elke gebruiker zijn eigen sleutel meebrengt: dan gebruikt de
gebruiker zelf Google, niet jij.*

### 6.2 Het betaalaccount: welk type?

Betalen voor de Gemini API loopt via een **Cloud Billing-account** van Google Cloud. Je
koppelt dat vanuit AI Studio aan je project.

**Belangrijk: het accounttype kan je achteraf niet meer veranderen.**

| Type | Wanneer | Btw op de factuur van Google |
|---|---|---|
| **Business** (standaard in de EU) | Je hebt een ondernemingsnummer (KBO) met btw-nummer | **Geen btw** op de factuur. De btw wordt *verlegd*: jij moet de Belgische btw zelf aangeven (§8.3). |
| **Individual Entrepreneur** | Je werkt als eenmanszaak, eventueel nog zonder btw-nummer | Google rekent **21% Belgische btw** aan |

**Advies:** maak het betaalaccount voor de echte coach pas aan **nadat** je weet hoe je de
onderneming opzet (fase 4), of kies bewust met je boekhouder. Wil je eerder al testen,
gebruik dan een apart testproject met een apart betaalaccount.

### 6.3 Betaalmiddelen

- **Kredietkaart of debetkaart.**
- **Domiciliëring (SEPA)**: je bankrekening met IBAN en BIC.
- Bankoverschrijvingen kunnen enkele dagen duren voor ze verwerkt zijn.

### 6.4 Vooraf betalen of achteraf betalen?

| | **Prepay** (vooraf) | **Postpay** (achteraf) |
|---|---|---|
| Hoe | Je koopt tegoed, vanaf $5 | Google rekent aan het einde van de maand af, of eerder zodra je de limiet van je niveau bereikt |
| Voordeel | Je kan nooit meer uitgeven dan je tegoed | Geen tegoed dat vervalt |
| Nadeel | Tegoed **vervalt na 1 jaar** en wordt **niet terugbetaald** (behalve bij overstappen naar postpay) | Een fout of misbruik kost tot de limiet van je niveau |

**Advies:** begin met **prepay en een klein bedrag ($10 à $20)**. Dat is een tweede
vangnet naast de maandlimiet van het tussenstation.

### 6.5 Niveaus (tiers) en de limiet van Google

| Niveau | Hoe je het bereikt | Maandlimiet van Google |
|---|---|---|
| Gratis | Actief project | – |
| **Tier 1** | Betaalaccount gekoppeld | **$250** |
| Tier 2 | $100 betaald en 3 dagen sinds de eerste betaling | $2.000 |
| Tier 3 | $1.000 betaald en 30 dagen sinds de eerste betaling | $20.000 – $100.000+ |

Met weinig gebruikers blijf je in **Tier 1**. Een hoger niveau geeft ook ruimere
snelheidslimieten (vragen per minuut).

### 6.6 Het gratis Google Cloud-tegoed geldt hier niet

Nieuwe Google Cloud-klanten krijgen soms welkomsttegoed of proeftegoed ($300). Dat mag
**niet** gebruikt worden voor de Gemini API of AI Studio.

### 6.7 Wat Google met de gegevens doet (betaalde laag)

- **Niet** gebruikt om modellen te trainen.
- Wel **tijdelijk bewaard om misbruik op te sporen**, standaard tot 55 dagen. In AI Studio
  kan je die bewaartermijn per project instellen op **7, 14, 28 of 55 dagen**.
  **Zet ze op 7 dagen.**
- **Zero Data Retention** (helemaal niets bewaren) kan je aanvragen bij Google.
  - Zoeken met Google (Search grounding) bewaart altijd 30 dagen. De coach gebruikt dat
    niet, en dat moet zo blijven.
- **Waar de gegevens verwerkt worden:** de Gemini API via AI Studio belooft geen verwerking
  binnen de EU. Wil je later zekerheid dat alles in de EU blijft, dan is **Vertex AI**
  (Google Cloud) met een Europese regio de volgende stap. Dat is meer werk en valt
  buiten dit plan.

### 6.8 Welk model, en wat het kost

Prijzen per miljoen tokens, betaalde laag (standaardtarief):

| Model | Invoer | Uitvoer | Per coachvraag* | Per 1.000 vragen |
|---|---|---|---|---|
| Gemini 2.5 Flash-Lite | $0,10 | $0,40 | ~$0,001 | ~$1 |
| Gemini 3.1 Flash-Lite | $0,25 | $1,50 | ~$0,003 | ~$3 |
| Gemini 3.5 Flash-Lite | $0,30 | $2,50 | ~$0,004 | ~$4 |

\* Een vraag is gemiddeld ongeveer 3 rondes van zo'n 3.000 tokens invoer, plus zo'n 500
tokens antwoord in totaal. De opdracht en de tools zijn bij elke ronde dezelfde; Gemini
kan dat herhaalde begin tijdelijk bewaren, wat de echte prijs wat lager maakt. Een vraag
met een foto of in een heel lang gesprek kost meer: de foto en de eerdere berichten gaan
telkens mee.

### 6.9 Stap voor stap instellen

1. Ga naar **AI Studio → Projects**. Maak een nieuw project aan: **"FitLog Coach"**, apart
   van je persoonlijke project.
2. Klik **Set up billing** bij dat project.
3. Maak een **Cloud Billing-account** aan. Kies het accounttype bewust (§6.2): dat kan
   later niet meer.
4. Geef een betaalmiddel op (§6.3).
5. Kies **Prepay** en koop $10 à $20 tegoed (§6.4).
6. Stel de **bewaartermijn van de logboeken** in op **7 dagen** (§6.7).
7. Maak een **API-sleutel** aan in dit project.
8. **Beperk de sleutel** tot de Gemini API (*Generative Language API*) in Google Cloud
   Console → *APIs & Services → Credentials*.
9. Zet de sleutel **alleen als geheim** in de Cloudflare Worker (`wrangler secret put`).
   Nooit in de code, nooit in de app, nooit in git.
10. Stel een **budgetwaarschuwing** in bij Google Cloud Billing, bijvoorbeeld bij 50% en
    90% van je maandlimiet.
11. Zet een herinnering om de sleutel **elk jaar te vervangen**, en meteen als je vermoedt
    dat hij uitgelekt is.

---

## 7. Google Play en Google Play Billing

### 7.1 Waarom Google Play?

- **Gebruikers.** Zonder gebruikers valt er niets te verkopen, en de Play Store is waar
  Android-gebruikers apps zoeken.
- **Play Integrity** (§5.4) werkt alleen voor installaties via Google Play.
- **Aankopen** van digitale functies moeten in een Play-app via Google Play Billing.
- **Health Connect** is het makkelijkst te gebruiken in een app op Google Play, die daar
  zijn gezondheidstoestemmingen verklaart.
- **Ontwikkelaarsverificatie komt eraan.** Sinds 30 september 2026 moeten apps van buiten
  Google Play in Brazilië, Indonesië, Singapore en Thailand van een geverifieerde
  ontwikkelaar komen. Google breidt dat vanaf 2027 wereldwijd uit. Ook voor de
  GitHub-versie moet je je dus binnenkort laten verifiëren (via de *Android Developer
  Console*).

### 7.2 Ontwikkelaarsaccount

- **Kosten:** eenmalig **$25**.
- **Type:**
  - **Persoonlijk account:** het eenvoudigst. Identiteitscontrole met je
    identiteitskaart.
  - **Organisatieaccount:** voor een vennootschap. Vraagt een D-U-N-S-nummer.
- **Testverplichting voor nieuwe persoonlijke accounts** (aangemaakt na 13 november 2023):
  voor je de app publiek mag zetten, moet je een **gesloten test** draaien met **minstens
  12 testers**, **14 dagen onafgebroken**.
  - Een tester telt pas als hij de uitnodiging aanvaardde **én** de app installeerde met
    het juiste Google-account.
  - Daarna vraag je *production access* aan. Google beoordeelt dat meestal binnen 7 dagen.
  - **Begin dus op tijd met testers zoeken:** vrienden, familie, sportmaten.

### 7.3 Betaalprofiel en uitbetalingen

- Je maakt in Play Console een **betaalprofiel (payments profile)** aan en koppelt en
  verifieert een bankrekening.
- Google betaalt **elke maand, vanaf de 15e**, uit voor de verkopen van de vorige maand.
- Er is een **minimumbedrag** voor een uitbetaling. Tot dat bereikt is, schuift het saldo
  door naar de volgende maand.
- Je ontvangt maandelijks een **overzicht** van Google. Dat is het bewijsstuk voor je
  boekhouding.

### 7.4 Wat Google inhoudt (EER, vanaf 30 juni 2026)

| Soort aankoop | Kost |
|---|---|
| **Abonnement** (automatisch verlengd) | **10% servicekost + 5% betaalkost = 15%** |
| **Eenmalige aankoop** (zoals een vragenpakket), nieuwe installatie | **10% + 5% = 15%**; in sommige gevallen 15% + 5% = 20% |
| Eenmalige aankoop, installatie van vóór 30 juni 2026 | 20% à 25% + 5% |

"Nieuwe installatie" betekent: de gebruiker installeerde of werkte de app voor het eerst
bij **via Google Play op of na 30 juni 2026**. FitLog staat nog niet op Google Play, dus
**al zijn Play-gebruikers zijn nieuwe installaties**. De tabel van Google is niet overal
eenduidig: dit plan rekent voor pakketten voorzichtig met **20%**. Kijk de actuele tabel
na voor je prijzen vastlegt.

**Rekenvoorbeeld abonnement van €2,99 per maand** (prijs voor de gebruiker, btw inbegrepen):

| | Bedrag |
|---|---|
| Prijs voor de gebruiker | €2,99 |
| − 21% Belgische btw (Google draagt die af) | −€0,52 |
| = Prijs zonder btw | €2,47 |
| − 15% Google | −€0,37 |
| **= Wat jij ontvangt** | **€2,10** |

Bij **€4,99** ontvang je **€3,51**. Voor een **pakket van €1,99** ontvang je **€1,32** (met
20%) of €1,40 (met 15%).

### 7.5 Btw bij verkopen via Google Play

- In de EU is **Google verantwoordelijk** voor het berekenen, aanrekenen en afdragen van
  de btw op aankopen via Google Play.
- In België toont Google Play prijzen **inclusief btw**. Je stelt de prijs in zoals de
  klant hem betaalt.
- **Jij rekent zelf geen btw aan de gebruiker aan.** Voor de btw verkoop jij aan Google
  (Google Ireland), niet aan de gebruiker. Meer daarover in §8.3.

### 7.6 Pakketten en abonnementen instellen

**Vragenpakketten** (eerst):

1. Play Console → **Monetize → Products → In-app products**.
2. Maak **verbruikbare producten** aan, bijvoorbeeld `vragen_100` (€1,99) en
   `vragen_300` (€4,99).
3. Na een aankoop stuurt de app het **aankoopbewijs** naar het tussenstation. Dat
   controleert het bij Google, schrijft het tegoed bij, en **verbruikt** (consume) de
   aankoop zodat hij opnieuw gekocht kan worden.
4. **Tegoed vervalt niet.** Dat is eerlijk tegenover de gebruiker, en je kosten volgen pas
   als het tegoed gebruikt wordt.

**Abonnement** (later, als pakketten verkopen):

1. **Monetize → Products → Subscriptions → Create subscription**, bijvoorbeeld
   `coach_plus`.
2. Een **basisplan**: *maandelijks, automatisch verlengd*. Eventueel ook jaarlijks, met
   korting.
3. Eventueel een **aanbieding**: bijvoorbeeld 7 dagen gratis proberen.
4. Zet de **respijtperiode** (grace period) aan. Mislukt een betaling, dan houdt de
   gebruiker nog enkele dagen toegang terwijl Google opnieuw probeert.

**Voor allebei:**

- In de app: het Flutter-pakket **`in_app_purchase`**, een scherm met wat je krijgt en
  de prijs, en **"Aankopen herstellen"**.
- Op het tussenstation: controle via de **Google Play Developer API**, met een eigen
  servicesleutel.
- **Een aankoop moet binnen 3 dagen bevestigd (acknowledged) of verbruikt worden.** Anders
  betaalt Google de klant automatisch terug.
- Later, optioneel: **Real-time Developer Notifications** (via Google Cloud Pub/Sub), zodat
  opzeggingen, verlengingen en terugbetalingen meteen doorkomen.
- **Opzeggen en terugbetalen** gaan via Google Play zelf.

### 7.7 Regels van Google Play waar je aan moet voldoen

| Regel | Wat je moet doen |
|---|---|
| **Privacyverklaring** | Een openbare webpagina met je privacyverklaring. Die kan op de FitLog-website. De link komt in Play Console. |
| **Data safety** (gegevensveiligheid) | Een formulier in Play Console: welke gegevens de app verzamelt, deelt en waarvoor. De coach deelt gegevens met Google (Gemini). |
| **Health apps declaration** | Verplicht formulier voor elke app. FitLog verwerkt fitness-, slaap- en alcoholgegevens. |
| **Gezondheidstoestemmingen** | Voor elk gegevenstype uit Health Connect een verklaring waarom FitLog het leest (§4.4). |
| **AI-gegenereerde inhoud** | De app moet gebruikers **in de app zelf**, zonder ze te verlaten, laten melden als de AI iets aanstootgevends zegt. Nodig: een meldknop bij elk antwoord van de coach (§10). |
| **Doel-API-niveau** | Nieuwe apps moeten API 36 targeten (sinds 31 augustus 2026). FitLog target al 37. |

---

## 8. België: onderneming, btw, belasting en sociale bijdragen

*Dit deel is een oriëntatie. Laat het bevestigen door een boekhouder voor je de eerste
betaalde verkoop doet.*

### 8.1 Wanneer word je een onderneming?

Zolang de coach gratis is en jij er niets aan verdient, is er niets te regelen. **Zodra je
geregeld geld ontvangt voor pakketten of abonnementen**, is dat een beroepsactiviteit.
Dan heb je nodig:

- een **ondernemingsnummer** in de KBO (Kruispuntbank van Ondernemingen);
- een **btw-nummer** (hetzelfde nummer, geactiveerd voor btw);
- een aansluiting bij een **sociaal verzekeringsfonds**.

Heb je een job in loondienst, dan word je **zelfstandige in bijberoep**. Ben je student,
dan bestaat er een apart statuut **student-zelfstandige**, met andere drempels. Vraag dat na
bij je sociaal verzekeringsfonds.

### 8.2 Stappen

1. **Ondernemingsloket** (bijvoorbeeld Xerius, Liantis, Securex, Partena):
   - inschrijving in de KBO: **€111,50** (2026);
   - kies een omschrijving van je activiteit (NACEBEL-code, bijvoorbeeld
     softwareontwikkeling en -uitgeverij).
2. **Btw-nummer activeren:** via het ondernemingsloket (extra dienst, ongeveer €70 excl.
   btw), of zelf bij de FOD Financiën.
3. **Sociaal verzekeringsfonds:** aansluiten.
4. **Bankrekening:** een aparte rekening voor de onderneming is sterk aangeraden. Voor een
   eenmanszaak is ze niet verplicht.
5. **Boekhouding:** alle inkomsten (overzichten van Google Play) en kosten (facturen van
   Google Cloud, Cloudflare, KBO, boekhouder) bijhouden.

### 8.3 Btw

**Vrijstellingsregeling voor kleine ondernemingen:** is je jaaromzet (zonder btw) niet hoger
dan **€25.000**, dan kan je kiezen voor de vrijstellingsregeling. Je rekent dan geen btw aan
en dient geen periodieke btw-aangiften in. Je moet wel nog een **jaarlijkse klantenlisting**
indienen, en een **jaaropgave** van je handelingen in België (uiterlijk 31 maart).

Hoe het uitdraait voor FitLog:

| Stroom | Wie rekent de btw | Wat jij doet |
|---|---|---|
| Gebruiker → Google Play (pakket of abonnement) | **Google** rekent 21% aan en draagt ze af | Niets |
| Google → jij (uitbetaling) | Jouw dienst aan Google Ireland is een dienst aan een bedrijf in een ander EU-land: **geen Belgische btw**, de btw wordt verlegd | Laat je boekhouder bepalen welke opgave nodig is (bijvoorbeeld een intracommunautaire opgave) |
| Google Cloud → jij (Gemini, Business-account) | **Verlegd**: Google rekent geen btw | Je moet de Belgische btw zelf aangeven en betalen, via een **bijzondere btw-aangifte**. Ook onder de vrijstellingsregeling. |
| Google Cloud → jij (Individual Entrepreneur-account) | Google rekent **21%** aan | Niets extra, maar je betaalt 21% meer |

Omdat je onder de vrijstellingsregeling geen btw kan terugvragen, **betaal je in beide
gevallen 21% op je Gemini-kosten**. Het verschil tussen de twee accounttypes is vooral
administratief. Beslis het samen met je boekhouder vóór je het betaalaccount aanmaakt
(§6.2). De berekeningen in §11 tellen die 21% al mee.

### 8.4 Inkomstenbelasting

- Je **winst** (ontvangsten van Google min je beroepskosten) wordt belast in de
  **personenbelasting**, samen met je andere inkomsten, aan het progressieve tarief.
- **Beroepskosten** zijn onder meer: Gemini-kosten, Cloudflare, de $25 van Google Play,
  de KBO-inschrijving, de boekhouder, en eventueel een deel van je materiaal.
- **Bewaar alle overzichten en facturen.**

### 8.5 Sociale bijdragen (bijberoep, cijfers 2026)

| Netto belastbaar inkomen uit je zelfstandige activiteit, per jaar | Sociale bijdragen |
|---|---|
| Lager dan **€1.922,16** | **Geen** |
| Hoger | Ongeveer **20,5%** van dat inkomen; minimum **€98,51 per kwartaal** |

In de eerste jaren betaal je **voorlopige bijdragen**, later rechtgezet op basis van je echte
inkomen. Verwacht je weinig inkomen, meld dat aan je sociaal verzekeringsfonds. Het
minimum is dan vaak nul of laag.

**Rekenvoorbeeld:** 50 abonnees × €2,10 × 12 maanden ≈ **€1.260 per jaar** vóór kosten.
Dat blijft onder de drempel, dus er zijn geen sociale bijdragen. Wel inkomstenbelasting op
de winst.

### 8.6 Consumentenrecht

- De aankoop zelf verloopt via **Google Play**: Google toont de voorwaarden, rekent af en
  regelt terugbetalingen volgens zijn eigen beleid.
- Zorg toch voor **eigen gebruiksvoorwaarden**: wat een pakket of abonnement geeft, dat de
  coach geen medisch advies geeft, dat tegoed niet vervalt, en wat er gebeurt als de
  maandlimiet van FitLog bereikt is.
- **Herroepingsrecht (14 dagen)** bij digitale diensten: laat je boekhouder of een jurist
  bevestigen hoe dat samengaat met de afhandeling door Google Play.

---

## 9. Privacy (AVG) en de AI-verordening

### 9.1 Wie is wie?

| Rol | Wie |
|---|---|
| **Verwerkingsverantwoordelijke** (bepaalt waarom en hoe) | **Jij**, voor de gedeelde coach |
| **Verwerker** | **Google** (Gemini, betaalde laag, met de verwerkersovereenkomst van Google Cloud) |
| **Verwerker** | **Cloudflare** (tussenstation, met de verwerkersovereenkomst van Cloudflare) |

Bij de optie **"eigen sleutel"** ben jij geen verwerkingsverantwoordelijke voor de
gesprekken: die gaan rechtstreeks van de gebruiker naar Google. **Health Connect** blijft
op de gsm: daar verwerk jij niets op een server.

### 9.2 Gezondheidsgegevens

Trainingen, slaap, HRV, spierpijn en alcohol liggen dicht tegen **gezondheidsgegevens**
aan: een **bijzondere categorie** in de AVG (artikel 9). Daarvoor is **uitdrukkelijke
toestemming** nodig. In de praktijk:

- de gedeelde coach staat **standaard uit**;
- bij het aanzetten een **toestemmingsscherm** dat duidelijk zegt:
  - dat je met een AI praat;
  - welke gegevens meegaan: enkel wat de coach opzoekt of de samenvatting van een
    proactieve functie, nooit het hele logboek;
  - dat ze via het tussenstation naar Google gaan en daar tot 7 dagen voor misbruikcontrole
    bewaard kunnen worden;
  - dat er niets op jouw server blijft;
- de **proactieve functies** (§3) staan elk apart aan of uit, want ze sturen uit zichzelf
  een samenvatting weg;
- **intrekken moet even makkelijk zijn**: één schakelaar in de instellingen.

### 9.3 Zo weinig mogelijk gegevens

- **De app rekent, de AI legt uit** (§3): de AI krijgt samenvattingen in cijfers, geen
  ruwe gegevens.
- De coach haalt al alleen op wat hij nodig heeft, met een plafond van 40 rijen per
  opzoeking. **Zo houden.**
- **Geen naam, geen e-mail, geen telefoonnummer** meesturen. Het installatienummer is
  willekeurig.
- **Het tussenstation bewaart geen inhoud**, alleen tellers en tegoed.
- **Bewaartermijn in AI Studio: 7 dagen** (§6.7). Overweeg Zero Data Retention aan te
  vragen.

### 9.4 Documenten die je nodig hebt

- [ ] **Privacyverklaring** (verplicht voor Google Play): wie je bent, welke gegevens,
  waarom, met wie gedeeld, hoe lang bewaard, welke rechten de gebruiker heeft, en hoe hij
  jou bereikt. Met een apart stuk over Health Connect.
- [ ] **Verwerkingsregister** (artikel 30 AVG). Kleine organisaties zijn meestal
  vrijgesteld, **maar niet** als ze bijzondere categorieën verwerken. Hou er dus een bij.
- [ ] **Afweging voor een gegevensbeschermingseffectbeoordeling (DPIA)**: schrijf op
  waarom er wel of geen nodig is.
- [ ] **Verwerkersovereenkomsten** van Google Cloud en Cloudflare aanvaarden.
- [ ] **Rechten van gebruikers:** inzage en verwijdering. Omdat de server niets bewaart
  behalve tellers en tegoed, staat alles op de gsm. Leg dat uit in de privacyverklaring.

### 9.5 Doorgifte buiten de EU

De Gemini API via AI Studio belooft geen verwerking binnen de EU. Google en Cloudflare
dekken doorgifte in hun voorwaarden (EU-VS-gegevensprivacykader en
standaardcontractbepalingen). Vermeld dit in je privacyverklaring. Voor meer zekerheid
later: Vertex AI met een Europese regio (§6.7).

### 9.6 De AI-verordening (EU AI Act)

- **Vanaf 2 augustus 2026** (artikel 50): gebruikers moeten weten dat ze met een AI praten.
  De naam **"AI-coach"** en het toestemmingsscherm dekken dat. Zet het er ook bij in het
  gesprek en boven elk weekoverzicht.
- **Gegenereerde beelden en tekst** moeten machineleesbaar herkenbaar zijn als
  AI-gegenereerd. Voor systemen die al op de markt waren, geldt daarvoor een overgang tot
  **2 december 2026**. Die plicht ligt vooral bij de aanbieder van het model. De tekeningen
  in FitLog dragen al zichtbaar het label *"getekend door AI"*.

---

## 10. Wat er in de app verandert

| Onderdeel | Wat |
|---|---|
| **Health Connect** | Toestemmingen per gegevenstype, slaap/HRV/rusthartslag/gewicht/cardio lezen, workouts terugschrijven. Herstel en statistieken gebruiken die gegevens. |
| **Stilstand zien** | Gratis, lokaal berekend, op de pagina van een oefening en in de overzichten. |
| **Keuze van de coach** | Drie opties: *Uit* (standaard), *FitLog-coach* (gedeeld) en *Eigen sleutel* (zoals nu). |
| **Toestemmingsscherm** | Zie §9.2. Pas daarna vertrekt er iets. |
| **Weekoverzicht** | Een melding op zondagavond, en het overzicht als eigen scherm. Aan/uit en het tijdstip instelbaar. |
| **Aangepast schema** | Een plan over enkele weken, met wekelijkse voorstellen die je aanvaardt of weigert. |
| **Check voor je training** | Bij het starten van een workout, alleen als er iets te melden valt. |
| **Installatienummer** | Willekeurig, één keer aangemaakt, alleen op de gsm. |
| **Play Integrity** | Bij elke vraag (of per korte periode) een bewijs voor het tussenstation. |
| **Het ene netwerkbestand** | Het adres van het tussenstation komt erbij als vaste, gekende host. De deurtest (`test/security/offline_test.dart`) krijgt die host erbij. Health Connect vraagt geen netwerk. |
| **Teller en tegoed** | "Nog 12 van 20 gratis vragen deze maand", of het resterende tegoed. |
| **Meldknop** | Bij elk antwoord van de coach: *"Meld dit antwoord"*. Stuurt alleen de tekst van dat antwoord en een reden naar het tussenstation, nooit het logboek. Het tussenstation bewaart meldingen 30 dagen zodat jij ze kan nakijken. Vermeld dit in de privacyverklaring. |
| **Kopen** | Scherm met de pakketten (later het abonnement), kopen en "Aankopen herstellen", via `in_app_purchase`. |
| **Limiet bereikt** | Duidelijke melding: gratis vragen op, tegoed op, of maandlimiet van FitLog bereikt. En de verwijzing naar een pakket of de optie "eigen sleutel". |

**Technische keuzes:**

- De gedeelde coach gebruikt **dezelfde opdracht en tools** als nu. Het tussenstation geeft
  de vraag ongewijzigd door aan Gemini, dus er is geen tweede versie van de coach om te
  onderhouden.
- De proactieve functies werken **ook met een eigen sleutel**: de app maakt de samenvatting,
  en stuurt ze naar wie de coach levert.
- **Tekeningen** blijven voorlopig bij de eigen tokens (Hugging Face of Cloudflare) van de
  gebruiker. Ze kunnen later ook via het tussenstation, maar dat valt buiten dit plan.

---

## 11. Kosten, prijzen en wanneer het winst maakt

*Voor de eenvoud: $1 ≈ €1. De 21% btw op de Gemini-kosten zit overal inbegrepen, want die
betaal je hoe dan ook (§8.3).*

### 11.1 Wat één gebruiker oplevert of kost, per maand

| | per maand |
|---|---|
| **Abonnee €2,99**: na btw en Google | **+€2,10** |
| **Abonnee €4,99**: na btw en Google | **+€3,51** |
| Eigen vragen van een abonnee (gemiddeld 5 per dag, sterker model) | −€0,50 |
| De vier proactieve functies samen | −€0,08 |
| **Gratis gebruiker**, gemiddeld 2 vragen per dag (goedkoopste model) | −€0,07 |
| **Gratis gebruiker**, gemiddeld 1 vraag per dag | −€0,04 |
| **Gratis gebruiker** met 20 vragen per maand (§5.5) | −€0,03 |

### 11.2 De verhouding die telt

Een abonnee van €2,99 houdt netto ongeveer **€1,52** over na zijn eigen vragen en de vier
functies. Een gratis gebruiker met gemiddeld 2 vragen per dag kost **€0,07**. **Eén abonnee
betaalt dus voor ongeveer 22 gratis gebruikers.** Neemt minder dan 1 op 22 actieve
gebruikers (4,6%) iets af, dan verlies je geld op de AI, hoeveel gebruikers je ook hebt.

**Gratis gebruik is je grootste kost**, niet de abonnees. Daarom is de gratis limiet in dit
plan **20 vragen per maand** en niet "3 per dag".

### 11.3 Hoeveel vragen voor een abonnee?

Een vraag op het sterkere model kost ongeveer **€0,0036** (btw inbegrepen). Wie zijn
volledige limiet opgebruikt, kost:

| Vragen per maand | Kost als alles gebruikt wordt | Wat je overhoudt bij €2,99 | bij €4,99 |
|---|---|---|---|
| 150 (~5/dag) | €0,54 | €1,56 | €2,97 |
| **300 (~10/dag)** | €1,09 | **€1,01** | €2,42 |
| **500 (~16/dag)** | €1,82 | €0,28 | **€1,69** |
| 1.500 (50/dag) | €5,45 | −€3,35 | −€1,94 |

**Omslagpunt** (als elke vraag de gemiddelde prijs kost): ongeveer **19 vragen per dag** bij
€2,99, en **32 per dag** bij €4,99. Daarom **300 per maand bij €2,99, of 500 bij €4,99**:
zelfs een abonnee die alles opgebruikt, brengt dan nog op. De proactieve functies tellen
niet mee in die limiet en kosten samen ongeveer €0,08.

### 11.4 Wanneer verdien je de opstart terug?

**Eenmalige kosten:** Google Play $25 + KBO €111,50 + btw-activering ~€70 ≈ **€205**.

Aantal betalers dat je een jaar lang nodig hebt om dat terug te verdienen, als 5% van de
actieve gebruikers betaalt:

| Scenario | Winst per betaler per maand* | Betalers nodig (1 jaar) | Actieve gebruikers nodig |
|---|---|---|---|
| **A.** €2,99, gratis gemiddeld 2 vragen per dag | €0,19 | 90 | ~1.800 |
| **B.** €2,99, gratis gemiddeld 1 vraag per dag | €0,86 | **20** | ~400 |
| **C.** €4,99, gratis gemiddeld 1 vraag per dag | €2,27 | **8** | ~160 |

\* Wat een betaler netto oplevert (na zijn eigen vragen en de vier functies), min de
kosten van de 19 gratis gebruikers die bij hem horen.

- Na het eerste jaar vallen de opstartkosten weg: dan is alles boven nul winst.
- **Vaste jaarkosten** (zoals een boekhouder): elke €100 per jaar vraagt in scenario B
  ongeveer **10 betalers extra**.
- De **5% is een aanname.** Hoeveel gebruikers echt betalen, weet je pas als je het
  probeert. Ligt het lager, dan telt een lage gratis limiet nog zwaarder.
- Op de winst betaal je inkomstenbelasting. Sociale bijdragen pas vanaf €1.922 winst per
  jaar in bijberoep (§8.5).

### 11.5 Vragenpakketten

| Pakket | Prijs | Jij ontvangt (20% Google) | Kost als alles gebruikt wordt | Marge |
|---|---|---|---|---|
| 100 vragen | €1,99 | €1,32 | €0,36 | **€0,96** |
| 300 vragen | €4,99 | €3,30 | €1,09 | **€2,21** |

- **Een pakket is altijd winstgevend**, ook als alles gebruikt wordt: de gebruiker betaalt
  eerst, en jij betaalt Google pas als het tegoed opgaat.
- **Lage drempel** voor een onbekende maker: geen abonnement om op te zeggen.
- **Het is een test**: verkopen pakketten, dan is er vraag, en kan een abonnement volgen.

### 11.6 Vaste en eenmalige kosten

| Wat | Bedrag |
|---|---|
| Google Play-ontwikkelaarsaccount | $25, eenmalig |
| KBO-inschrijving | €111,50, eenmalig |
| Btw-activering via het ondernemingsloket (optioneel) | ~€70 excl. btw, eenmalig |
| Cloudflare Workers | €0 (gratis plan), $5 per maand als het ooit nodig is |
| Health Connect | €0 |
| Boekhouder | Verschilt; vraag een offerte voor een klein bijberoep |

---

## 12. Stappenplan

### Fase 0 — Beslissingen (vooraf)

- [ ] Ga je naar **Google Play**? (Nodig voor gebruikers, Play Integrity en aankopen.)
- [ ] Hoeveel mag de gedeelde coach **maximaal per maand** kosten? (Voorstel: €10.)
- [ ] Ga je akkoord met de **nieuwe belofte**: "geen account, en een tussenstation dat
  niets bewaart"?
- [ ] Gratis limiet en prijzen (voorstel: 20 vragen per maand; pakketten van €1,99 en
  €4,99; later eventueel een abonnement van €2,99 voor 300 of €4,99 voor 500).

### Fase 1 — Health Connect (gratis, los van de coach)

- [ ] Slaap, HRV, rusthartslag, gewicht en cardio lezen; workouts terugschrijven.
- [ ] Herstel gebruikt HRV en rusthartslag tegenover je eigen gemiddelde; cardio telt mee
  voor de benen; slaap komt automatisch binnen.
- [ ] Stilstand herkennen (lokaal, gratis) op de pagina van een oefening.
- [ ] Privacyverklaring op de website bijwerken met een stuk over Health Connect.

### Fase 2 — Google Play

- [ ] Ontwikkelaarsaccount ($25), identiteitscontrole.
- [ ] Gesloten test met **12 testers, 14 dagen onafgebroken**. Begin vroeg met testers
  zoeken.
- [ ] Formulieren in Play Console: Data safety, Health apps declaration,
  gezondheidstoestemmingen, privacyverklaring, inhoudsbeoordeling.
- [ ] Production access aanvragen (meestal binnen 7 dagen beoordeeld).
- [ ] Ook de GitHub-versie laten verifiëren via de Android Developer Console, vóór de
  wereldwijde verplichting in 2027.

### Fase 3 — De gedeelde coach en de vier functies (nog zonder te verkopen)

- [ ] AI Studio: een testproject met betaalaccount, prepay $10 (§6.9). *Bewust: nog zonder
  onderneming.*
- [ ] Cloudflare Worker: doorsturen, Play Integrity, gratis limiet per installatie,
  maandlimiet, niets bewaren.
- [ ] App: keuze *Uit / FitLog-coach / Eigen sleutel*, toestemmingsscherm, teller,
  meldknop.
- [ ] De vier functies: weekoverzicht, aangepast schema, check voor je training, stilstand
  uitgelegd. Eerst allemaal gratis voor testers, om te zien wat mensen echt gebruiken.

### Fase 4 — Onderneming en vragenpakketten

- [ ] Gesprek met een boekhouder over §8, **vóór** de eerste betaalde verkoop.
- [ ] Ondernemingsloket: KBO, btw-nummer, sociaal verzekeringsfonds.
- [ ] Nu pas het **definitieve** Cloud Billing-account voor de coach aanmaken, met het
  juiste accounttype (§6.2). Project en sleutel overzetten.
- [ ] Play Console: betaalprofiel, bankrekening, pakketten `vragen_100` en `vragen_300`
  (§7.6).
- [ ] App: koopscherm met `in_app_purchase`, tegoed, "Aankopen herstellen".
- [ ] Tussenstation: aankoop controleren, tegoed bijschrijven, aankoop verbruiken (binnen
  3 dagen).
- [ ] Gebruiksvoorwaarden en de privacyverklaring bijwerken.
- [ ] Lanceren.

### Fase 5 — Abonnement (alleen als pakketten verkopen)

- [ ] Abonnement `coach_plus` in Play Console (§7.6).
- [ ] Tussenstation: abonnement controleren en bevestigen (binnen 3 dagen),
  abonneelimieten (§5.5).
- [ ] App: het abonnement naast de pakketten tonen.

### Fase 6 — Opvolgen (maandelijks)

- [ ] Kosten bij Google Cloud tegenover de maandlimiet.
- [ ] Hoeveel procent van de actieve gebruikers betaalt? Boven of onder 4,6% (§11.2)?
- [ ] Meldingen van gebruikers nakijken (meldknop).
- [ ] Zijn de limieten te krap of te ruim? Zijn de modellen nog de beste keuze?
- [ ] Overzicht van Google Play in de boekhouding.
- [ ] Jaarlijks: API-sleutel vervangen, voorwaarden van Google en Play opnieuw lezen.

---

## 13. Risico's die je bewust aanvaardt

| Risico | Wat het afdekt |
|---|---|
| **Google's eigen coach** (Google Health Premium) is bekender en kent het horloge | Inzetten op krachttraining in detail, privacy en een lagere prijs; Health Connect gratis zodat FitLog de horlogegegevens ook kent |
| Te weinig mensen betalen | Lage gratis limiet; eerst pakketten als test; de app blijft ook zonder betalers bruikbaar |
| Iemand misbruikt het tussenstation | Play Integrity, limiet per installatie, harde maandlimiet |
| De sleutel lekt uit | Staat alleen als geheim in de Worker, is beperkt tot de Gemini API, jaarlijks vervangen, en er is prepay-tegoed als plafond |
| Google verandert prijzen of voorwaarden | Maandlimiet; maandelijks nakijken; de optie "eigen sleutel" blijft |
| De coach zegt iets fout of schadelijks | Het is geen medisch advies (opdracht en voorwaarden), er is een meldknop, en Google's veiligheidsfilters |
| Privacyklacht | Toestemming, de app rekent en de AI legt uit, niets bewaren, duidelijke privacyverklaring |

## 14. Nog na te kijken door een deskundige

- [ ] **Boekhouder:** statuut (bijberoep of student-zelfstandige), btw-regeling en welke
  opgaven nodig zijn voor de uitbetalingen van Google Ireland en de facturen van Google
  Cloud, het accounttype van het Cloud Billing-account.
- [ ] **Jurist of privacyspecialist (aangeraden):** de privacyverklaring, de toestemming
  voor gezondheidsgegevens (ook uit Health Connect), de afweging over een DPIA, en het
  herroepingsrecht.

---

## Bronnen

**Concurrentie en prijzen**

- [TechCrunch – Google's $9,99-per-month AI health coach](https://techcrunch.com/2026/05/07/googles-9-99-per-month-ai-health-coach-launches-may-19/)
- [Google – Google Health Coach voor Premium-gebruikers](https://blog.google/products-and-platforms/products/google-health/google-health-coach/)
- [Prijzen van fitnessapps 2026 (Hevy, Strong, Fitbod)](https://www.sensai.fit/blog/fitness-app-pricing-free-tier-comparison)
- [Hevy – prijzen](https://hevy.com/pricing)

**Health Connect**

- [Android – slaapsessies in Health Connect](https://developer.android.com/health-and-fitness/health-connect/features/sleep-sessions)
- [Android – je gezondheidsapp publiceren op Google Play](https://developer.android.com/health-and-fitness/health-connect/publish)
- [Flutter en Health Connect – praktische gids](https://asoasis.tech/articles/2026-08-03-0853-flutter-health-kit-fitness-data/)

**Google AI Studio en de Gemini API**

- [Gemini API – aanvullende voorwaarden (enkel betaalde diensten in de EER)](https://ai.google.dev/gemini-api/terms)
- [Gemini API – billing (prepay/postpay, limieten, tegoed)](https://ai.google.dev/gemini-api/docs/billing)
- [Gemini API – rate limits en niveaus](https://ai.google.dev/gemini-api/docs/rate-limits)
- [Gemini API – prijzen](https://ai.google.dev/gemini-api/docs/pricing)
- [Gemini API – logging en bewaartermijn](https://ai.google.dev/gemini-api/docs/logs-policy)
- [Gemini API – Zero Data Retention](https://ai.google.dev/gemini-api/docs/zdr)
- [Google Cloud – btw in jouw land (accounttypes)](https://docs.cloud.google.com/billing/docs/resources/vat-overview)
- [Google Cloud – betalen met SEPA](https://knowledge.workspace.google.com/admin/billing/update-your-bank-account-for-sepa-europe)

**Google Play**

- [Servicekosten van Google Play](https://support.google.com/googleplay/android-developer/answer/112622)
- [Btw en belastingen bij Google Play](https://support.google.com/googleplay/android-developer/answer/138000)
- [Uitbetalingen](https://support.google.com/googleplay/android-developer/answer/137997)
- [Testverplichting voor nieuwe persoonlijke accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Beleid voor AI-gegenereerde inhoud](https://support.google.com/googleplay/android-developer/answer/14094294)
- [Health apps declaration](https://support.google.com/googleplay/android-developer/answer/14738291)
- [Play Integrity – verdicts](https://developer.android.com/google/play/integrity/verdicts)
- [Android developer verification](https://developer.android.com/developer-verification)

**België**

- [FOD Financiën – btw-vrijstellingsregeling kleine ondernemingen](https://finance.belgium.be/en/node/223)
- [VLAIO – een ondernemingsnummer aanvragen](https://www.vlaio.be/nl/begeleiding-advies/start/opstart-van-je-onderneming/opstarten-7-stappen/een-ondernemingsnummer-aanvragen)
- [KBO-inschrijving, prijs 2026](https://billy.tech/nl/gids/onderneming-starten/kosten/inschrijving-kbo-prijs/)
- [Sociale bijdragen in bijberoep, 2026](https://www.accountable.eu/nl-be/blog/sociale-bijdragen-zelfstandigen-in-bijberoep/)

**Europa**

- [Europese Commissie – transparantieverplichtingen artikel 50 AI-verordening](https://digital-strategy.ec.europa.eu/en/faqs/transparency-obligations-under-article-50-ai-act)

**Infrastructuur**

- [Cloudflare Workers – prijzen](https://developers.cloudflare.com/workers/platform/pricing/)
