import 'package:drift/drift.dart' show Value;

import '../../../core/db/database.dart';
import 'health_importer.dart';
import 'health_source.dart';

/// How far back the first import reaches. Health Connect itself only hands
/// an app the month before it was granted access, unless it asks for more.
const Duration kFirstImportReach = Duration(days: 30);

/// How far before the last import the next one starts again. A watch often
/// hands its night over hours later, when it next meets the phone.
const Duration kImportOverlap = Duration(days: 2);

/// Imports at most this often on their own. Pressing the button always does.
const Duration kImportInterval = Duration(minutes: 15);

/// How far back sessions are written when writing is switched on - the same
/// month the first import reaches. Older ones stay in FitLog only.
const Duration kWriteReach = Duration(days: 30);

/// How long one write may take before FitLog stops waiting. It runs right
/// after finishing a session, and must never hold that up.
const Duration kWriteTimeout = Duration(seconds: 5);

/// One import from Health Connect, and writing sessions back to it, with no
/// screen attached.
///
/// The screen's [HealthSync] drives this while the app is open; the morning
/// report drives it on its own, early, while nobody is looking.
class HealthImport {
  HealthImport(this.db, this.source);

  final AppDatabase db;
  final HealthSource source;

  /// The stretch the next import should ask for, or null when there is
  /// nothing to do: Health Connect was never connected, or - unless [force] -
  /// the last import was only minutes ago.
  Future<({DateTime from, DateTime to})?> due({
    required DateTime now,
    bool force = false,
  }) async {
    final settings = await db.settingsDao.getSettings();
    if (!settings.healthConnectEnabled) return null;

    final last = settings.healthConnectSyncedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(settings.healthConnectSyncedAt!);
    if (!force && last != null && now.difference(last) < kImportInterval) {
      return null;
    }

    final earliest = now.subtract(kFirstImportReach);
    var from = last == null ? earliest : last.subtract(kImportOverlap);
    if (from.isBefore(earliest)) from = earliest;
    return (from: DateTime(from.year, from.month, from.day), to: now);
  }

  /// Reads that stretch, stores it, and remembers when.
  Future<ImportSummary> fetch({
    required DateTime from,
    required DateTime to,
  }) async {
    final snapshot = await source.read(from: from, to: to);
    final summary = await HealthImporter(db).apply(snapshot);
    await db.settingsDao.updateSettings(
      AppSettingsTableCompanion(
        healthConnectSyncedAt: Value(to.millisecondsSinceEpoch),
      ),
    );
    return summary;
  }

  /// [due] and [fetch] in one go. Null when there was nothing to do.
  Future<ImportSummary?> run({
    required DateTime now,
    bool force = false,
  }) async {
    final window = await due(now: now, force: force);
    if (window == null) return null;
    return fetch(from: window.from, to: window.to);
  }

  /// Writes every finished session of the last month that is not in Health
  /// Connect yet, and returns how many it wrote. Nothing unless writing is
  /// switched on. Throws when Health Connect does.
  Future<int> writeWorkouts({required DateTime now}) async {
    final settings = await db.settingsDao.getSettings();
    if (!settings.healthConnectEnabled ||
        !settings.healthConnectWriteWorkouts) {
      return 0;
    }

    var written = 0;
    for (final workout in await db.healthDao.workoutsToWrite(
      now.subtract(kWriteReach),
    )) {
      final id = await source
          .writeWorkout(
            start: DateTime.fromMillisecondsSinceEpoch(workout.startedAt),
            end: DateTime.fromMillisecondsSinceEpoch(workout.endedAt!),
            title: workout.name,
          )
          .timeout(kWriteTimeout);
      if (id == null) continue;
      await db.healthDao.markWritten(workout.id, id);
      written++;
    }
    return written;
  }
}
