import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:image_picker/image_picker.dart';

import '../../../core/db/database.dart';
import '../../../core/util/paths.dart';
import 'photo_library.dart';
import 'photo_store.dart';

/// Picks up a photo Android threw away.
///
/// While the camera is open the app is in the background, and Android is free
/// to kill it to reclaim memory. The picture is taken all the same: the plugin
/// hands it back on the next launch through `retrieveLostData`, and until now
/// nobody asked, so the photo was simply gone.
///
/// Knowing there is a file is not enough - it has to go somewhere. The app
/// therefore writes down what it was picking **before** it opens the camera,
/// and that note is what turns a stray file back into a progress photo or the
/// start position of an exercise.
class PickRecovery {
  PickRecovery({
    required this.db,
    required this.paths,
    Future<File?> Function()? readLostFile,
  }) : _readLostFile = readLostFile ?? _platformLostFile;

  final AppDatabase db;
  final AppPaths paths;
  final Future<File?> Function() _readLostFile;

  /// Only Android loses data this way, and the plugin throws everywhere else.
  static Future<File?> _platformLostFile() async {
    if (!Platform.isAndroid) return null;
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty) return null;
    final file = response.file;
    return file == null ? null : File(file.path);
  }

  /// Writes down what is being picked, before the camera opens.
  Future<void> remember(PendingPick pick) => db.settingsDao.updateSettings(
    AppSettingsTableCompanion(
      pendingPickKind: Value(pick.kind.wire),
      pendingPickRef: Value(pick.ref),
    ),
  );

  /// Clears the note, whether the pick succeeded or the user backed out.
  Future<void> forget() => db.settingsDao.updateSettings(
    const AppSettingsTableCompanion(
      pendingPickKind: Value(null),
      pendingPickRef: Value(null),
    ),
  );

  /// Reads the note back, or null when nothing is pending.
  Future<PendingPick?> pending() async {
    final settings = await db.settingsDao.getSettings();
    final kind = PickKind.fromWire(settings.pendingPickKind);
    if (kind == null) return null;
    return PendingPick(kind, settings.pendingPickRef);
  }

  /// Runs at startup and on resume: finishes an interrupted pick if there is
  /// one, and clears the note either way.
  Future<PickRecoveryOutcome> recover() async {
    final pick = await pending();
    final file = await _readLostFile();

    if (file == null) {
      // The pick is over one way or another; the note has done its job.
      if (pick != null) await forget();
      return PickRecoveryOutcome.nothing;
    }
    if (pick == null) return PickRecoveryOutcome.orphaned;

    final outcome = await _complete(pick, file);
    await forget();
    return outcome;
  }

  Future<PickRecoveryOutcome> _complete(PendingPick pick, File file) async {
    switch (pick.kind) {
      case PickKind.progressPhoto:
        final pose = PhotoPose.fromWire(pick.ref ?? '');
        await PhotoLibrary(db: db, store: PhotoStore(paths)).importPhoto(
          source: file,
          pose: pose,
          takenAt: DateTime.now(),
        );
        return PickRecoveryOutcome.recovered;

      case PickKind.exerciseFrame:
        final slot = ExerciseFrameSlot.parse(pick.ref);
        // An exercise that was still being created has no row to hang the
        // picture on, and the half-filled form is gone with the process. The
        // file is left where the system put it rather than stored for a row
        // that will never point at it.
        if (slot == null) return PickRecoveryOutcome.unplaceable;
        if (await db.exercisesDao.getById(slot.exerciseId) == null) {
          return PickRecoveryOutcome.unplaceable;
        }

        final fileName = await PhotoStore(paths).import(file, maxLongEdge: 720);
        await db.exercisesDao.updateExercise(
          slot.exerciseId,
          slot.isStart
              ? ExercisesTableCompanion(startImageFile: Value(fileName))
              : ExercisesTableCompanion(endImageFile: Value(fileName)),
        );
        return PickRecoveryOutcome.recovered;
    }
  }
}

/// What was being picked when the app went away.
class PendingPick {
  const PendingPick(this.kind, this.ref);

  /// A progress photo for a pose.
  PendingPick.progressPhoto(PhotoPose pose)
    : kind = PickKind.progressPhoto,
      ref = pose.wire;

  /// One frame of an exercise. [exerciseId] is null while the exercise is
  /// still being created, which is the one case that cannot be recovered.
  PendingPick.exerciseFrame({
    required String? exerciseId,
    required bool isStart,
  }) : kind = PickKind.exerciseFrame,
       ref = ExerciseFrameSlot.encode(exerciseId, isStart: isStart);

  final PickKind kind;
  final String? ref;
}

/// The exercise and slot a lost frame belongs to.
class ExerciseFrameSlot {
  const ExerciseFrameSlot({required this.exerciseId, required this.isStart});

  final String exerciseId;
  final bool isStart;

  static String encode(String? exerciseId, {required bool isStart}) =>
      '${exerciseId ?? ''}:${isStart ? 'start' : 'end'}';

  /// Null when the note names no exercise, so there is nowhere to put it.
  static ExerciseFrameSlot? parse(String? raw) {
    if (raw == null) return null;
    final separator = raw.lastIndexOf(':');
    if (separator <= 0) return null;
    return ExerciseFrameSlot(
      exerciseId: raw.substring(0, separator),
      isStart: raw.substring(separator + 1) == 'start',
    );
  }
}

enum PickRecoveryOutcome {
  /// No interrupted pick to finish.
  nothing,

  /// A picture was picked up and stored where it was meant to go.
  recovered,

  /// A file came back with no note saying what it was for.
  orphaned,

  /// A file and a note, but the exercise it belonged to is gone or was never
  /// saved.
  unplaceable,
}
