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

  Stream<AppSettingsRow> watchSettings() => (select(
    appSettingsTable,
  )..where((t) => t.id.equals(kSingletonId))).watchSingle();

  Future<AppSettingsRow> getSettings() => (select(
    appSettingsTable,
  )..where((t) => t.id.equals(kSingletonId))).getSingle();

  Future<void> updateSettings(AppSettingsTableCompanion changes) async {
    await (update(
      appSettingsTable,
    )..where((t) => t.id.equals(kSingletonId))).write(
      changes.copyWith(updatedAt: Value(DateTime.now().millisecondsSinceEpoch)),
    );
  }

  /// Stores the user's Anthropic key, or clears it when [key] is null or
  /// blank.
  ///
  /// Its own method so that there is one place to look for what happens to a
  /// key: it is trimmed, it is written, and it is never logged, never copied
  /// into an error message, and never sent anywhere but to Anthropic's own
  /// API, by the one file that is allowed to open a connection at all.
  Future<void> setApiKey(String? key) async {
    final trimmed = key?.trim();
    await updateSettings(
      AppSettingsTableCompanion(
        anthropicApiKey: Value(
          trimmed == null || trimmed.isEmpty ? null : trimmed,
        ),
      ),
    );
  }

  Future<String?> apiKey() async => (await getSettings()).anthropicApiKey;

  Stream<UserProfileRow?> watchProfile() => (select(
    userProfileTable,
  )..where((t) => t.id.equals(kSingletonId))).watchSingleOrNull();

  Future<UserProfileRow?> getProfile() => (select(
    userProfileTable,
  )..where((t) => t.id.equals(kSingletonId))).getSingleOrNull();

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
      await (update(
        userProfileTable,
      )..where((t) => t.id.equals(kSingletonId))).write(
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
