# Wat er niet aangetoond is

De rest van de oplevering is groen. Dit staat er niet, en dit is waarom.

## De iOS-build is niet uitgevoerd

`flutter build ios --release --no-codesign` vereist macOS en Xcode. Deze build
is volledig op Windows gemaakt. Het subcommando bestaat daar niet eens:

```
$ flutter build ios
Could not find a subcommand named "ios" for "flutter build".
```

Wat er wél in orde is gebracht:

- `ios/Runner/Info.plist` heeft `NSFaceIDUsageDescription`,
  `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` en
  `NSPhotoLibraryAddUsageDescription`, alle vier met Nederlandse teksten, plus
  een `CFBundleDisplayName` van `FitLog`.
- `PRODUCT_BUNDLE_IDENTIFIER` staat op `be.fitlog.app`.
- Het deployment target is 15.0 (zie `docs/DECISIONS.md`, punt 6: Flutter 3.47
  ondersteunt iOS 14 niet meer).

Wat er nog moet gebeuren op een Mac:

1. `flutter pub get` en `dart run build_runner build`.
2. `cd ios && pod install`. De `Podfile` wordt daarbij aangemaakt; hij staat niet
   in de repository omdat CocoaPods niet op Windows draait. Zet daarna in de
   `Podfile` `platform :ios, '15.0'`.
3. `flutter build ios --release --no-codesign`.

Het risico zit bij de native onderdelen: `package:sqlite3` met
`source: sqlcipher` haalt een SQLCipher-build voor iOS op via zijn build hook,
en `local_auth`, `flutter_secure_storage`, `image_picker`,
`flutter_local_notifications` en `wakelock_plus` hebben elk een iOS-kant. Dat
zijn allemaal onderhouden pakketten met iOS-ondersteuning, maar "hoort te
werken" is geen "is gebouwd".

## De app is niet op een echt toestel gedraaid

Er was geen Android-toestel of emulator beschikbaar in deze omgeving. Wat wel is
aangetoond:

- `flutter analyze`: 0 issues.
- `flutter test`: 182 tests groen, waaronder widget tests die het
  actieve-workout-scherm echt opbouwen, een set afvinken en de rusttimer zien
  starten, en een integratietest die een routine maakt, een workout logt,
  afrondt en geschiedenis plus records controleert.
- SQLCipher is echt actief (`PRAGMA cipher_version` = `4.18.0 community`), een
  bestand geschreven met een sleutel is onleesbaar zonder die sleutel, en de
  verkeerde sleutel geeft een getypeerde fout.

Wat daarmee **niet** aangetoond is:

- De koudstarttijd onder de 2 seconden op een middenklasse toestel. Dat is een
  meting op hardware; er is wel bewust naartoe gewerkt (geen splash-animatie, de
  seeding draait in één transactie en maar één keer, Argon2id draait in een
  aparte isolate zodat het vergrendelscherm niet blokkeert).
- Biometrie via `local_auth`. Het pad is er, `MainActivity` erft van
  `FlutterFragmentActivity` zoals vereist, maar er is geen vingerafdruksensor om
  het op te proberen.
- De lokale meldingen van de rusttimer, en het gedrag van
  `SCHEDULE_EXACT_ALARM` op Android 14+. De in-app countdown werkt los daarvan:
  die rekent uit een tijdstempel en is wel getest.
- Haptiek en systeemgeluiden.
- De camera en de galerij voor voortgangsfoto's.
- Het deelmenu van het systeem voor back-up en CSV-export.
