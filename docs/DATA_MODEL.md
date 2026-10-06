# Datamodel

Alles staat in één SQLCipher-database (`fitlog.db`) in de privémap van de app.
Er is geen tweede opslag: foto's staan als bestand in `photos/`, maar hun
metadata staat in de database. De bron van waarheid voor wat hieronder staat
is `lib/core/db/tables.dart` (de tabellen) en de `onUpgrade` in
`lib/core/db/database.dart` (de migraties).

## Conventies

| Conventie | Waarom |
|---|---|
| Alle id's zijn `TEXT` met een UUID v4 | Geen autoincrement die botst bij het terugzetten van een back-up. De gezaaide oefeningen gebruiken een UUID v5 (zie `docs/DECISIONS.md`). |
| Uitzondering: één rij per dag heeft de dag als id, `yyyymmdd` | `sleep_entries`, `drink_days`, `daily_vitals` en `morning_reports`. Dezelfde dag opnieuw invullen of importeren vervangt de rij in plaats van er een tweede te maken. `soreness_checks` doet hetzelfde per spier: `<spier>\|<yyyymmdd>`. |
| Geïmporteerde rijen hebben `hc:` en het id van Health Connect als id | Een tweede import vindt de rij terug in plaats van ze nog eens toe te voegen. |
| Alle tijdstippen zijn `INTEGER`, unix-millis, UTC | Eén rekentype, geen tijdzoneverrassingen in queries. Omrekenen naar lokale tijd gebeurt in de weergavelaag. |
| Alle maten zijn metrisch: kg, cm, m, seconden | De enige plek waar lb of inch bestaat, is `lib/core/formatting/formatters.dart`. |
| Enums staan als Engelse `TEXT` in de database | De labels zijn Nederlands en staan in `lib/core/db/enums.dart`; hernoemen van een label raakt de data nooit. |
| Booleans zijn `INTEGER` 0/1 met een `CHECK` | Zo maakt drift ze aan. |
| `PRAGMA foreign_keys = ON` bij elke verbinding | Wordt gezet in `applyKeyAndVerify` én in `beforeOpen`. |

## Versies

`schemaVersion` is **46**. Migratiestappen mogen alleen optellen; een kolom met
gebruikersdata verwijderen of herschrijven mag niet. Elke nieuwe kolom krijgt
een standaard die zegt wat er al waar was voor ze bestond - meestal "uit" of
"niets".

| Versie | Wat er bijkwam |
|---|---|
| 1 | Eerste release. |
| 2 | `personal_records.workout_set_id` kreeg de ontbrekende `ON DELETE SET NULL`. Dat vereist een tabelherbouw, dus de migratie zet `foreign_keys` uit, doet de herbouw in een transactie, controleert met `PRAGMA foreign_key_check` en zet ze weer aan. Verwijzingen die al dood waren, worden eenmalig leeggemaakt. |
| 3 | `app_settings.default_warmup_sets`. |
| 4 | `workout_exercises.is_pr_attempt`, `pr_target_weight_kg`, `pr_result` en `app_settings.pr_default_warmup_sets` / `pr_default_extra_attempts`. |
| 5 | `exercises.start_image_file` en `end_image_file`: de twee beelden van een eigen oefening. |
| 6 | `workouts.perceived_effort`: hoe zwaar de sessie voelde. |
| 7 | `app_settings.last_backup_at`: wanneer de laatste back-up gemaakt is. |
| 8 | `app_settings.pending_pick_kind` en `pending_pick_ref`: waar een onderbroken fotokeuze heen moest. |
| 9 | `routines.color_index` en `workouts.color_index`: de kleur van een routine, en de kopie die een sessie ervan bewaart. |
| 10 | `workout_exercises.is_unilateral` en `workout_sets.side`: één arm per keer, met links en rechts als aparte sets. |
| 11 | `workout_sets.is_skipped`: een set die je bewust oversloeg. |
| 12 | `app_settings.seed_version`: tot welke versie van de catalogus de database is bijgewerkt. |
| 13 | `routine_sets.target_distance_m` en `exercises.category_overridden`: een afstand als doel, en een type dat de gebruiker zelf koos. |
| 14 | `routines.is_favourite`: routines met een ster, voor de snelkoppelingen. |
| 15 | `app_settings.track_rpe`: per set om een RPE vragen. |
| 16 | `routines.scheduled_days`: de weekdagen waarop een routine gepland staat. |
| 17 | `app_settings.home_layout`: hoe je het startscherm schikte. |
| 18 | `progress_photos.workout_id`: de training bij een foto. |
| 19 | `custom_muscles` en `custom_equipment`: spiergroepen en materiaal van jezelf. |
| 20 | `custom_categories` en `exercises.custom_category`: eigen namen voor een manier van loggen. |
| 21 | De coach: `chat_threads`, `chat_messages`, `app_settings.anthropic_api_key` en `chat_model`. |
| 22 | `app_settings.chat_provider`: bij welke dienst de sleutel hoort. |
| 23 | `chat_messages.image_file`: een foto bij een vraag. |
| 24 | `chat_messages.requests` en `app_settings.coach_daily_limit`: hoeveel aanvragen een antwoord kostte, en je eigen daglimiet. |
| 25 | `chat_messages.proposals`: wat de coach voorstelde. |
| 26 | `app_settings.image_api_key` en `exercises.images_generated`: een token om te tekenen, en de vlag op een getekende oefening. |
| 27 | `app_settings.image_provider` en `image_account_id`: Cloudflare naast Hugging Face. |
| 28 | `app_settings.image_equipment`: materiaal mee tekenen of niet. |
| 29 | `soreness_checks`: hoe een spier aanvoelde. |
| 30 | `sleep_entries` en `app_settings.track_sleep_stages`: nachten, met hun fasen als je dat wil. |
| 31 | `drink_days` en `app_settings.track_alcohol`: glazen per dag. |
| 32 | `exercises.is_favourite`: een ster op een oefening. |
| 33 | Health Connect: `sleep_entries.source`, `body_measurements.source`, `daily_vitals`, `cardio_sessions`, `app_settings.health_connect_enabled` en `health_connect_synced_at`. |
| 34 | `workouts.health_connect_id` en `app_settings.health_connect_write_workouts`: trainingen terugschrijven naar Health Connect. |
| 35 | `morning_reports`: het ochtendrapport. |
| 36 | `app_settings.morning_report_enabled` en `morning_report_minutes`: het rapport zelf maken, op een uur. |
| 37 | `workouts.avg_heart_rate` en `max_heart_rate`: de hartslag tijdens een training. |
| 38 | `daily_vitals.resting_hr_derived`: een rusthartslag die FitLog uit de nacht berekende. |
| 39 | `daily_vitals.spo2_avg`, `spo2_min` en `steps`: zuurstof tijdens de nacht en stappen per dag. |
| 40 | `app_settings.coach_sees_profile`: leeftijd, geslacht en lengte delen met de coach. |
| 41 | `app_settings.coach_gym`: waar je traint, voor de coach. |
| 42 | `routine_folders.is_coach` en `routine_versions`: de map van de coach, en vorige versies van een routine. |
| 43 | `app_settings.progression_hints`: de hint per oefening, standaard aan. |
| 44 | Geen nieuwe kolom: elke index die het schema kent, wordt aangemaakt waar ze ontbreekt (zie Indexen). |
| 45 | `week_reviews`: wat de coach over een week schreef. |
| 46 | `app_settings.week_review_notify`: de melding van het weekoverzicht op zondagavond, standaard aan. |

**De valkuil bij een nieuwe kolom in een jongere tabel.** Een tabel die een
migratiestap aanmaakt (`m.createTable`), krijgt de definitie van vandaag, met
alle kolommen die er later bijkwamen al in. Een latere stap die zo'n kolom
toevoegt, mag dat dan alleen doen voor een database die de tabel al had: vandaar
`if (from >= 21)` bij de kolommen van `chat_messages` (v23-25), `if (from >= 30)`
bij `sleep_entries.source` (v33) en `if (from >= 33)` bij die van
`daily_vitals` (v38-39). Zonder die voorwaarde faalt de migratie met "duplicate
column".

`test/db/migration_test.dart` bouwt een echte v1-database uit
`test/db/fixtures/schema_v1.sql`, vult ze met gebruikersdata en controleert dat
openen met de huidige code migreert zonder iets te verliezen. Voor de jongere
tabellen maakt het een database van vandaag, haalt er wat later bijkwam weer
uit en zet de versie terug (v37, v39, v41): zo loopt de migratie het pad dat een
toestel met die versie loopt. Wie een kolom toevoegt, haalt ze daar ook weg.

## Tabellen

### Jijzelf en de app

#### `user_profile` (max 1 rij, id = `singleton`)

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | altijd `singleton` |
| `display_name` | TEXT? | gaat mee naar de coach |
| `birth_date` | INT? | millis, middernacht |
| `sex` | TEXT? | `male` \| `female` \| `other` \| `undisclosed` |
| `height_cm` | REAL? | |
| `created_at`, `updated_at` | INT | |

Geboortedatum, geslacht en lengte gaan alleen naar de coach met
`app_settings.coach_sees_profile` aan.

#### `app_settings` (max 1 rij, id = `singleton`)

| Kolom | Type | Standaard |
|---|---|---|
| `unit_weight` | TEXT | `kg` (\| `lb`) |
| `unit_length` | TEXT | `cm` (\| `in`) |
| `unit_distance` | TEXT | `km` (\| `mi`) |
| `theme_mode` | TEXT | `dark` (\| `system` \| `light`) |
| `locale` | TEXT | `nl` |
| `onboarding_done` | BOOL | false |
| `exercises_seeded` | BOOL | false: de catalogus is precies één keer geïmporteerd |
| `seed_version` | INT | 0: tot welke versie de catalogus is bijgewerkt |
| `auto_lock_seconds` | INT | 60 (`0` = meteen, `-1` = nooit) |
| `last_backup_at` | INT? | wanneer de laatste back-up gemaakt is |
| `pending_pick_kind`, `pending_pick_ref` | TEXT? | een fotokeuze die Android onderbrak |
| `home_layout` | TEXT? | JSON; leeg = de standaardschikking |
| **Trainen** | | |
| `default_rest_seconds` | INT | 90 |
| `rest_sound_enabled` | BOOL | true |
| `set_check_sound_enabled` | BOOL | true |
| `pr_alert_enabled` | BOOL | true |
| `default_warmup_sets` | INT | 0 (0-5, warming-ups bovenaan een nieuw toegevoegde oefening) |
| `pr_default_warmup_sets` | INT | 4 (2-8, lengte van de PR-ladder) |
| `pr_default_extra_attempts` | INT | 1 (0-3, aanbod na een geslaagde poging) |
| `track_rpe` | BOOL | false |
| `progression_hints` | BOOL | true: de hint per oefening |
| `bar_weight_kg` | REAL | 20 |
| `available_plates_kg` | TEXT | `[25,20,15,10,5,2.5,1.25]` (JSON, per kant) |
| **Herstel en gezondheid** | | |
| `track_sleep_stages` | BOOL | false |
| `track_alcohol` | BOOL | false |
| `health_connect_enabled` | BOOL | false: zonder dit vraagt de app Health Connect niets |
| `health_connect_synced_at` | INT? | einde van de laatste import |
| `health_connect_write_workouts` | BOOL | false |
| `morning_report_enabled` | BOOL | false |
| `morning_report_minutes` | INT | 420 (minuten na middernacht: 7:00) |
| `week_review_notify` | BOOL | true: het weekoverzicht op zondag om 20:00, met een melding |
| **De coach** | | |
| `anthropic_api_key` | TEXT? | de sleutel van de coach, van welke dienst ook - de naam stamt van toen Anthropic de enige was |
| `chat_provider` | TEXT? | leeg = afleiden uit de sleutel |
| `chat_model` | TEXT? | leeg = de standaard van de app |
| `coach_daily_limit` | INT? | je eigen daglimiet; leeg = die van de app |
| `coach_sees_profile` | BOOL | false |
| `coach_gym` | TEXT? | waar je traint, in je eigen woorden |
| `image_api_key` | TEXT? | token om te tekenen; leeg = er wordt nooit getekend |
| `image_provider` | TEXT? | `hugging_face` \| `cloudflare`; leeg = Hugging Face |
| `image_account_id` | TEXT? | het account bij Cloudflare |
| `image_equipment` | BOOL? | leeg = ja, materiaal mee tekenen |
| `updated_at` | INT | |

De sleutels staan hier en niet in de Keystore: hier zitten ze al achter de
sleutel van de database, en een sleutel die een terugzet overleeft, hoeft de
gebruiker niet opnieuw te zoeken.

### Oefeningen

#### `exercises`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `name` | TEXT | Engels, zoals in de zaal |
| `primary_muscle` | TEXT | Nederlands, kleine letters |
| `secondary_muscles` | TEXT | JSON-array van Nederlandse namen |
| `equipment` | TEXT? | Nederlands |
| `category` | TEXT | `barbell` \| `dumbbell` \| `machine` \| `cable` \| `bodyweight` \| `assisted_bodyweight` \| `duration` \| `cardio`; bepaalt welke kolommen een set heeft |
| `custom_category` | TEXT? | naam van een eigen categorie; verandert niets aan hoe er gelogd wordt |
| `category_overridden` | BOOL | de gebruiker koos het type zelf; een correctie van de catalogus laat het staan |
| `instructions` | TEXT? | |
| `image_asset` | TEXT? | ongebruikt; de illustraties worden opgezocht op `id` via `assets/exercises/manifest.json` |
| `start_image_file` | TEXT? | bestandsnaam in de fotomap; startpositie van een eigen oefening |
| `end_image_file` | TEXT? | bestandsnaam in de fotomap; eindpositie |
| `images_generated` | BOOL | de beelden zijn getekend, geen foto's |
| `is_custom` | BOOL | door de gebruiker gemaakt |
| `is_archived` | BOOL | verborgen, maar blijft bestaan voor de geschiedenis |
| `is_favourite` | BOOL | met een ster; de catalogus schrijft dit nooit opnieuw |
| `created_at` | INT | |

De twee beeldkolommen bewaren alleen de **bestandsnaam**, om dezelfde reden
als `progress_photos.file_name`: op iOS verandert de container-UUID bij een
update, waardoor een opgeslagen absoluut pad dood zou zijn. De bestanden staan
in dezelfde map als de voortgangsfoto's, zodat ze zonder extra code meegaan in
de back-up en door dezelfde opstartcontrole worden opgeruimd. Die controle
kijkt daarom naar alle tabellen die een bestand aanwijzen
(`progress_photos`, `exercises`, `chat_messages`): een bestand dat alleen van
een van de andere wordt aangewezen, zou anders als wees verdwijnen.

#### `custom_muscles`, `custom_equipment`

`name` (PK, kleine letters), `created_at`. Spiergroepen en materiaal die je
zelf toevoegde. Apart van de oefeningen, omdat ze moeten bestaan voor er een
oefening is die ze gebruikt.

#### `custom_categories`

`name` (PK), `base` (de ingebouwde `category` waarvoor ze staat), `created_at`.
Een eigen categorie leent het gedrag van een ingebouwde; ze kan geen nieuw
gedrag verzinnen.

### Routines

#### `routine_folders`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `name` | TEXT | |
| `sort_order` | INT | |
| `is_coach` | BOOL | de map waarin de coach routines mag aanpassen; hoogstens één |

De map van de coach wordt herkend aan `is_coach`, niet aan haar naam. Zonder
sleutel is ze verborgen, niet verwijderd.

#### `routines`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `name` | TEXT | |
| `notes` | TEXT? | |
| `folder_id` | TEXT? | → `routine_folders.id` **ON DELETE SET NULL** |
| `sort_order` | INT | |
| `color_index` | INT? | plaats in `AppColors.routinePalette` |
| `is_favourite` | BOOL | |
| `scheduled_days` | INT | weekdagen als bitmasker (`WeekdaySet`); 0 = niet gepland |
| `last_performed_at` | INT? | |
| `created_at`, `updated_at` | INT | |

Een map verwijderen laat de routines dus bestaan; ze komen op het hoofdniveau.

#### `routine_exercises`

`id`, `routine_id` → `routines.id` **CASCADE**, `exercise_id` → `exercises.id`,
`sort_order`, `rest_seconds?`, `superset_group?`, `notes?`.

#### `routine_sets`

`id`, `routine_exercise_id` → `routine_exercises.id` **CASCADE**, `sort_order`,
`set_type`, `target_reps?`, `target_weight_kg?`, `target_duration_seconds?`,
`target_distance_m?`.

#### `routine_versions`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `routine_id` | TEXT | → `routines.id` **CASCADE** |
| `saved_at` | INT | |
| `note` | TEXT? | waarom ze bewaard werd: wat de coach ging veranderen, of een terugzet |
| `content` | TEXT | JSON: naam, notitie, elke oefening en set - niet de map en de kleur |

Bewaard voor elke wijziging door de coach en voor elk terugzetten; twintig per
routine, de oudste gaan eerst.

### Trainingen

#### `workouts`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `routine_id` | TEXT? | → `routines.id` **ON DELETE SET NULL** |
| `name` | TEXT | |
| `started_at` | INT | |
| `ended_at` | INT? | **`NULL` = de lopende sessie; er kan er maar één zijn** |
| `notes` | TEXT? | |
| `total_volume_kg` | REAL | gedenormaliseerd, herberekend bij elke wijziging |
| `total_sets` | INT | aantal afgevinkte sets |
| `duration_seconds` | INT | |
| `perceived_effort` | TEXT? | `very_easy` \| `easy` \| `normal` \| `hard` \| `all_out` |
| `color_index` | INT? | kopie van de kleur van de routine |
| `health_connect_id` | TEXT? | het id in Health Connect, als FitLog ze daar schreef |
| `avg_heart_rate`, `max_heart_rate` | INT? | van een horloge, via Health Connect |

Een routine verwijderen laat de gelogde workouts staan; alleen de verwijzing
verdwijnt.

#### `workout_exercises`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `workout_id` | TEXT | → `workouts.id` **CASCADE** |
| `exercise_id` | TEXT | → `exercises.id` |
| `sort_order` | INT | |
| `rest_seconds` | INT | 90 |
| `superset_group` | INT? | |
| `notes` | TEXT? | |
| `is_unilateral` | BOOL | één kant per keer; hoort bij de sessie, niet bij de routine |
| `is_pr_attempt` | BOOL | een één-rep-max-poging met een eigen opwarmladder |
| `pr_target_weight_kg` | REAL? | het doelgewicht van die poging |
| `pr_result` | TEXT? | `success` \| `failed` \| `abandoned`, of leeg zolang ze loopt |

De PR-ladder staat niet apart opgeslagen: de opwarmrungen zijn gewone
`workout_sets` van het type `warmup` en de poging is de enige werkset. Daardoor
tellen opwarmers automatisch niet mee voor volume of records, en zijn de
rusttijden af te leiden uit de reps.

#### `workout_sets`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `workout_exercise_id` | TEXT | → `workout_exercises.id` **CASCADE** |
| `sort_order` | INT | |
| `set_type` | TEXT | `warmup` \| `normal` \| `drop` \| `failure` |
| `weight_kg` | REAL? | |
| `reps` | INT? | |
| `duration_seconds` | INT? | voor een houding en voor cardio |
| `distance_m` | REAL? | voor cardio |
| `rpe` | REAL? | |
| `side` | TEXT? | `left` \| `right` bij één kant per keer, anders leeg |
| `is_completed` | BOOL | |
| `completed_at` | INT? | |
| `is_skipped` | BOOL | bewust overgeslagen; iets anders dan nog niet gedaan |

Wat je in een set typt, wordt meteen bewaard, ook voor je ze afvinkt. Een set
uit een routine begint met het doel van die routine ingevuld.

#### `personal_records`

`id`, `exercise_id` → `exercises.id` **CASCADE**, `record_type`
(`max_weight` \| `est_1rm` \| `max_set_volume` \| `max_reps` \| `max_duration`
\| `max_distance`), `value`, `workout_set_id?` → `workout_sets.id` **ON DELETE
SET NULL**, `achieved_at`.

Er staat hoogstens één rij per (oefening, type): een nieuw record vervangt het
oude. Sets met één kant tellen niet mee. Bij het bewerken van een sessie speelt
`RecordsDao.rebuildAllRecords()` de hele geschiedenis opnieuw af; bij het
verwijderen van een workout doet `rebuildRecordsFor()` dat alleen voor de
oefeningen die erin zaten, binnen dezelfde transactie als de verwijdering.

### Lichaam

#### `body_measurements`

`id`, `measured_at`, `type`, `value`, `note?`, `source?`.

`type` is `weight` \| `body_fat` \| `neck` \| `chest` \| `waist` \| `hips` \|
`left_arm` \| `right_arm` \| `left_thigh` \| `right_thigh` \| `left_calf` \|
`right_calf`. De eenheid volgt uit het type: kg voor gewicht, procent voor
vetpercentage, centimeter voor de rest. `source` is leeg voor wat je in FitLog
invulde, anders de app die het naar Health Connect schreef; zo'n rij heeft
`hc:` en het id van Health Connect als id.

#### `progress_photos`

`id`, `taken_at`, `file_name`, `pose` (`front` \| `side` \| `back`), `note?`,
`workout_id?` → `workouts.id` **ON DELETE SET NULL**.

De bestanden staan onder `<app documents>/photos/`. Ze gaan mee in de
versleutelde back-up, niet in de camerarol. Een foto overleeft de training
waaraan ze gekoppeld is; ze zegt dan alleen niet meer welke.

### Herstel en gezondheid

#### `soreness_checks`

`id` (`<spier>|<yyyymmdd>`), `muscle`, `checked_at`, `level` (`fresh` \|
`stiff` \| `sore`). Eén antwoord per spier per dag; later dezelfde dag vervangt
het eerste.

#### `sleep_entries`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | de ochtend, `yyyymmdd` |
| `fell_asleep_at` | INT | |
| `woke_at` | INT | |
| `light_minutes`, `rem_minutes`, `deep_minutes` | INT? | leeg = niet ingevuld, iets anders dan nul |
| `source` | TEXT? | leeg = zelf ingevuld; anders de app die het naar Health Connect schreef |

Wat je zelf invult, wint: een import overschrijft nooit een nacht zonder bron,
en een geïmporteerde nacht verbeteren maakt hem van jou.

#### `drink_days`

`id` (`yyyymmdd`), `day` (middernacht), `drinks` (standaardglazen). Alleen
dagen met iets op: nul wordt niet bewaard.

#### `daily_vitals`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | de dag, `yyyymmdd` |
| `day` | INT | middernacht |
| `hrv_ms` | REAL? | RMSSD, gemiddelde van de dag |
| `resting_hr` | REAL? | slagen per minuut, de laagste van de dag |
| `resting_hr_derived` | BOOL | door FitLog berekend uit de nacht; een waarde van het horloge vervangt ze, nooit omgekeerd |
| `spo2_avg`, `spo2_min` | REAL? | zuurstof tijdens de nacht die die ochtend eindigde, in procent |
| `steps` | INT? | stappen die dag, zoals Health Connect ze over alle apps samen telt |

#### `cardio_sessions`

`id` (`hc:` en het id van Health Connect), `started_at`, `ended_at`, `kind`
(`running` \| `cycling`), `source?`. Geen training in FitLog-zin, maar ze telt
mee in de herstelschatting.

#### `morning_reports`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | de dag, `yyyymmdd` |
| `created_at` | INT | |
| `facts` | TEXT | JSON: de nacht, de score, HRV en rusthartslag, de spieren die nog herstellen - zoals ze die ochtend waren |
| `coach_text` | TEXT? | wat de coach schreef |
| `coach_error` | TEXT? | waarom er geen tekst is terwijl de coach aan staat |
| `import_error` | TEXT? | waarom Health Connect net ervoor niet gelezen kon worden |
| `requests`, `input_tokens`, `output_tokens` | INT? | wat de vraag aan de coach kostte |

#### `week_reviews`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | de maandag van de week, `yyyymmdd` |
| `week_start` | INT | die maandag, middernacht |
| `created_at` | INT | |
| `facts` | TEXT | JSON: de cijfers van de week zoals ze toen waren |
| `coach_text` | TEXT? | wat de coach schreef |
| `coach_error` | TEXT? | waarom er geen tekst is terwijl de coach aan staat |
| `requests`, `input_tokens`, `output_tokens` | INT? | wat de vraag aan de coach kostte |

Elke week krijgt een rij zodra haar overzicht gemaakt is, ook zonder coach:
zo weet de app dat het niet opnieuw moet. De cijfers op het scherm worden
telkens opnieuw berekend; alleen de tekst van de coach komt hier vandaan.

### De coach

#### `chat_threads`

`id`, `title` (je eerste vraag, ingekort), `created_at`, `updated_at`.

#### `chat_messages`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `thread_id` | TEXT | → `chat_threads.id` **CASCADE** |
| `role` | TEXT | `user` \| `assistant` |
| `content` | TEXT | |
| `lookups` | TEXT? | JSON-array: wat de coach opzocht, in leesbare zinnen |
| `image_file` | TEXT? | bestandsnaam van een meegestuurde foto, in de fotomap |
| `proposals` | TEXT? | JSON: kaarten bij het antwoord - een voorstel met een knop, of een routine die de coach maakte of aanpaste |
| `requests` | INT? | hoeveel aanvragen het antwoord kostte |
| `input_tokens`, `output_tokens` | INT? | |
| `created_at` | INT | |

## Indexen

| Index | Kolommen |
|---|---|
| `idx_workouts_started_at` | `workouts(started_at)` |
| `idx_workout_exercises_workout` | `workout_exercises(workout_id)` |
| `idx_workout_exercises_exercise` | `workout_exercises(exercise_id)` |
| `idx_workout_sets_workout_exercise` | `workout_sets(workout_exercise_id)` |
| `idx_personal_records_exercise_type` | `personal_records(exercise_id, record_type)` |
| `idx_body_measurements_type_date` | `body_measurements(type, measured_at)` |
| `idx_progress_photos_taken_at` | `progress_photos(taken_at)` |
| `idx_routine_exercises_routine` | `routine_exercises(routine_id)` |
| `idx_routine_sets_routine_exercise` | `routine_sets(routine_exercise_id)` |
| `idx_routine_versions_routine` | `routine_versions(routine_id)` |
| `idx_soreness_checked_at` | `soreness_checks(checked_at)` |
| `idx_sleep_woke_at` | `sleep_entries(woke_at)` |
| `idx_cardio_started_at` | `cardio_sessions(started_at)` |

SQLite gebruikt een index in beide richtingen, dus `started_at DESC` wordt
bediend door een gewone index op `started_at`.

Een migratie die een tabel met een index aanmaakt, moet die index zelf aanmaken
(`m.createIndex`): drift's `createTable` doet dat niet, alleen `createAll` bij
een nieuwe installatie. Bij `soreness_checks` (v29), `sleep_entries` (v30) en
`cardio_sessions` (v33) is dat niet gebeurd, zodat een database die van voor
die versies migreerde `idx_soreness_checked_at`, `idx_sleep_woke_at` en
`idx_cardio_started_at` miste. Versie 44 maakt elke index die het schema kent
aan met `CREATE INDEX IF NOT EXISTS`, en een test vergelijkt de indexen van een
gemigreerde v1-database met die van een nieuwe: zo'n vergeten index valt
voortaan meteen op.

## Relaties in één blik

```
routine_folders 1─┐ (SET NULL)
                  └─* routines 1─* routine_exercises 1─* routine_sets
                        │   └─* routine_versions
                        │ (SET NULL)
                        └─* workouts 1─* workout_exercises 1─* workout_sets
                              │               │                     │
                              │         exercises ─────────────┐    │
                              │               │                │    │
                              │               └─* personal_records ─┘
                              │                     (workout_set_id, SET NULL)
                              └─* progress_photos (SET NULL)

chat_threads 1─* chat_messages

Los, één rij of één rij per dag:
user_profile  app_settings  body_measurements  custom_muscles
custom_equipment  custom_categories  soreness_checks  sleep_entries
drink_days  daily_vitals  cardio_sessions  morning_reports  week_reviews
```
