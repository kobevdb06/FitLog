# FitLog op een iPhone

Dit project wordt op Windows ontwikkeld. Een iOS-build heeft een Mac nodig, en
die staat hier niet — dus draait hij op een Mac van GitHub.
`.github/workflows/ios.yml` bouwt de app en hangt het resultaat als
downloadbaar bestand aan de workflow-run.

De Android-kant staat los hiervan; die wordt lokaal gebouwd en als release
gepubliceerd. Zie de README.

## De build starten

Hij draait vanzelf bij elke push naar `main`. Met de hand:

1. Ga naar het tabblad **Actions** in de repository.
2. Kies links de workflow **iOS**.
3. **Run workflow** → branch `main` → **Run workflow**.

Reken op tien tot twintig minuten voor een build zonder cache, daarna minder.

## Het bestand ophalen

Open de klaar gelopen run en scrol naar **Artifacts**. Daar staat
`fitlog-ios-unsigned-<versie>` met een `.ipa` erin. GitHub pakt het in als zip,
dus je downloadt een zip met de `.ipa` erin.

Artifacts blijven **30 dagen** staan; daarna verdwijnen ze en moet je opnieuw
bouwen.

## Wat dat bestand is, en wat niet

De `.ipa` uit de eerste job is **niet ondertekend**. iOS installeert dat niet
uit zichzelf: elk programma op een iPhone moet ondertekend zijn door iemand die
Apple kent. Een sideload-programma doet dat voor je, met je eigen Apple ID, op
het moment van installeren.

## Installeren met een gratis Apple ID

Twee programma's doen dit; beide draaien op je pc en hebben je iPhone aan een
kabel nodig.

**Sideloadly** (Windows en macOS) — sleep de `.ipa` erin, vul je Apple ID in,
druk op Start. iTunes of de Apple Devices-app moet geïnstalleerd zijn zodat
Windows je toestel herkent.

**AltStore** (Windows en macOS) — installeert een winkeltje op je iPhone dat de
app zelf kan bijwerken zolang je pc in hetzelfde netwerk zit.

Na de installatie moet je de ontwikkelaar nog vertrouwen:
**Instellingen → Algemeen → VPN en apparaatbeheer** → jouw Apple ID →
**Vertrouwen**.

### De zeven dagen

Een gratis Apple ID ondertekent voor **zeven dagen**. Daarna start de app niet
meer en moet je hem opnieuw ondertekenen — de app zelf en je gegevens blijven
staan, het is de handtekening die verloopt. AltStore kan dat automatisch doen
zolang je pc bereikbaar is; met Sideloadly doe je het met de hand.

Verder geldt bij een gratis account:

- maximaal **drie** apps tegelijk van dezelfde Apple ID
- maximaal **tien** app-id's per week

## Met een Developer Program-account

Kost 99 dollar per jaar en verandert dit:

- De handtekening geldt **een jaar** in plaats van zeven dagen.
- Je kunt tot honderd toestellen op een profiel zetten en het bestand
  rechtstreeks doorgeven aan wie je wil, zonder dat zij een pc nodig hebben.
- TestFlight komt beschikbaar: tot tienduizend testers, installeren zonder
  kabel, updates zonder opnieuw ondertekenen.
- Publiceren in de App Store wordt mogelijk.

Dan kun je de tweede job in de workflow aanzetten, die de `.ipa` meteen
ondertekend aflevert.

### De ondertekende build aanzetten

Onder **Settings → Secrets and variables → Actions**:

Bij **Variables**:

| Naam | Waarde |
|---|---|
| `IOS_SIGNING` | `true` |

Bij **Secrets**:

| Naam | Wat het is |
|---|---|
| `IOS_CERTIFICATE_BASE64` | Je ondertekeningscertificaat als `.p12`, base64-gecodeerd |
| `IOS_CERTIFICATE_PASSWORD` | Het wachtwoord dat je bij het exporteren van die `.p12` koos |
| `IOS_PROVISIONING_PROFILE_BASE64` | Het `.mobileprovision` voor `be.fitlog.app`, base64-gecodeerd |
| `APPLE_TEAM_ID` | De tien tekens onder Membership details in je developer-account |

Coderen doe je zo:

```bash
base64 -i certificaat.p12 | pbcopy
base64 -i profiel.mobileprovision | pbcopy
```

`ios/ExportOptions.plist` staat in de repository met `__TEAM_ID__` als
plaatshouder; de workflow vult daar je echte team-id in. Er staat dus nergens
een identifier van je in de code.

Staat er `development` als methode. Wil je breder verspreiden binnen je eigen
kring, zet dat op `ad-hoc`; voor de App Store op `app-store`. Elk daarvan
vraagt een profiel van dezelfde soort.

## Wat er nooit gedraaid heeft

**Deze app is nog nooit op een iPhone uitgevoerd.** Alles is op Windows gebouwd
en op Android getest. De workflow bewijst dat het project compileert voor iOS,
niet dat het zich er goed gedraagt. Dingen om als eerste na te lopen:

- Face ID en de pincodevergrendeling (`local_auth`)
- de versleutelde database (SQLCipher via `package:sqlite3`)
- meldingen, en de aflopende teller tijdens een workout
- foto's kiezen en de camera voor de QR-scanner
- back-up maken en terugzetten via het deelvenster

Zie ook `NOT_VERIFIED.md`.

## Instellingen die vastliggen

| Wat | Waarde | Waar |
|---|---|---|
| Bundle-id | `be.fitlog.app` | `ios/Runner.xcodeproj/project.pbxproj` |
| Minimum iOS | 15.0 | idem, en `ios/Podfile` |
| Flutter | 3.47.2 | vastgezet in de workflow |
| Scheme | `Runner` | `ios/Runner.xcodeproj/xcshareddata/xcschemes/` |

15.0 ligt ruim boven wat de plugins vragen; de hoogste eis is 13.0
(`image_picker_ios`, `flutter_local_notifications`,
`flutter_secure_storage_darwin`, `local_auth_darwin`). De `Podfile` trekt elke
pod naar 15.0, zodat er niet één op zijn eigen lagere minimum blijft staan.

`ios/Podfile.lock` staat nog niet in de repository, omdat CocoaPods niet op
Windows draait. Na de eerste geslaagde build kun je hem uit de logs of van een
Mac overnemen en meecommitten; dan liggen ook de pod-versies vast.
