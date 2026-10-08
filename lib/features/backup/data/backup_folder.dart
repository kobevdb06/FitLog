import 'package:flutter/services.dart';

/// A folder you picked yourself, as Android hands it over.
class PickedFolder {
  const PickedFolder({required this.uri, required this.name});

  /// The content URI the app keeps permission to write to.
  final String uri;

  /// What the folder is called, to show you where your backups go.
  final String name;
}

/// A file in that folder.
class FolderFile {
  const FolderFile({required this.name, required this.modifiedAt});

  final String name;
  final DateTime modifiedAt;
}

/// A folder outside the app that it may write to: picked once, kept across
/// restarts, and still there after FitLog is uninstalled - the point of a
/// backup.
abstract interface class BackupFolder {
  /// Asks you for a folder; null when you back out.
  Future<PickedFolder?> pick();

  /// The folder's name, or null when it is gone or the app may no longer
  /// write to it.
  Future<String?> nameOf(String uri);

  /// Copies the file at [sourcePath] into the folder as [fileName].
  Future<void> write(String uri, String fileName, String sourcePath);

  Future<List<FolderFile>> list(String uri);

  Future<void> delete(String uri, String fileName);

  /// Gives the permission back, when automatic backups are switched off.
  Future<void> release(String uri);
}

/// The Android storage access framework, through `FitLogActivity`.
class AndroidBackupFolder implements BackupFolder {
  const AndroidBackupFolder();

  static const _channel = MethodChannel('be.fitlog.app/folders');

  @override
  Future<PickedFolder?> pick() async {
    final picked = await _channel.invokeMapMethod<String, Object?>('pick');
    if (picked == null) return null;
    return PickedFolder(
      uri: picked['uri']! as String,
      name: picked['name'] as String? ?? 'gekozen map',
    );
  }

  @override
  Future<String?> nameOf(String uri) =>
      _channel.invokeMethod<String>('name', {'uri': uri});

  @override
  Future<void> write(String uri, String fileName, String sourcePath) =>
      _channel.invokeMethod<void>('write', {
        'uri': uri,
        'name': fileName,
        'source': sourcePath,
      });

  @override
  Future<List<FolderFile>> list(String uri) async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>('list', {
          'uri': uri,
        }) ??
        const [];
    return [
      for (final row in rows)
        FolderFile(
          name: row['name']! as String,
          modifiedAt: DateTime.fromMillisecondsSinceEpoch(
            (row['modified'] as int?) ?? 0,
          ),
        ),
    ];
  }

  @override
  Future<void> delete(String uri, String fileName) =>
      _channel.invokeMethod<void>('delete', {'uri': uri, 'name': fileName});

  @override
  Future<void> release(String uri) =>
      _channel.invokeMethod<void>('release', {'uri': uri});
}
