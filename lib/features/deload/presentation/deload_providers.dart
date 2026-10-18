import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/deload.dart';
import '../../../core/calc/progression.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../history/presentation/history_providers.dart';
import '../data/deload_standing.dart';

part 'deload_providers.g.dart';

/// The deload going on now, or the next one planned; null without either.
@Riverpod(keepAlive: true)
Stream<DeloadWeekRow?> currentDeload(Ref ref) =>
    ref.watch(databaseProvider).deloadDao.watchAll().map((rows) {
      final now = DateTime.now();
      for (final row in rows) {
        if (row.isOnAt(now) || row.isAheadAt(now)) return row;
      }
      return null;
    });

/// Why Start proposes a deload now, or null: switched off, put away with
/// Later, one going or planned, or simply not time.
@riverpod
Future<DeloadReason?> deloadSuggestion(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final settings = ref.watch(settingsProvider).value;
  // Again when a deload starts or stops, and when a session is finished.
  ref.watch(currentDeloadProvider);
  ref.watch(finishedWorkoutDatesProvider);
  if (settings == null || !settings.deloadSuggest) return null;

  final now = DateTime.now();
  final snoozed = settings.deloadSnoozedUntil;
  if (snoozed != null && now.millisecondsSinceEpoch < snoozed) return null;
  if (await db.deloadDao.currentAt(now) != null) return null;

  final standing = await deloadStanding(db, now: now);
  return deloadDue(
    weeks: standing.weeks,
    stalled: standing.stalled,
    weeksLimit: settings.deloadSuggestWeeks,
    stalledLimit: settings.deloadSuggestStalled,
  );
}

/// What a deload does, shown on an exercise you did last time.
class DeloadExample {
  const DeloadExample({
    required this.name,
    required this.sets,
    required this.weightKg,
    required this.reps,
    required this.stepKg,
  });

  final String name;
  final int sets;
  final double weightKg;
  final int reps;
  final double stepKg;
}

@riverpod
Future<DeloadExample?> deloadExample(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final found = await db.workoutsDao.lastOrdinaryExample();
  if (found == null) return null;
  final settings = await db.settingsDao.getSettings();
  return DeloadExample(
    name: found.name,
    sets: found.sets,
    weightKg: found.weightKg,
    reps: found.reps,
    stepKg:
        await db.workoutsDao.learnedStepFor(found.exerciseId) ??
        defaultWeightStep(
          found.category,
          platesKg: decodePlates(settings.availablePlatesKg),
        ),
  );
}

/// Later: the proposal away for the days the settings say.
Future<void> snoozeDeloadSuggestion(AppDatabase db, {DateTime? now}) async {
  final settings = await db.settingsDao.getSettings();
  final at = now ?? DateTime.now();
  await db.settingsDao.updateSettings(
    AppSettingsTableCompanion(
      deloadSnoozedUntil: Value(
        DateTime(
          at.year,
          at.month,
          at.day + settings.deloadLaterDays,
        ).millisecondsSinceEpoch,
      ),
    ),
  );
}

/// Melding dempen: no more proposals until switched on again in the
/// settings.
Future<void> muteDeloadSuggestion(AppDatabase db) =>
    db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(deloadSuggest: Value(false)),
    );
