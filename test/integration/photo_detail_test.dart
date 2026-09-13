import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// What a photograph carries besides the picture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> photo({
    PhotoPose pose = PhotoPose.front,
    DateTime? takenAt,
    String? note,
  }) => db.recordsDao.addPhoto(
    fileName: 'foto.jpg',
    pose: pose,
    takenAt: takenAt ?? DateTime(2026, 9, 7, 10),
    note: note,
  );

  Future<String> workout(String name) async {
    final id = await db.workoutsDao.startWorkout(
      name: name,
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.finishWorkout(id, discardPending: true);
    return id;
  }

  Future<ProgressPhotoRow> read(String id) async =>
      (await db.recordsDao.photoById(id))!;

  group('what an edit can change', () {
    test('a photo starts with no note and no session', () async {
      final row = await read(await photo());

      expect(row.note, isNull);
      expect(row.workoutId, isNull);
    });

    test('all four fields at once', () async {
      final id = await photo();
      final workoutId = await workout('Push');

      await db.recordsDao.updatePhoto(
        id,
        pose: PhotoPose.back,
        takenAt: DateTime(2026, 9, 8, 11),
        note: 'ochtend, nuchter',
        workoutId: workoutId,
      );

      final row = await read(id);
      expect(PhotoPose.fromWire(row.pose), PhotoPose.back);
      expect(
        DateTime.fromMillisecondsSinceEpoch(row.takenAt),
        DateTime(2026, 9, 8, 11),
      );
      expect(row.note, 'ochtend, nuchter');
      expect(row.workoutId, workoutId);
    });

    test('and a note can be taken away again', () async {
      // Which is why every field is passed on every call: "not mentioned" and
      // "emptied" cannot be the same thing.
      final id = await photo(note: 'iets');

      await db.recordsDao.updatePhoto(
        id,
        pose: PhotoPose.front,
        takenAt: DateTime(2026, 9, 7, 10),
        note: null,
        workoutId: null,
      );

      expect((await read(id)).note, isNull);
    });

    test('the same for the session it was linked to', () async {
      final id = await photo();
      final workoutId = await workout('Push');
      await db.recordsDao.updatePhoto(
        id,
        pose: PhotoPose.front,
        takenAt: DateTime(2026, 9, 7, 10),
        note: null,
        workoutId: workoutId,
      );

      await db.recordsDao.updatePhoto(
        id,
        pose: PhotoPose.front,
        takenAt: DateTime(2026, 9, 7, 10),
        note: null,
        workoutId: null,
      );

      expect((await read(id)).workoutId, isNull);
    });
  });

  group('when the session goes', () {
    test('the photo stays, and only forgets which one it was', () async {
      // Clearing out your history must not take your photographs with it.
      final id = await photo();
      final workoutId = await workout('Push');
      await db.recordsDao.updatePhoto(
        id,
        pose: PhotoPose.front,
        takenAt: DateTime(2026, 9, 7, 10),
        note: 'blijft staan',
        workoutId: workoutId,
      );

      await db.workoutsDao.deleteWorkout(workoutId);

      final row = await read(id);
      expect(row.note, 'blijft staan');
      expect(row.workoutId, isNull);
    });
  });
}
