import 'dart:typed_data';

import '../security/key_material.dart';
import '../util/paths.dart';
import 'connection.dart';
import 'database.dart';

/// The database for an alarm's own isolate, or null when this is not a turn
/// for it: no database, a key that does not open it, or one the app has not
/// brought to this version yet.
///
/// Right after an update the alarm and the app starting could both run the
/// same migration, and the second stopped on a column the first had just
/// added. The migration is the app's: the alarm leaves it, and its turn
/// comes again (DECISIONS 258).
Future<AppDatabase?> openForAlarm(Uint8List key) async {
  final file = (await AppPaths.resolve()).databaseFile;
  if (databaseVersion(file, toHex(key)) != AppDatabase.currentSchemaVersion) {
    return null;
  }
  return AppDatabase(openEncryptedExecutor(file: file, keyHex: toHex(key)));
}
