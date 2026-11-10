import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

/// Thrown when the database could not be opened as an *encrypted* database.
///
/// The app deliberately refuses to fall back to plain SQLite: silently writing
/// unencrypted training data would be worse than not starting at all.
class EncryptionUnavailableException implements Exception {
  const EncryptionUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'EncryptionUnavailableException: $message';
}

/// Thrown when the supplied key does not decrypt the database.
class WrongDatabaseKeyException implements Exception {
  const WrongDatabaseKeyException();

  @override
  String toString() => 'WrongDatabaseKeyException';
}

/// Applies the SQLCipher key and asserts that we really are on SQLCipher.
///
/// `PRAGMA key` must be the very first statement executed on the connection.
/// The key is passed in raw-key form (`x'<64 hex chars>'`) so SQLCipher uses
/// the 32 bytes directly instead of running its own KDF over them - our data
/// encryption key is already a full-entropy random key.
void applyKeyAndVerify(CommonDatabase db, String keyHex) {
  db.execute("PRAGMA key = \"x'$keyHex'\";");

  final cipher = db.select('PRAGMA cipher_version;');
  final version = cipher.isEmpty ? '' : '${cipher.first.values.first ?? ''}';
  if (version.trim().isEmpty) {
    throw const EncryptionUnavailableException(
      'PRAGMA cipher_version is leeg: deze build gebruikt gewone SQLite in '
      'plaats van SQLCipher. De database wordt niet geopend.',
    );
  }

  // Touching the schema forces SQLCipher to decrypt page 1. A wrong key
  // surfaces here as "file is not a database" rather than at a random later
  // query.
  try {
    db.select('SELECT count(*) FROM sqlite_master;');
  } on SqliteException catch (e) {
    if (e.resultCode == 26 || e.message.contains('not a database')) {
      throw const WrongDatabaseKeyException();
    }
    rethrow;
  }

  // Two connections at once - an alarm's isolate and the app starting -
  // waited for nothing: the second got "database is locked" at once. Now it
  // waits a few seconds for the first (DECISIONS 258).
  db.execute('PRAGMA busy_timeout = 5000;');
  db.execute('PRAGMA foreign_keys = ON;');
}

/// The schema version of the database in [file], read without opening it
/// for the app, or null when it does not open with [keyHex].
int? databaseVersion(File file, String keyHex) {
  if (!file.existsSync()) return null;
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    applyKeyAndVerify(db, keyHex);
    final version = db.select('PRAGMA user_version').first.values.first;
    return version is int ? version : null;
  } on Object {
    return null;
  } finally {
    db.close();
  }
}

/// Whether [keyHex] opens the database in [file]: checked before anything is
/// written with a key recovered from the twelve words.
bool keyOpensDatabase(File file, String keyHex) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    applyKeyAndVerify(db, keyHex);
    return true;
  } on WrongDatabaseKeyException {
    return false;
  } finally {
    db.close();
  }
}

/// Opens the encrypted database file on a background isolate.
QueryExecutor openEncryptedExecutor({
  required File file,
  required String keyHex,
  bool logStatements = false,
}) {
  return NativeDatabase.createInBackground(
    file,
    logStatements: logStatements,
    setup: (db) => applyKeyAndVerify(db, keyHex),
  );
}

/// Opens an encrypted in-memory database. Used by tests.
QueryExecutor openEncryptedMemoryExecutor(String keyHex) {
  return NativeDatabase.memory(setup: (db) => applyKeyAndVerify(db, keyHex));
}

/// Reads `PRAGMA cipher_version` from a throwaway in-memory database.
///
/// Returns an empty string when the linked SQLite has no encryption support.
String detectCipherVersion() {
  final db = sqlite3.openInMemory();
  try {
    final rows = db.select('PRAGMA cipher_version;');
    if (rows.isEmpty) return '';
    return '${rows.first.values.first ?? ''}'.trim();
  } finally {
    db.close();
  }
}
