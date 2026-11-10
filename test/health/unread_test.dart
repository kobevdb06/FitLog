import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/health/data/health_connect_source.dart';
import 'package:fitlog/features/health/data/health_import.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../widget/helpers.dart';

/// A read that failed is not a read that found nothing (DECISIONS 252).
///
/// A type that could not be read was skipped, the import kept its new
/// moment anyway, and the next one looked back two days only: a night or a
/// run that was unreadable just then never came in, under "Ophalen gelukt".
/// And granting part of the access counted as granting none.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 11, 10, 8);

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
    );
  });

  tearDown(() => db.close());

  Future<int?> syncedAt() async =>
      (await db.settingsDao.getSettings()).healthConnectSyncedAt;

  test('a type that could not be read keeps the moment where it was', () async {
    final import = HealthImport(db, _Patchy(unread: const ['slaap']));

    final summary = await import.fetch(
      from: now.subtract(const Duration(days: 2)),
      to: now,
    );

    expect(summary.unread, ['slaap']);
    expect(await syncedAt(), isNull, reason: 'asked again from where it was');
  });

  test('so do the steps, read day by day', () async {
    final import = HealthImport(db, _Patchy(stepsFail: true));

    final summary = await import.fetch(
      from: now.subtract(const Duration(days: 1)),
      to: now,
    );

    expect(summary.unread, ['stappen']);
    expect(await syncedAt(), isNull);
  });

  test('everything read: the moment moves on', () async {
    final import = HealthImport(db, _Patchy());

    final summary = await import.fetch(
      from: now.subtract(const Duration(days: 1)),
      to: now,
    );

    expect(summary.unread, isEmpty);
    expect(await syncedAt(), now.millisecondsSinceEpoch);
  });

  group('Health Connect itself', () {
    test(
      'a type refused is not unread; a type granted that fails is',
      () async {
        final health = _FakeHealth(
          granted: {HealthDataType.WEIGHT},
          failing: {HealthDataType.WEIGHT, HealthDataType.SLEEP_SESSION},
        );

        final snapshot = await HealthConnectSource(health: health)
            .read(from: now.subtract(const Duration(days: 1)), to: now);

        expect(snapshot.unread, ['gewicht']);
      },
    );

    test(
      'part of the access granted is access: what is missing is said',
      () async {
        final health = _FakeHealth(granted: {HealthDataType.SLEEP_SESSION});
        final source = HealthConnectSource(health: health);

        expect(await source.requestAccess(), isTrue);
        expect(await source.missingAccess(), contains('gewicht'));
        expect(await source.missingAccess(), contains('slaapfasen'));
      },
    );

    test('none of it granted is none', () async {
      final source = HealthConnectSource(health: _FakeHealth(granted: {}));

      expect(await source.requestAccess(), isFalse);
    });
  });
}

/// A source that reads nothing, and fails where it is told to.
class _Patchy implements HealthSource {
  _Patchy({this.unread = const [], this.stepsFail = false});

  final List<String> unread;
  final bool stepsFail;

  @override
  Future<HealthSnapshot> read({
    required DateTime from,
    required DateTime to,
  }) async => HealthSnapshot(unread: unread);

  @override
  Future<int?> steps({required DateTime from, required DateTime to}) async {
    if (stepsFail) throw const HealthUnreadable('stappen');
    return null;
  }

  @override
  Future<List<ImportedReading>> oxygenSaturation({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<List<ImportedReading>> heartRate({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<List<String>> missingAccess() async => const [];

  @override
  Future<HealthAvailability> availability() async =>
      HealthAvailability.available;

  @override
  Future<void> openInstall() async {}

  @override
  Future<bool> hasAccess() async => true;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<void> revokeAccess() async {}

  @override
  Future<bool> requestWriteAccess() async => true;

  @override
  Future<bool> requestBackgroundAccess() async => true;

  @override
  Future<String?> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async => null;

  @override
  Future<void> deleteWorkout(String id) async {}
}

/// The plugin, as far as these tests reach: what is granted, and what fails
/// to be read.
class _FakeHealth implements Health {
  _FakeHealth({required this.granted, this.failing = const {}});

  final Set<HealthDataType> granted;
  final Set<HealthDataType> failing;

  @override
  Future<void> configure() async {}

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => types.every(granted.contains);

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => types.every(granted.contains);

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    if (types.any(failing.contains)) throw StateError('kon niet lezen');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
