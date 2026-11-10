import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where FitLog keeps its files. Everything lives inside the app's own
/// documents directory: nothing is written to shared storage or the camera
/// roll.
class AppPaths {
  const AppPaths(this.documents);

  final Directory documents;

  static Future<AppPaths> resolve() async =>
      AppPaths(await getApplicationDocumentsDirectory());

  /// The single encrypted SQLite file.
  File get databaseFile => File(p.join(documents.path, 'fitlog.db'));

  /// The database key wrapped under the twelve words, a second time: what
  /// the phrase still opens when the key store lost everything in it
  /// (DECISIONS 241).
  File get recoveryKeyFile => File(p.join(documents.path, 'fitlog.recovery'));

  /// Progress photos, one file per picture.
  Directory get photosDirectory => Directory(p.join(documents.path, 'photos'));

  Future<Directory> ensurePhotosDirectory() async {
    final dir = photosDirectory;
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File photoFile(String fileName) =>
      File(p.join(photosDirectory.path, fileName));

  /// Scratch space for exports before they are handed to the share sheet.
  Future<Directory> exportDirectory() async {
    final dir = Directory(p.join(documents.path, 'export'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
