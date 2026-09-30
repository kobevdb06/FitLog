import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/app/app_state.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../data/health_connect_source.dart';
import '../data/health_importer.dart';
import '../data/health_source.dart';

part 'health_providers.g.dart';

/// Where Health Connect is reached. Overridden in tests with one that
/// answers from memory.
@Riverpod(keepAlive: true)
HealthSource healthSource(Ref ref) => HealthConnectSource();

/// Whether Health Connect is on this phone and usable.
@riverpod
Future<HealthAvailability> healthAvailability(Ref ref) =>
    ref.watch(healthSourceProvider).availability();

/// Whether the user connected it.
@riverpod
bool healthConnectEnabled(Ref ref) =>
    ref.watch(settingsProvider).value?.healthConnectEnabled ?? false;

/// Whether finished sessions are written to it as well.
@riverpod
bool healthConnectWritesWorkouts(Ref ref) {
  final settings = ref.watch(settingsProvider).value;
  return (settings?.healthConnectEnabled ?? false) &&
      (settings?.healthConnectWriteWorkouts ?? false);
}

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

class HealthSyncState {
  const HealthSyncState({this.busy = false, this.summary, this.error});

  final bool busy;

  /// What the last import in this session brought in.
  final ImportSummary? summary;
  final String? error;
}

/// Connecting, importing and disconnecting.
@Riverpod(keepAlive: true)
class HealthSync extends _$HealthSync {
  @override
  HealthSyncState build() => const HealthSyncState();

  bool get _appOpen => ref.read(appControllerProvider) is AppReady;

  /// Asks Health Connect for access and, when given, imports the last month.
  Future<bool> connect() async {
    final source = ref.read(healthSourceProvider);
    state = const HealthSyncState(busy: true);
    try {
      final granted = await source.requestAccess();
      if (!granted) {
        state = const HealthSyncState(
          error:
              'Health Connect gaf FitLog geen toegang. Je kan het opnieuw '
              'proberen, en per gegeven kiezen wat je deelt.',
        );
        return false;
      }
      await ref
          .read(databaseProvider)
          .settingsDao
          .updateSettings(
            const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
          );
      state = const HealthSyncState();
      await sync(force: true);
      return true;
    } on Object catch (error) {
      state = HealthSyncState(error: 'Verbinden lukte niet: $error');
      return false;
    }
  }

  /// Imports what is new since the last time.
  ///
  /// Does nothing when the app is locked, when Health Connect was never
  /// connected, or - unless [force] - when the last import was only minutes
  /// ago. Safe to call from anywhere, as often as you like.
  Future<void> sync({bool force = false, DateTime? now}) async {
    if (!_appOpen || state.busy) return;
    final db = ref.read(databaseProvider);
    // Straight from the database: the settings stream may have nobody
    // listening, and then it answers "still loading" (DECISIONS 130).
    final settings = await db.settingsDao.getSettings();
    if (!settings.healthConnectEnabled) return;

    final moment = now ?? DateTime.now();
    final last = settings.healthConnectSyncedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(settings.healthConnectSyncedAt!);
    if (!force && last != null && moment.difference(last) < kImportInterval) {
      return;
    }

    final earliest = moment.subtract(kFirstImportReach);
    var from = last == null ? earliest : last.subtract(kImportOverlap);
    if (from.isBefore(earliest)) from = earliest;
    from = DateTime(from.year, from.month, from.day);

    state = HealthSyncState(busy: true, summary: state.summary);
    try {
      final snapshot = await ref
          .read(healthSourceProvider)
          .read(from: from, to: moment);
      final summary = await HealthImporter(db).apply(snapshot);
      await db.settingsDao.updateSettings(
        AppSettingsTableCompanion(
          healthConnectSyncedAt: Value(moment.millisecondsSinceEpoch),
        ),
      );
      state = HealthSyncState(summary: summary);
    } on Object catch (error) {
      state = HealthSyncState(
        summary: state.summary,
        error: 'Ophalen uit Health Connect lukte niet: $error',
      );
    }
    // And the other way: a session a failed write left behind gets another
    // chance here.
    await writeWorkouts(now: moment);
  }

  /// Asks for permission to write sessions and, when given, switches it on
  /// and writes the last month's.
  Future<bool> startWriting() async {
    final source = ref.read(healthSourceProvider);
    try {
      final granted = await source.requestWriteAccess();
      if (!granted) {
        state = HealthSyncState(
          summary: state.summary,
          error:
              'Health Connect gaf FitLog geen toestemming om trainingen te '
              'schrijven.',
        );
        return false;
      }
    } on Object catch (error) {
      state = HealthSyncState(
        summary: state.summary,
        error: 'Toestemming vragen lukte niet: $error',
      );
      return false;
    }
    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          const AppSettingsTableCompanion(
            healthConnectWriteWorkouts: Value(true),
          ),
        );
    await writeWorkouts();
    return true;
  }

  /// Stops writing new sessions. What was written stays in Health Connect:
  /// those are your sessions, wherever you look at them.
  Future<void> stopWriting() => ref
      .read(databaseProvider)
      .settingsDao
      .updateSettings(
        const AppSettingsTableCompanion(
          healthConnectWriteWorkouts: Value(false),
        ),
      );

  /// Writes every finished session of the last month that is not in Health
  /// Connect yet, and returns how many it wrote.
  ///
  /// Does nothing unless writing is switched on. Never throws: it runs right
  /// after a session is finished, and a failure here must not look like the
  /// session failed. What did not make it is tried again at the next import.
  Future<int> writeWorkouts({DateTime? now}) async {
    try {
      final db = ref.read(databaseProvider);
      final settings = await db.settingsDao.getSettings();
      if (!settings.healthConnectEnabled ||
          !settings.healthConnectWriteWorkouts) {
        return 0;
      }
      final source = ref.read(healthSourceProvider);
      final since = (now ?? DateTime.now()).subtract(kWriteReach);

      var written = 0;
      for (final workout in await db.healthDao.workoutsToWrite(since)) {
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
    } on Object catch (error) {
      state = HealthSyncState(
        summary: state.summary,
        error: 'Een training naar Health Connect schrijven lukte niet: $error',
      );
      return 0;
    }
  }

  /// Takes a deleted session out of Health Connect as well. A courtesy: when
  /// it fails, the session stays there until you remove it in Health Connect
  /// itself.
  Future<void> forgetWorkout(String healthConnectId) async {
    try {
      await ref
          .read(healthSourceProvider)
          .deleteWorkout(healthConnectId)
          .timeout(kWriteTimeout);
    } on Object {
      return;
    }
  }

  /// Stops importing and gives the permissions back. With [forget], also
  /// deletes everything that ever came in from Health Connect - and nothing
  /// you entered yourself.
  Future<void> disconnect({required bool forget}) async {
    try {
      await ref.read(healthSourceProvider).revokeAccess();
    } on Object {
      // Revoking is a courtesy; the switch below is what stops the imports.
    }
    final db = ref.read(databaseProvider);
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(
        healthConnectEnabled: Value(false),
        healthConnectSyncedAt: Value(null),
        healthConnectWriteWorkouts: Value(false),
      ),
    );
    if (forget) await db.healthDao.forgetImported();
    state = const HealthSyncState();
  }
}
