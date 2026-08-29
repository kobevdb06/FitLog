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
