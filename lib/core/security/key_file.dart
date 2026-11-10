import 'dart:io';

/// One small value kept in a file of its own, next to the database.
///
/// For the database key wrapped under the twelve words: Argon2 and the
/// phrase protect it, not the Keystore, so it may lie on disk - and it has
/// to, because the Keystore is exactly what can lose it (DECISIONS 241).
abstract interface class KeyFile {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// On disk, in the app's own documents directory.
class DiskKeyFile implements KeyFile {
  DiskKeyFile(this._locate);

  /// Where the file is: asked for when it is needed, since the documents
  /// directory is only known once the platform answers.
  final Future<File> Function() _locate;

  @override
  Future<String?> read() async {
    final file = await _locate();
    if (!await file.exists()) return null;
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  /// Written next to it first and then moved over it, so a crash halfway
  /// leaves the old value or the new one, never half of one.
  @override
  Future<void> write(String value) async {
    final file = await _locate();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _locate();
    if (await file.exists()) await file.delete();
  }
}

/// Used by tests.
class InMemoryKeyFile implements KeyFile {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}
