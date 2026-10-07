import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/backup/presentation/backup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The backup is made well after it is asked for: the weekly one waits for
/// the app to settle, and the first one waits for a folder to be picked.
/// Whatever it needs must still be there by then.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('de back-up kan nog gemaakt worden als niemand meer kijkt', () async {
    // Read once, as the screen and the app do, and nobody listening after.
    final make = container.read(autoBackupProvider).createBackup;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // In this test there is no open database, so it may say that - but it
    // must get that far rather than fail on a provider that is gone.
    await expectLater(
      make(),
      throwsA(
        predicate(
          (error) => '$error'.contains('De database is niet open'),
          'says the database is not open',
        ),
      ),
    );
  });
}
