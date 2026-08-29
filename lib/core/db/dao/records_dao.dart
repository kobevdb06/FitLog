import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../calc/pr.dart';
import '../database.dart';
import '../models.dart';

part 'records_dao.drift.dart';

const _uuid = Uuid();

@DriftAccessor(
  tables: [
    PersonalRecordsTable,
    ExercisesTable,
    BodyMeasurementsTable,
    ProgressPhotosTable,
    WorkoutSetsTable,
    WorkoutExercisesTable,
    WorkoutsTable,
  ],
)
class RecordsDao extends DatabaseAccessor<AppDatabase> with _$RecordsDaoMixin {
  RecordsDao(super.db);

  // --- Personal records -----------------------------------------------------

  Future<Map<PrType, double>> currentBests(String exerciseId) async {
    final rows = await (select(
      personalRecordsTable,
    )..where((t) => t.exerciseId.equals(exerciseId))).get();
    return {
      for (final r in rows) PrType.fromWire(r.recordType): r.value,
    };
  }

  /// Checks a freshly completed set against the exercise's records and writes
  /// every new one. Returns the records that were actually set.
  Future<List<PrCandidate>> registerSet({
    required String exerciseId,
    required String workoutSetId,
    required SetType setType,
    required bool isCompleted,
    double? weightKg,
    int? reps,
    int? achievedAt,
  }) async {
    final bests = await currentBests(exerciseId);
    final records = detectRecordsForSet(
      setType: setType,
      isCompleted: isCompleted,
      weightKg: weightKg,
      reps: reps,
      currentBests: bests,
    );
    if (records.isEmpty) return const [];

    final at = achievedAt ?? DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      for (final record in records) {
        await (delete(personalRecordsTable)..where(
              (t) =>
                  t.exerciseId.equals(exerciseId) &
                  t.recordType.equals(record.type.wire),
            ))
            .go();
        await into(personalRecordsTable).insert(
          PersonalRecordsTableCompanion.insert(
            id: _uuid.v4(),
            exerciseId: exerciseId,
            recordType: record.type.wire,
            value: record.value,
            workoutSetId: Value(workoutSetId),
            achievedAt: at,
          ),
        );
      }
    });
    return records;
  }

  /// Rebuilds every personal record from the stored sets.
  ///
  /// Editing or deleting a past workout can invalidate a record, and there is
  /// no cheap way to know which. Replaying the history is exact and, with a
  /// few thousand sets, fast enough to run on save.
  Future<void> rebuildAllRecords() async {
    final rows = await customSelect(
      'SELECT ws.id AS set_id, ws.weight_kg AS weight_kg, ws.reps AS reps, '
      'ws.set_type AS set_type, ws.is_completed AS is_completed, '
      'we.exercise_id AS exercise_id, '
      'COALESCE(ws.completed_at, w.started_at) AS achieved_at '
      'FROM workout_sets ws '
      'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
      'JOIN workouts w ON w.id = we.workout_id '
      'WHERE ws.is_completed = 1 AND w.ended_at IS NOT NULL '
      'ORDER BY achieved_at ASC',
      readsFrom: {workoutSetsTable, workoutExercisesTable, workoutsTable},
    ).get();

    // exercise -> type -> (value, setId, achievedAt)
    final best = <String, Map<PrType, ({double v, String setId, int at})>>{};

    for (final r in rows) {
      final exerciseId = r.read<String>('exercise_id');
      final candidates = prCandidatesForSet(
        setType: SetType.fromWire(r.read<String>('set_type')),
        isCompleted: true,
        weightKg: r.read<double?>('weight_kg'),
        reps: r.read<int?>('reps'),
      );
      if (candidates.isEmpty) continue;

      final forExercise = best.putIfAbsent(exerciseId, () => {});
      for (final c in candidates) {
        final current = forExercise[c.type];
        if (current == null || c.value > current.v) {
          forExercise[c.type] = (
            v: c.value,
            setId: r.read<String>('set_id'),
            at: r.read<int>('achieved_at'),
          );
        }
      }
    }

    await transaction(() async {
      await delete(personalRecordsTable).go();
      await batch((b) {
        for (final entry in best.entries) {
          for (final rec in entry.value.entries) {
            b.insert(
              personalRecordsTable,
              PersonalRecordsTableCompanion.insert(
                id: _uuid.v4(),
                exerciseId: entry.key,
                recordType: rec.key.wire,
                value: rec.value.v,
                workoutSetId: Value(rec.value.setId),
                achievedAt: rec.value.at,
              ),
            );
          }
        }
      });
    });
  }

  Stream<List<RecordWithExercise>> watchRecords({
    PrType? type,
    int? limit,
  }) {
    final query = select(personalRecordsTable).join([
      innerJoin(
        exercisesTable,
        exercisesTable.id.equalsExp(personalRecordsTable.exerciseId),
      ),
    ]);
    if (type != null) {
      query.where(personalRecordsTable.recordType.equals(type.wire));
    }
    query.orderBy([OrderingTerm.desc(personalRecordsTable.achievedAt)]);
    if (limit != null) query.limit(limit);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => RecordWithExercise(
              record: r.readTable(personalRecordsTable),
              exercise: r.readTable(exercisesTable),
            ),
          )
          .toList(),
    );
  }

  Future<List<PersonalRecordRow>> recordsForExercise(String exerciseId) =>
      (select(personalRecordsTable)
            ..where((t) => t.exerciseId.equals(exerciseId))
            ..orderBy([(t) => OrderingTerm.asc(t.recordType)]))
          .get();

  Stream<List<PersonalRecordRow>> watchRecordsForExercise(String exerciseId) =>
      (select(personalRecordsTable)
            ..where((t) => t.exerciseId.equals(exerciseId))
            ..orderBy([(t) => OrderingTerm.asc(t.recordType)]))
          .watch();

  /// The records achieved during one workout, used by the summary screen.
  Future<List<RecordWithExercise>> recordsForWorkout(String workoutId) async {
    final rows = await customSelect(
      'SELECT pr.* FROM personal_records pr '
      'JOIN workout_sets ws ON ws.id = pr.workout_set_id '
      'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
      'WHERE we.workout_id = ?',
      variables: [Variable.withString(workoutId)],
      readsFrom: {
        personalRecordsTable,
        workoutSetsTable,
        workoutExercisesTable,
      },
    ).get();
    if (rows.isEmpty) return const [];

    final records = rows.map((r) => personalRecordsTable.map(r.data)).toList();
    final exercises = await (select(
      exercisesTable,
    )..where((t) => t.id.isIn(records.map((r) => r.exerciseId)))).get();
    final byId = {for (final e in exercises) e.id: e};

    return records
        .where((r) => byId.containsKey(r.exerciseId))
        .map(
          (r) => RecordWithExercise(record: r, exercise: byId[r.exerciseId]!),
        )
        .toList();
  }

  /// The ids of sets that produced a record, for the badge on the set row.
  Future<Set<String>> recordSetIds(String workoutId) async {
    final rows = await customSelect(
      'SELECT DISTINCT pr.workout_set_id AS id FROM personal_records pr '
      'JOIN workout_sets ws ON ws.id = pr.workout_set_id '
      'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
      'WHERE we.workout_id = ? AND pr.workout_set_id IS NOT NULL',
      variables: [Variable.withString(workoutId)],
      readsFrom: {
        personalRecordsTable,
        workoutSetsTable,
        workoutExercisesTable,
      },
    ).get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  // --- Body measurements ----------------------------------------------------

  Stream<List<BodyMeasurementRow>> watchMeasurements({
    MeasurementType? type,
    int? limit,
  }) {
    final q = select(bodyMeasurementsTable);
    if (type != null) q.where((t) => t.type.equals(type.wire));
    q.orderBy([(t) => OrderingTerm.desc(t.measuredAt)]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Future<List<BodyMeasurementRow>> measurements({
    MeasurementType? type,
    int? limit,
  }) {
    final q = select(bodyMeasurementsTable);
    if (type != null) q.where((t) => t.type.equals(type.wire));
    q.orderBy([(t) => OrderingTerm.desc(t.measuredAt)]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  /// The newest value per measurement type.
  Stream<Map<MeasurementType, BodyMeasurementRow>> watchLatestMeasurements() {
    return customSelect(
      'SELECT bm.* FROM body_measurements bm '
      'JOIN (SELECT type, MAX(measured_at) AS m FROM body_measurements '
      '      GROUP BY type) latest '
      'ON latest.type = bm.type AND latest.m = bm.measured_at',
      readsFrom: {bodyMeasurementsTable},
    ).watch().map((rows) {
      final result = <MeasurementType, BodyMeasurementRow>{};
      for (final r in rows) {
        final row = bodyMeasurementsTable.map(r.data);
        result[MeasurementType.fromWire(row.type)] = row;
      }
      return result;
    });
  }

  Future<String> addMeasurement({
    required MeasurementType type,
    required double value,
    required DateTime measuredAt,
    String? note,
  }) async {
    final id = _uuid.v4();
    await into(bodyMeasurementsTable).insert(
      BodyMeasurementsTableCompanion.insert(
        id: id,
        measuredAt: measuredAt.millisecondsSinceEpoch,
        type: type.wire,
        value: value,
        note: Value(note),
      ),
    );
    return id;
  }

  Future<void> deleteMeasurement(String id) async {
    await (delete(bodyMeasurementsTable)..where((t) => t.id.equals(id))).go();
  }

  // --- Progress photos ------------------------------------------------------

  Stream<List<ProgressPhotoRow>> watchPhotos() =>
      (select(progressPhotosTable)
            ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
          .watch();

  Future<List<ProgressPhotoRow>> photos() =>
      (select(progressPhotosTable)
            ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
          .get();

  Future<String> addPhoto({
    required String fileName,
    required PhotoPose pose,
    required DateTime takenAt,
    String? note,
  }) async {
    final id = _uuid.v4();
    await into(progressPhotosTable).insert(
      ProgressPhotosTableCompanion.insert(
        id: id,
        takenAt: takenAt.millisecondsSinceEpoch,
        fileName: fileName,
        pose: pose.wire,
        note: Value(note),
      ),
    );
    return id;
  }

  Future<ProgressPhotoRow?> photoById(String id) => (select(
    progressPhotosTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> deletePhoto(String id) async {
    await (delete(progressPhotosTable)..where((t) => t.id.equals(id))).go();
  }

  /// The body weight recorded closest to [at], used when comparing photos.
  Future<BodyMeasurementRow?> weightNearest(DateTime at) async {
    final rows = await customSelect(
      "SELECT * FROM body_measurements WHERE type = 'weight' "
      'ORDER BY ABS(measured_at - ?) ASC LIMIT 1',
      variables: [Variable.withInt(at.millisecondsSinceEpoch)],
      readsFrom: {bodyMeasurementsTable},
    ).get();
    if (rows.isEmpty) return null;
    return bodyMeasurementsTable.map(rows.first.data);
  }
}
