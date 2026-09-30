# Plan: een AI-coach voor iedereen in FitLog

*Opgesteld op 30 september 2026. Bedragen, regels en voorwaarden veranderen: kijk ze na
voor je een stap zet. Waar dit plan over belastingen en recht gaat, is het een
oriëntatie en geen advies. Laat die delen nakijken door een boekhouder (en voor de
privacy eventueel een jurist).*

---

## 0. In het kort

- **Wat:** elke gebruiker kan de coach gebruiken zonder zelf een sleutel aan te maken.
  Gratis met een paar vragen per dag, later met een betaald abonnement voor meer.
- **Hoe:** de app stuurt de vraag naar een **klein tussenstation** (een Cloudflare Worker)
  dat jouw sleutel bewaart en de vraag doorgeeft aan **Gemini, betaalde laag**.
  Het tussenstation bewaart niets.
- **Geen eigen model trainen.** Een bestaand model met goede tools en een goede opdracht
  doet het beter en kost bijna niets.
- **Kostprijs:** ongeveer **0,1 tot 0,4 cent per vraag**. Met weinig gebruikers is dat
  enkele euro's per maand.
- **Wat je moet regelen:**
  1. een betaalaccount bij Google AI Studio;
  2. een ontwikkelaarsaccount bij Google Play (eenmalig $25);
  3. vóór de eerste betaalde verkoop: een inschrijving als zelfstandige (KBO, btw,
     sociaal verzekeringsfonds);
  4. een privacyverklaring en een toestemmingsscherm.
- **Wat er verandert aan de belofte van de app:** van *"geen server, geen account"*
  naar *"geen account, en een tussenstation dat niets bewaart"*. De coach blijft
  uitgeschakeld tot de gebruiker hem zelf aanzet.
- **Volgorde:** fase 1 techniek (gratis vragen) → fase 2 Google Play → fase 3 onderneming
  en abonnement → fase 4 opvolgen.

---

## 1. Wat we bouwen, en wat niet

**Wel:**

- Een gedeelde coach die iedereen kan gebruiken, via jouw eigen Gemini-sleutel die
  veilig op het tussenstation staat.
- Een dagelijkse limiet per installatie, en een harde maandlimiet op jouw kosten.
- Later een abonnement via Google Play voor meer vragen en een sterker model.
- De huidige optie **"eigen sleutel"** blijft bestaan. Wie zijn eigen Gemini-sleutel
  gebruikt, gaat rechtstreeks naar Google zoals nu.

**Niet:**

- **Geen eigen model trainen.** Een model vanaf nul trainen kost miljoenen. Bijtrainen
  (fine-tuning) is niet nodig: de kracht van de coach zit in zijn tools (hij zoekt zelf
  in het logboek) en in zijn opdracht.
- **Geen accounts, geen wachtwoorden, geen e-mailadressen.**
- **Geen opslag van logboeken of gesprekken op een server.** Gesprekken blijven op de gsm.

---

## 2. Hoe het werkt

```
 ┌──────────────┐    HTTPS     ┌──────────────────────┐    HTTPS    ┌───────────────────┐
 │  FitLog-app  │ ───────────► │    Tussenstation     │ ──────────► │  Gemini API       │
 │  (gsm)       │ ◄─────────── │ (Cloudflare Worker)  │ ◄────────── │  (betaalde laag)  │
 └──────────────┘              └──────────────────────┘             └───────────────────┘
        │                                 │
        │ Play Integrity-bewijs           │ controleert bewijs en aankoop
        ▼                                 ▼
 ┌─────────────────────────────────────────────────────┐
 │  Google Play (installatie, Integrity, abonnementen) │
 └─────────────────────────────────────────────────────┘
```

### 2.1 Waarom een tussenstation?

Een sleutel die in de app zit, is **niet geheim**. Iedereen kan een APK uit elkaar halen en
de sleutel eruit halen, en dan betaal jij voor zijn gebruik. Het tussenstation houdt de
sleutel bij zich en stuurt alleen door.

### 2.2 Wat het tussenstation doet

1. **Controleert** of de vraag van een echte FitLog-installatie komt (Play Integrity, §2.4).
2. **Telt** de vragen per installatie en weigert boven de daglimiet.
3. **Bewaakt de maandlimiet** van jouw kosten. Is die bereikt, dan stopt de gedeelde coach
   tot de volgende maand. Misbruik kan je dus nooit meer kosten dan die limiet.
4. **Geeft de vraag door** aan Gemini, met jouw sleutel.
5. **Controleert abonnementen** bij Google Play (fase 3).

### 2.3 Wat het tussenstation nooit doet

- Geen vragen, antwoorden of logboekgegevens opslaan.
- Geen inhoud loggen. Alleen tellers: welke installatie hoeveel vragen stelde op een dag.
- Geen namen, e-mailadressen of telefoonnummers ontvangen.

**Waarom Cloudflare Workers?** Je hebt al een Cloudflare-account voor de tekeningen. Het
gratis plan geeft 100.000 verzoeken per dag, ruim genoeg. Het betaalde plan kost $5 per
maand als het ooit nodig is.

### 2.4 Gebruikers herkennen zonder accounts

- **Installatienummer:** bij de eerste keer maakt de app een willekeurig nummer aan. Dat
  zegt niets over wie je bent, en is genoeg om per toestel te tellen.
- **Play Integrity:** Google geeft de app een bewijs dat het een echte, onaangepaste
  FitLog-installatie is. Het tussenstation laat dat bewijs controleren.
  - **Dit werkt alleen voor installaties via Google Play.** Een APK van GitHub krijgt het
    oordeel "niet via Play geïnstalleerd" en kan dus geen gedeelde coach gebruiken.
    GitHub-gebruikers houden de optie "eigen sleutel".

### 2.5 Limieten (voorstel, aan te passen)

| | Gratis | Abonnement |
|---|---|---|
| Vragen per dag | 3 | 50 |
| Model | Gemini 2.5 Flash-Lite (goedkoopst) | Gemini 3.1 Flash-Lite (sterker) |
| Foto meesturen | nee | ja |

**Jouw maandlimiet** voor de gedeelde coach: voorstel **€10**. Dat stel je in op het
tussenstation, bovenop de limiet van Google zelf (§3.5).

---

## 3. Google AI Studio en de Gemini API: alles over betalen

### 3.1 Waarom het de betaalde laag moet zijn

De voorwaarden van de Gemini API zeggen letterlijk:

> *"You may use only Paid Services when making API Clients available to users in the
> European Economic Area, Switzerland, or the United Kingdom."*

De gratis laag mag je dus **niet** gebruiken om de coach aan Belgische en Europese
gebruikers aan te bieden. Daar komt nog bij: op de gratis laag mag Google je vragen
gebruiken om zijn producten te verbeteren, en mogen menselijke beoordelaars ze lezen.
Op de betaalde laag gebeurt dat niet.

*Nu mag het wel, omdat elke gebruiker zijn eigen sleutel meebrengt: dan gebruikt de
gebruiker zelf Google, niet jij.*

### 3.2 Het betaalaccount: welk type?

Betalen voor de Gemini API loopt via een **Cloud Billing-account** van Google Cloud. Je
koppelt dat vanuit AI Studio aan je project.

**Belangrijk: het accounttype kan je achteraf niet meer veranderen.**

| Type | Wanneer | Btw op de factuur van Google |
|---|---|---|
| **Business** (standaard in de EU) | Je hebt een ondernemingsnummer (KBO) met btw-nummer | **Geen btw** op de factuur. De btw wordt *verlegd*: jij moet de Belgische btw zelf aangeven (§5.3). |
| **Individual Entrepreneur** | Je werkt als eenmanszaak, eventueel nog zonder btw-nummer | Google rekent **21% Belgische btw** aan |

**Advies:** maak het betaalaccount pas aan **nadat** je weet hoe je de onderneming opzet
(fase 3), of kies bewust met je boekhouder. Wil je in fase 1 al testen zonder
onderneming, gebruik dan een apart testproject en een apart betaalaccount. Het
eigenlijke betaalaccount voor de coach maak je later aan.

### 3.3 Betaalmiddelen

- **Kredietkaart of debetkaart.**
- **Domiciliëring (SEPA)**: je bankrekening met IBAN en BIC.
- Bankoverschrijvingen kunnen enkele dagen duren voor ze verwerkt zijn.

### 3.4 Vooraf betalen of achteraf betalen?

| | **Prepay** (vooraf) | **Postpay** (achteraf) |
|---|---|---|
| Hoe | Je koopt tegoed, vanaf $5 | Google rekent aan het einde van de maand af, of eerder zodra je de limiet van je niveau bereikt |
| Voordeel | Je kan nooit meer uitgeven dan je tegoed | Geen tegoed dat vervalt |
| Nadeel | Tegoed **vervalt na 1 jaar** en wordt **niet terugbetaald** (behalve bij overstappen naar postpay) | Een fout of misbruik kost tot de limiet van je niveau |

**Advies:** begin met **prepay en een klein bedrag ($10 à $20)**. Dat is een tweede
vangnet naast de maandlimiet van het tussenstation.

### 3.5 Niveaus (tiers) en de limiet van Google

| Niveau | Hoe je het bereikt | Maandlimiet van Google |
|---|---|---|
| Gratis | Actief project | – |
| **Tier 1** | Betaalaccount gekoppeld | **$250** |
| Tier 2 | $100 betaald en 3 dagen sinds de eerste betaling | $2.000 |
| Tier 3 | $1.000 betaald en 30 dagen sinds de eerste betaling | $20.000 – $100.000+ |

Met weinig gebruikers blijf je in **Tier 1**. Een hoger niveau geeft ook ruimere
snelheidslimieten (vragen per minuut).

### 3.6 Het gratis Google Cloud-tegoed geldt hier niet

Nieuwe Google Cloud-klanten krijgen soms welkomsttegoed of proeftegoed ($300). Dat mag
**niet** gebruikt worden voor de Gemini API of AI Studio.

### 3.7 Wat Google met de gegevens doet (betaalde laag)

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

### 3.8 Welk model, en wat het kost

Prijzen per miljoen tokens, betaalde laag (standaardtarief):

| Model | Invoer | Uitvoer | Per coachvraag* | Per 1.000 vragen |
|---|---|---|---|---|
| Gemini 2.5 Flash-Lite | $0,10 | $0,40 | ~$0,001 | ~$1 |
| Gemini 3.1 Flash-Lite | $0,25 | $1,50 | ~$0,003 | ~$3 |
| Gemini 3.5 Flash-Lite | $0,30 | $2,50 | ~$0,004 | ~$4 |

\* Een vraag is gemiddeld ongeveer 3 rondes van zo'n 3.000 tokens invoer, plus zo'n 500
tokens antwoord in totaal. De opdracht en de tools zijn bij elke ronde dezelfde; Gemini
kan dat herhaalde begin tijdelijk bewaren, wat de echte prijs wat lager maakt.

### 3.9 Stap voor stap instellen

1. Ga naar **AI Studio → Projects**. Maak een nieuw project aan: **"FitLog Coach"**, apart
   van je persoonlijke project.
2. Klik **Set up billing** bij dat project.
3. Maak een **Cloud Billing-account** aan. Kies het accounttype bewust (§3.2): dat kan
   later niet meer.
4. Geef een betaalmiddel op (§3.3).
5. Kies **Prepay** en koop $10 à $20 tegoed (§3.4).
6. Stel de **bewaartermijn van de logboeken** in op **7 dagen** (§3.7).
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

## 4. Google Play en Google Play Billing

### 4.1 Waarom Google Play?

- **Play Integrity** (§2.4) werkt alleen voor installaties via Google Play.
- **Abonnementen** voor digitale functies moeten in een Play-app via Google Play Billing.
- **Makkelijker installeren en bijwerken** voor gebruikers.
- **Ontwikkelaarsverificatie komt eraan.** Sinds 30 september 2026 moeten apps van buiten
  Google Play in Brazilië, Indonesië, Singapore en Thailand van een geverifieerde
  ontwikkelaar komen. Google breidt dat vanaf 2027 wereldwijd uit. Ook voor de
  GitHub-versie moet je je dus binnenkort laten verifiëren (via de *Android Developer
  Console*).

### 4.2 Ontwikkelaarsaccount

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

### 4.3 Betaalprofiel en uitbetalingen

- Je maakt in Play Console een **betaalprofiel (payments profile)** aan en koppelt en
  verifieert een bankrekening.
- Google betaalt **elke maand, vanaf de 15e**, uit voor de verkopen van de vorige maand.
- Er is een **minimumbedrag** voor een uitbetaling. Tot dat bereikt is, schuift het saldo
  door naar de volgende maand.
- Je ontvangt maandelijks een **overzicht** van Google. Dat is het bewijsstuk voor je
  boekhouding.

### 4.4 Wat Google inhoudt

Voor **abonnementen** aan gebruikers in de EER (vanaf 30 juni 2026):
**10% servicekost + 5% betaalkost = 15%**.

**Rekenvoorbeeld** voor een abonnement van **€2,99 per maand** (prijs voor de gebruiker,
btw inbegrepen):

| | Bedrag |
|---|---|
| Prijs voor de gebruiker | €2,99 |
| − 21% Belgische btw (Google draagt die af) | −€0,52 |
| = Prijs zonder btw | €2,47 |
| − 15% Google (servicekost + betaalkost) | −€0,37 |
| **= Wat jij ontvangt** | **€2,10** |

Van die €2,10 gaan nog je kosten af (Gemini, eventueel Cloudflare), en daarna
inkomstenbelasting en eventueel sociale bijdragen (§5).

### 4.5 Btw bij verkopen via Google Play

- In de EU is **Google verantwoordelijk** voor het berekenen, aanrekenen en afdragen van
  de btw op aankopen via Google Play.
- In België toont Google Play prijzen **inclusief btw**. Je stelt de prijs in zoals de
  klant hem betaalt.
- **Jij rekent zelf geen btw aan de gebruiker aan.** Voor de btw verkoop jij aan Google
  (Google Ireland), niet aan de gebruiker. Meer daarover in §5.3.

### 4.6 Het abonnement instellen

In Play Console:

1. **Monetize → Products → Subscriptions → Create subscription**, bijvoorbeeld
   `coach_plus`.
2. Een **basisplan**: *maandelijks, automatisch verlengd*. Eventueel ook jaarlijks, met
   korting.
3. Eventueel een **aanbieding**: bijvoorbeeld 7 dagen gratis proberen.
4. Zet de **respijtperiode** (grace period) aan. Mislukt een betaling, dan houdt de
   gebruiker nog enkele dagen toegang terwijl Google opnieuw probeert.

In de app:

- Het Flutter-pakket **`in_app_purchase`** gebruikt Google Play Billing.
- Een scherm met wat het abonnement geeft, de prijs, en **"Aankopen herstellen"**.

Op het tussenstation:

- Na een aankoop stuurt de app het **aankoopbewijs** (purchase token) naar het
  tussenstation.
- Het tussenstation controleert dat bij Google via de **Google Play Developer API**
  (`purchases.subscriptionsv2`), met een eigen servicesleutel.
- **Een aankoop moet binnen 3 dagen bevestigd (acknowledged) worden.** Anders betaalt
  Google de klant automatisch terug.
- Later, optioneel: **Real-time Developer Notifications** (via Google Cloud Pub/Sub), zodat
  opzeggingen en verlengingen meteen doorkomen.
- **Opzeggen en terugbetalen** gaan via Google Play zelf. De gebruiker zegt op in de Play
  Store.

### 4.7 Regels van Google Play waar je aan moet voldoen

| Regel | Wat je moet doen |
|---|---|
| **Privacyverklaring** | Een openbare webpagina met je privacyverklaring. Die kan op de FitLog-website. De link komt in Play Console. |
| **Data safety** (gegevensveiligheid) | Een formulier in Play Console: welke gegevens de app verzamelt, deelt en waarvoor. De coach deelt gegevens met Google (Gemini). |
| **Health apps declaration** | Verplicht formulier voor elke app. FitLog verwerkt fitness-, slaap- en alcoholgegevens. |
| **AI-gegenereerde inhoud** | De app moet gebruikers **in de app zelf**, zonder ze te verlaten, laten melden als de AI iets aanstootgevends zegt. Nodig: een meldknop bij elk antwoord van de coach (§7). |
| **Doel-API-niveau** | Nieuwe apps moeten API 36 targeten (sinds 31 augustus 2026). FitLog target al 37. |

---

## 5. België: onderneming, btw, belasting en sociale bijdragen

*Dit deel is een oriëntatie. Laat het bevestigen door een boekhouder voor je de eerste
betaalde verkoop doet.*

### 5.1 Wanneer word je een onderneming?

Zolang de coach gratis is en jij er niets aan verdient, is er niets te regelen. **Zodra je
geregeld geld ontvangt voor abonnementen**, is dat een beroepsactiviteit. Dan heb je nodig:

- een **ondernemingsnummer** in de KBO (Kruispuntbank van Ondernemingen);
- een **btw-nummer** (hetzelfde nummer, geactiveerd voor btw);
- een aansluiting bij een **sociaal verzekeringsfonds**.

Heb je een job in loondienst, dan word je **zelfstandige in bijberoep**. Ben je student,
dan bestaat er een apart statuut **student-zelfstandige**, met andere drempels. Vraag dat na
bij je sociaal verzekeringsfonds.

### 5.2 Stappen

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

### 5.3 Btw

**Vrijstellingsregeling voor kleine ondernemingen:** is je jaaromzet (zonder btw) niet hoger
dan **€25.000**, dan kan je kiezen voor de vrijstellingsregeling. Je rekent dan geen btw aan
en dient geen periodieke btw-aangiften in. Je moet wel nog een **jaarlijkse klantenlisting**
indienen, en een **jaaropgave** van je handelingen in België (uiterlijk 31 maart).

Hoe het uitdraait voor FitLog:

| Stroom | Wie rekent de btw | Wat jij doet |
|---|---|---|
| Gebruiker → Google Play (abonnement) | **Google** rekent 21% aan en draagt ze af | Niets |
| Google → jij (uitbetaling) | Jouw dienst aan Google Ireland is een dienst aan een bedrijf in een ander EU-land: **geen Belgische btw**, de btw wordt verlegd | Laat je boekhouder bepalen welke opgave nodig is (bijvoorbeeld een intracommunautaire opgave) |
| Google Cloud → jij (Gemini, Business-account) | **Verlegd**: Google rekent geen btw | Je moet de Belgische btw zelf aangeven en betalen, via een **bijzondere btw-aangifte**. Ook onder de vrijstellingsregeling. |
| Google Cloud → jij (Individual Entrepreneur-account) | Google rekent **21%** aan | Niets extra, maar je betaalt 21% meer |

Omdat je onder de vrijstellingsregeling geen btw kan terugvragen, **betaal je in beide
gevallen 21% op je Gemini-kosten**. Het verschil tussen de twee accounttypes is vooral
administratief. Beslis het samen met je boekhouder vóór je het betaalaccount aanmaakt
(§3.2).

### 5.4 Inkomstenbelasting

- Je **winst** (ontvangsten van Google min je beroepskosten) wordt belast in de
  **personenbelasting**, samen met je andere inkomsten, aan het progressieve tarief.
- **Beroepskosten** zijn onder meer: Gemini-kosten, Cloudflare, de $25 van Google Play,
  de KBO-inschrijving, de boekhouder, en eventueel een deel van je materiaal.
- **Bewaar alle overzichten en facturen.**

### 5.5 Sociale bijdragen (bijberoep, cijfers 2026)

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

### 5.6 Consumentenrecht

- De aankoop zelf verloopt via **Google Play**: Google toont de voorwaarden, rekent af en
  regelt terugbetalingen volgens zijn eigen beleid.
- Zorg toch voor **eigen gebruiksvoorwaarden**: wat het abonnement geeft, dat de coach
  geen medisch advies geeft, en wat er gebeurt als de maandlimiet bereikt is.
- **Herroepingsrecht (14 dagen)** bij digitale diensten: laat je boekhouder of een jurist
  bevestigen hoe dat samengaat met de afhandeling door Google Play.

---

## 6. Privacy (AVG) en de AI-verordening

### 6.1 Wie is wie?

| Rol | Wie |
|---|---|
| **Verwerkingsverantwoordelijke** (bepaalt waarom en hoe) | **Jij**, voor de gedeelde coach |
| **Verwerker** | **Google** (Gemini, betaalde laag, met de verwerkersovereenkomst van Google Cloud) |
| **Verwerker** | **Cloudflare** (tussenstation, met de verwerkersovereenkomst van Cloudflare) |

Bij de optie **"eigen sleutel"** ben jij geen verwerkingsverantwoordelijke voor de
gesprekken: die gaan rechtstreeks van de gebruiker naar Google.

### 6.2 Gezondheidsgegevens

Trainingen, slaap, spierpijn en alcohol liggen dicht tegen **gezondheidsgegevens** aan: een
**bijzondere categorie** in de AVG (artikel 9). Daarvoor is **uitdrukkelijke toestemming**
nodig. In de praktijk:

- de gedeelde coach staat **standaard uit**;
- bij het aanzetten een **toestemmingsscherm** dat duidelijk zegt:
  - dat je met een AI praat;
  - welke gegevens meegaan (enkel wat de coach opzoekt, nooit het hele logboek);
  - dat ze via het tussenstation naar Google gaan en daar tot 7 dagen voor misbruikcontrole
    bewaard kunnen worden;
  - dat er niets op jouw server blijft;
- **intrekken moet even makkelijk zijn**: één schakelaar in de instellingen.

### 6.3 Zo weinig mogelijk gegevens

- De coach haalt al alleen op wat hij nodig heeft, met een plafond van 40 rijen per
  opzoeking. **Zo houden.**
- **Geen naam, geen e-mail, geen telefoonnummer** meesturen. Het installatienummer is
  willekeurig.
- **Het tussenstation bewaart geen inhoud**, alleen tellers.
- **Bewaartermijn in AI Studio: 7 dagen** (§3.7). Overweeg Zero Data Retention aan te
  vragen.

### 6.4 Documenten die je nodig hebt

- [ ] **Privacyverklaring** (verplicht voor Google Play): wie je bent, welke gegevens,
  waarom, met wie gedeeld, hoe lang bewaard, welke rechten de gebruiker heeft, en hoe hij
  jou bereikt.
- [ ] **Verwerkingsregister** (artikel 30 AVG). Kleine organisaties zijn meestal
  vrijgesteld, **maar niet** als ze bijzondere categorieën verwerken. Hou er dus een bij.
- [ ] **Afweging voor een gegevensbeschermingseffectbeoordeling (DPIA)**: schrijf op
  waarom er wel of geen nodig is.
- [ ] **Verwerkersovereenkomsten** van Google Cloud en Cloudflare aanvaarden.
- [ ] **Rechten van gebruikers:** inzage en verwijdering. Omdat de server niets bewaart,
  staat alles op de gsm. Leg dat uit in de privacyverklaring.

### 6.5 Doorgifte buiten de EU

De Gemini API via AI Studio belooft geen verwerking binnen de EU. Google en Cloudflare
dekken doorgifte in hun voorwaarden (EU-VS-gegevensprivacykader en
standaardcontractbepalingen). Vermeld dit in je privacyverklaring. Voor meer zekerheid
later: Vertex AI met een Europese regio (§3.7).

### 6.6 De AI-verordening (EU AI Act)

- **Vanaf 2 augustus 2026** (artikel 50): gebruikers moeten weten dat ze met een AI praten.
  De naam **"AI-coach"** en het toestemmingsscherm dekken dat. Zet het er ook bovenaan het
  gesprek bij.
- **Gegenereerde beelden en tekst** moeten machineleesbaar herkenbaar zijn als
  AI-gegenereerd. Voor systemen die al op de markt waren, geldt daarvoor een overgang tot
  **2 december 2026**. Die plicht ligt vooral bij de aanbieder van het model. De tekeningen
  in FitLog dragen al zichtbaar het label *"getekend door AI"*.

---

## 7. Wat er in de app verandert

| Onderdeel | Wat |
|---|---|
| **Keuze van de coach** | Drie opties: *Uit* (standaard), *FitLog-coach* (gedeeld) en *Eigen sleutel* (zoals nu). |
| **Toestemmingsscherm** | Zie §6.2. Pas daarna vertrekt er iets. |
| **Installatienummer** | Willekeurig, één keer aangemaakt, alleen op de gsm. |
| **Play Integrity** | Bij elke vraag (of per korte periode) een bewijs voor het tussenstation. |
| **Het ene netwerkbestand** | Het adres van het tussenstation komt erbij als vaste, gekende host. De deurtest (`test/security/offline_test.dart`) krijgt die host erbij. |
| **Teller in de app** | "Nog 2 van 3 vragen vandaag", zoals het tussenstation het terugmeldt. |
| **Meldknop** | Bij elk antwoord van de coach: *"Meld dit antwoord"*. Stuurt alleen de tekst van dat antwoord en een reden naar het tussenstation, nooit het logboek. Het tussenstation bewaart meldingen 30 dagen zodat jij ze kan nakijken. Vermeld dit in de privacyverklaring. |
| **Abonnement** (fase 3) | Scherm met wat het geeft, de prijs, kopen en "Aankopen herstellen", via `in_app_purchase`. |
| **Limiet bereikt** | Duidelijke melding: dagelijkse limiet, of maandlimiet van FitLog bereikt. En de verwijzing naar het abonnement of de optie "eigen sleutel". |

**Technische keuzes:**

- De gedeelde coach gebruikt **dezelfde opdracht en tools** als nu. Het tussenstation geeft
  de vraag ongewijzigd door aan Gemini, dus er is geen tweede versie van de coach om te
  onderhouden.
- **Tekeningen** blijven voorlopig bij de eigen tokens (Hugging Face of Cloudflare) van de
  gebruiker. Ze kunnen later ook via het tussenstation, maar dat valt buiten dit plan.

---

## 8. Kosten en opbrengsten

**Uitgangspunten:** een actieve gebruiker stelt gemiddeld 2 vragen per dag. 5% van de
actieve gebruikers neemt een abonnement van €2,99. Gratis gebruikers gebruiken het
goedkoopste model (~$0,001 per vraag), abonnees het sterkere (~$0,003 per vraag). Een
abonnee stelt gemiddeld 5 vragen per dag.

| Actieve gebruikers | Vragen per maand | Gemini-kosten | Abonnees | Opbrengst na btw en Google |
|---|---|---|---|---|
| 10 | ~650 | ~$1 | 0–1 | €0–2 |
| 100 | ~6.500 | ~$8 | 5 | ~€10,50 |
| 1.000 | ~64.500 | ~$80 | 50 | ~€105 |

**Vaste en eenmalige kosten:**

| Wat | Bedrag |
|---|---|
| Google Play-ontwikkelaarsaccount | $25, eenmalig |
| KBO-inschrijving | €111,50, eenmalig |
| Btw-activering via het ondernemingsloket (optioneel) | ~€70 excl. btw, eenmalig |
| Cloudflare Workers | €0 (gratis plan), $5 per maand als het ooit nodig is |
| Boekhouder | Verschilt; vraag een offerte voor een klein bijberoep |

**Wat dit leert:**

- Tot een paar honderd gebruikers zijn de kosten klein: **enkele euro's per maand**.
- **Gratis vragen kosten geld voor elke gebruiker**, betaalde brengen maar €2,10 per abonnee
  op. Hou de gratis limiet dus laag (3 per dag) en op het goedkoopste model.
- De **maandlimiet op het tussenstation** (§2.5) is je verzekering: hoe het ook loopt, meer
  dan dat bedrag kan het niet kosten.

---

## 9. Stappenplan

### Fase 0 — Beslissingen (vooraf)

- [ ] Ga je naar **Google Play**? (Nodig voor Play Integrity en abonnementen.)
- [ ] Hoeveel mag de gedeelde coach **maximaal per maand** kosten? (Voorstel: €10.)
- [ ] Ga je akkoord met de **nieuwe belofte**: "geen account, en een tussenstation dat
  niets bewaart"?
- [ ] Gratis limiet en prijs van het abonnement (voorstel: 3 vragen per dag, €2,99 per
  maand).

### Fase 1 — De gedeelde coach, gratis (zonder onderneming)

- [ ] AI Studio: een testproject met betaalaccount, prepay $10 (§3.9). *Bewust kiezen:
  nog zonder onderneming.*
- [ ] Cloudflare Worker: doorsturen, daglimiet per installatienummer, maandlimiet, niets
  bewaren.
- [ ] App: keuze *Uit / FitLog-coach / Eigen sleutel*, toestemmingsscherm, teller,
  meldknop.
- [ ] Privacyverklaring op de website.
- [ ] Testen met jezelf en een paar vrienden, via de GitHub-APK. *Tijdelijk zonder Play
  Integrity: alleen voor een kleine, besloten groep, met een lage maandlimiet.*

### Fase 2 — Google Play

- [ ] Ontwikkelaarsaccount ($25), identiteitscontrole.
- [ ] Gesloten test met **12 testers, 14 dagen onafgebroken**. Begin vroeg met testers
  zoeken.
- [ ] Play Integrity aanzetten in de app en controleren op het tussenstation.
- [ ] Formulieren in Play Console: Data safety, Health apps declaration, privacyverklaring,
  inhoudsbeoordeling.
- [ ] Production access aanvragen (meestal binnen 7 dagen beoordeeld).
- [ ] Ook de GitHub-versie laten verifiëren via de Android Developer Console, vóór de
  wereldwijde verplichting in 2027.

### Fase 3 — Onderneming en abonnement

- [ ] Gesprek met een boekhouder over §5, **vóór** de eerste betaalde verkoop.
- [ ] Ondernemingsloket: KBO, btw-nummer, sociaal verzekeringsfonds.
- [ ] Nu pas het **definitieve** Cloud Billing-account voor de coach aanmaken, met het
  juiste accounttype (§3.2). Project en sleutel overzetten.
- [ ] Play Console: betaalprofiel, bankrekening, abonnement `coach_plus` (§4.6).
- [ ] App: abonnementsscherm met `in_app_purchase`.
- [ ] Tussenstation: aankoopbewijs controleren en bevestigen (binnen 3 dagen),
  abonneelimieten.
- [ ] Gebruiksvoorwaarden en de privacyverklaring bijwerken voor abonnementen.
- [ ] Lanceren.

### Fase 4 — Opvolgen (maandelijks)

- [ ] Kosten bij Google Cloud tegenover de maandlimiet.
- [ ] Meldingen van gebruikers nakijken (meldknop).
- [ ] Is de limiet te krap of te ruim? Zijn de modellen nog de beste keuze?
- [ ] Overzicht van Google Play in de boekhouding.
- [ ] Jaarlijks: API-sleutel vervangen, voorwaarden van Google en Play opnieuw lezen.

---

## 10. Risico's die je bewust aanvaardt

| Risico | Wat het afdekt |
|---|---|
| Iemand misbruikt het tussenstation | Play Integrity, limiet per installatie, harde maandlimiet |
| De sleutel lekt uit | Staat alleen als geheim in de Worker, is beperkt tot de Gemini API, jaarlijks vervangen, en er is prepay-tegoed als plafond |
| Google verandert prijzen of voorwaarden | Maandlimiet; maandelijks nakijken; de optie "eigen sleutel" blijft |
| De coach zegt iets fout of schadelijks | Het is geen medisch advies (opdracht en voorwaarden), er is een meldknop, en Google's veiligheidsfilters |
| Meer kosten dan opbrengsten | Lage gratis limiet op het goedkoopste model; de maandlimiet |
| Privacyklacht | Toestemming, zo weinig mogelijk gegevens, niets bewaren, duidelijke privacyverklaring |

## 11. Nog na te kijken door een deskundige

- [ ] **Boekhouder:** statuut (bijberoep of student-zelfstandige), btw-regeling en welke
  opgaven nodig zijn voor de uitbetalingen van Google Ireland en de facturen van Google
  Cloud, het accounttype van het Cloud Billing-account.
- [ ] **Jurist of privacyspecialist (aangeraden):** de privacyverklaring, de toestemming
  voor gezondheidsgegevens, de afweging over een DPIA, en het herroepingsrecht.

---

## Bronnen

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
