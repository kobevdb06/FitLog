# Datamodel

Alles staat in één SQLCipher-database (`fitlog.db`) in de privémap van de app.
Er is geen tweede opslag: foto's staan als bestand in `photos/`, maar hun
metadata staat in de database.

## Conventies

| Conventie | Waarom |
|---|---|
| Alle id's zijn `TEXT` met een UUID v4 | Geen autoincrement die botst bij het terugzetten van een back-up. De gezaaide oefeningen gebruiken een UUID v5 (zie `docs/DECISIONS.md`). |
| Alle tijdstippen zijn `INTEGER`, unix-millis, UTC | Eén rekentype, geen tijdzoneverrassingen in queries. Omrekenen naar lokale tijd gebeurt in de weergavelaag. |
| Alle maten zijn metrisch: kg, cm, m, seconden | De enige plek waar lb of inch bestaat, is `lib/core/formatting/formatters.dart`. |
| Enums staan als Engelse `TEXT` in de database | De labels zijn Nederlands en staan in `lib/core/db/enums.dart`; hernoemen van een label raakt de data nooit. |
| `PRAGMA foreign_keys = ON` bij elke verbinding | Wordt gezet in `applyKeyAndVerify` én in `beforeOpen`. |

`schemaVersion` is 1. De `MigrationStrategy` staat er al met een lege
`onUpgrade`; latere stappen mogen alleen optellen (nieuwe tabellen, nieuwe
nullable kolommen, nieuwe indexen). Een kolom met gebruikersdata verwijderen of
herschrijven mag niet.

## Tabellen

### `user_profile` (max 1 rij, id = `singleton`)

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | altijd `singleton` |
| `display_name` | TEXT? | |
| `birth_date` | INT? | millis |
| `sex` | TEXT? | `male` \| `female` \| `other` \| `undisclosed` |
| `height_cm` | REAL? | |
| `created_at`, `updated_at` | INT | |

### `app_settings` (max 1 rij, id = `singleton`)

| Kolom | Type | Standaard |
|---|---|---|
| `unit_weight` | TEXT | `kg` |
| `unit_length` | TEXT | `cm` |
| `unit_distance` | TEXT | `km` |
| `default_rest_seconds` | INT | 90 |
| `rest_sound_enabled` | BOOL | true |
| `set_check_sound_enabled` | BOOL | true |
| `pr_alert_enabled` | BOOL | true |
| `theme_mode` | TEXT | `dark` |
| `locale` | TEXT | `nl` |
| `onboarding_done` | BOOL | false |
| `exercises_seeded` | BOOL | false |
| `bar_weight_kg` | REAL | 20 |
| `available_plates_kg` | TEXT | `[25,20,15,10,5,2.5,1.25]` (JSON) |
| `auto_lock_seconds` | INT | 60 (`0` = meteen, `-1` = nooit) |
| `updated_at` | INT | |

`exercises_seeded` is de vlag die ervoor zorgt dat de oefeningencatalogus
precies één keer geïmporteerd wordt.

### `exercises`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `name` | TEXT | Engels, zoals in de zaal |
| `primary_muscle` | TEXT | Nederlands |
| `secondary_muscles` | TEXT | JSON-array van Nederlandse namen |
| `equipment` | TEXT? | Nederlands |
| `category` | TEXT | `barbell` \| `dumbbell` \| `machine` \| `cable` \| `bodyweight` \| `assisted_bodyweight` \| `duration` \| `cardio` |
| `instructions` | TEXT? | |
| `image_asset` | TEXT? | ongebruikt in de MVP; afbeeldingen zitten niet in de bundel |
| `is_custom` | BOOL | door de gebruiker gemaakt |
| `is_archived` | BOOL | verborgen, maar blijft bestaan voor de geschiedenis |
| `created_at` | INT | |

### `routine_folders`

`id`, `name`, `sort_order`.

### `routines`

`id`, `name`, `notes?`, `folder_id?` → `routine_folders.id` **ON DELETE SET
NULL**, `sort_order`, `created_at`, `updated_at`, `last_performed_at?`.

Een map verwijderen laat de routines dus bestaan; ze komen op het hoofdniveau.

### `routine_exercises`

`id`, `routine_id` → `routines.id` **CASCADE**, `exercise_id` → `exercises.id`,
`sort_order`, `rest_seconds?`, `superset_group?`, `notes?`.

### `routine_sets`

`id`, `routine_exercise_id` → `routine_exercises.id` **CASCADE**, `sort_order`,
`set_type`, `target_reps?`, `target_weight_kg?`, `target_duration_seconds?`.

### `workouts`

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

Een routine verwijderen laat de gelogde workouts staan; alleen de verwijzing
verdwijnt.

### `workout_exercises`

`id`, `workout_id` → `workouts.id` **CASCADE**, `exercise_id` → `exercises.id`,
`sort_order`, `rest_seconds`, `superset_group?`, `notes?`.

### `workout_sets`

| Kolom | Type | Opmerking |
|---|---|---|
| `id` | TEXT PK | |
| `workout_exercise_id` | TEXT | → `workout_exercises.id` **CASCADE** |
| `sort_order` | INT | |
| `set_type` | TEXT | `warmup` \| `normal` \| `drop` \| `failure` |
| `weight_kg` | REAL? | |
| `reps` | INT? | |
| `duration_seconds` | INT? | klaar voor cardio |
| `distance_m` | REAL? | klaar voor cardio |
| `rpe` | REAL? | |
| `is_completed` | BOOL | |
| `completed_at` | INT? | |

### `personal_records`

`id`, `exercise_id` → `exercises.id` **CASCADE**, `record_type`
(`max_weight` \| `est_1rm` \| `max_set_volume` \| `max_reps`), `value`,
`workout_set_id?`, `achieved_at`.

Er staat hoogstens één rij per (oefening, type): een nieuw record vervangt het
oude. `RecordsDao.rebuildAllRecords()` speelt de hele geschiedenis opnieuw af
wanneer een sessie bewerkt of verwijderd wordt.

### `body_measurements`

`id`, `measured_at`, `type`, `value`, `note?`.

`type` is `weight` \| `body_fat` \| `neck` \| `chest` \| `waist` \| `hips` \|
`left_arm` \| `right_arm` \| `left_thigh` \| `right_thigh` \| `left_calf` \|
`right_calf`. De eenheid volgt uit het type: kg voor gewicht, procent voor
vetpercentage, centimeter voor de rest.

### `progress_photos`

`id`, `taken_at`, `file_name`, `pose` (`front` \| `side` \| `back`), `note?`.

De bestanden staan onder `<app documents>/photos/`. Ze gaan mee in de
versleutelde back-up, niet in de camerarol.

## Indexen

| Index | Kolommen |
|---|---|
| `idx_workout_sets_workout_exercise` | `workout_sets(workout_exercise_id)` |
| `idx_workout_exercises_workout` | `workout_exercises(workout_id)` |
| `idx_workout_exercises_exercise` | `workout_exercises(exercise_id)` |
| `idx_workouts_started_at` | `workouts(started_at)` |
| `idx_personal_records_exercise_type` | `personal_records(exercise_id, record_type)` |
| `idx_body_measurements_type_date` | `body_measurements(type, measured_at)` |
| `idx_routine_exercises_routine` | `routine_exercises(routine_id)` |
| `idx_routine_sets_routine_exercise` | `routine_sets(routine_exercise_id)` |
| `idx_progress_photos_taken_at` | `progress_photos(taken_at)` |

SQLite gebruikt een index in beide richtingen, dus `started_at DESC` uit de
opdracht wordt bediend door een gewone index op `started_at`.

## Relaties in één blik

```
routine_folders 1─┐ (SET NULL)
                  └─* routines 1─* routine_exercises 1─* routine_sets
                        │ (SET NULL)
                        └─* workouts 1─* workout_exercises 1─* workout_sets
                                              │                     │
                                        exercises ─────────────┐    │
                                              │                │    │
                                              └─* personal_records ─┘
                                                    (workout_set_id)

user_profile   app_settings   body_measurements   progress_photos
   (1 rij)        (1 rij)        (los)                (los)
```

## Klaar voor later

`workout_sets` heeft al `duration_seconds` en `distance_m`, en
`ExerciseCategory` kent al `duration` en `cardio`. Een cardiomodule kan die
kolommen gebruiken zonder migratie. Een voedingsmodule zou nieuwe tabellen
toevoegen naast de bestaande, zonder er een aan te raken.
