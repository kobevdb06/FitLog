import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The picker hands a photo over as a copy in the app's own cache; once it
/// is stored, that copy goes (DECISIONS 247). A camera photo otherwise lay
/// there whole, where it was taken still in it.
///
/// Only a file inside that cache is ever touched, never one kept anywhere
/// else. A copy that cannot go is not worth an error.
Future<void> forgetPickedCopy(
  String path, {
  Future<Directory> Function() cache = getTemporaryDirectory,
}) async {
  try {
    final dir = await cache();
    if (!p.isWithin(dir.path, path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on Object {
    // Android clears its cache in time anyway.
  }
}
