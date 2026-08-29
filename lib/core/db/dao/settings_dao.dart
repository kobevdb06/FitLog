import 'package:drift/drift.dart';

import '../database.dart';

part 'settings_dao.drift.dart';

/// The settings and the profile are single-row tables. Both use this fixed id.
const kSingletonId = 'singleton';

@DriftAccessor(tables: [AppSettingsTable, UserProfileTable])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Creates the settings row on first start. Safe to call repeatedly.
  Future<AppSettingsRow> ensureInitialized() async {
    final existing = await (select(
      appSettingsTable,
    )..where((t) => t.id.equals(kSingletonId))).getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now().millisecondsSinceEpoch;
    await into(appSettingsTable).insert(
      AppSettingsTableCompanion.insert(id: kSingletonId, updatedAt: now),
    );
    return (select(
      appSettingsTable,
    )..where((t) => t.id.equals(kSingletonId))).getSingle();
  }

  Stream<AppSettingsRow> watchSettings() =>
      (select(appSettingsTable)
            ..where((t) => t.id.equals(kSingletonId)))
          .watchSingle();

  Future<AppSettingsRow> getSettings() =>
      (select(appSettingsTable)
            ..where((t) => t.id.equals(kSingletonId)))
          .getSingle();

  Future<void> updateSettings(AppSettingsTableCompanion changes) async {
    await (update(appSettingsTable)..where((t) => t.id.equals(kSingletonId)))
        .write(
          changes.copyWith(
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Stream<UserProfileRow?> watchProfile() =>
      (select(userProfileTable)
            ..where((t) => t.id.equals(kSingletonId)))
          .watchSingleOrNull();

  Future<UserProfileRow?> getProfile() =>
      (select(userProfileTable)
            ..where((t) => t.id.equals(kSingletonId)))
          .getSingleOrNull();

  Future<void> upsertProfile({
    Value<String?> displayName = const Value.absent(),
    Value<int?> birthDate = const Value.absent(),
    Value<String?> sex = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getProfile();
    if (existing == null) {
      await into(userProfileTable).insert(
        UserProfileTableCompanion.insert(
          id: kSingletonId,
          displayName: displayName,
          birthDate: birthDate,
          sex: sex,
          heightCm: heightCm,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await (update(userProfileTable)
            ..where((t) => t.id.equals(kSingletonId)))
          .write(
            UserProfileTableCompanion(
              displayName: displayName,
              birthDate: birthDate,
              sex: sex,
              heightCm: heightCm,
              updatedAt: Value(now),
            ),
          );
    }
  }
}
