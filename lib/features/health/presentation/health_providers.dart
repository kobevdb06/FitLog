import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/app/app_state.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../data/health_connect_source.dart';
import '../data/health_import.dart';
import '../data/health_importer.dart';
import '../data/health_source.dart';

export '../data/health_import.dart'
    show
        kFirstImportReach,
        kImportInterval,
        kImportOverlap,
        kWriteReach,
        kWriteTimeout;

part 'health_providers.g.dart';

/// Where Health Connect is reached. Overridden in tests with one that
/// answers from memory.
@Riverpod(keepAlive: true)
HealthSource healthSource(Ref ref) => HealthConnectSource();

/// Whether Health Connect is on this phone and usable.
@riverpod
Future<HealthAvailability> healthAvailability(Ref ref) =>
    ref.watch(healthSourceProvider).availability();

/// What FitLog asks for but may not read, while connected. Asked again when
/// the screen comes back, so a change made in Health Connect itself shows.
@riverpod
Future<List<String>> healthMissingAccess(Ref ref) async {
  if (!ref.watch(healthConnectEnabledProvider)) return const [];
  return ref.watch(healthSourceProvider).missingAccess();
}

/// The newest sessions with the heart rate a watch measured during them.
@riverpod
Stream<List<WorkoutRow>> workoutHeartRates(Ref ref) =>
    ref.watch(databaseProvider).healthDao.watchWorkoutHeartRates();

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
    final moment = now ?? DateTime.now();
    // Straight from the database: the settings stream may have nobody
    // listening, and then it answers "still loading" (DECISIONS 130).
    final import = _import();
    final window = await import.due(now: moment, force: force);
    if (window == null) return;

    state = HealthSyncState(busy: true, summary: state.summary);
    try {
      final summary = await import.fetch(from: window.from, to: window.to);
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
      return await _import().writeWorkouts(now: now ?? DateTime.now());
    } on Object catch (error) {
      state = HealthSyncState(
        summary: state.summary,
        error: 'Een training naar Health Connect schrijven lukte niet: $error',
      );
      return 0;
    }
  }

  HealthImport _import() =>
      HealthImport(ref.read(databaseProvider), ref.read(healthSourceProvider));

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

  /// Shows Health Connect's permission screen again, for what was refused
  /// or added since - the heart rate, for someone who connected before it
  /// was asked for - and imports straight after.
  Future<void> askAgain() async {
    try {
      await ref.read(healthSourceProvider).requestAccess();
    } on Object catch (error) {
      state = HealthSyncState(
        summary: state.summary,
        error: 'Toestemming vragen lukte niet: $error',
      );
      return;
    }
    ref.invalidate(healthMissingAccessProvider);
    await sync(force: true);
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
