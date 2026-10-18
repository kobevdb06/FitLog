import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../calc/deload.dart';
import '../database.dart';

part 'deload_dao.drift.dart';

const _uuid = Uuid();

/// Where a deload stands on [day]: not yet begun, going, or over.
extension DeloadWeekDays on DeloadWeekRow {
  DateTime get from => DateTime.fromMillisecondsSinceEpoch(startDay);

  /// The midnight after its last day, or the moment it was stopped.
  DateTime get until {
    final planned = DateTime(from.year, from.month, from.day + days);
    final stopped = stoppedAt;
    if (stopped == null) return planned;
    final at = DateTime.fromMillisecondsSinceEpoch(stopped);
    return at.isBefore(planned) ? at : planned;
  }

  /// The last day, for saying "tot en met".
  DateTime get lastDay {
    final end = until;
    return DateTime(end.year, end.month, end.day - (stoppedAt == null ? 1 : 0));
  }

  bool isOnAt(DateTime at) => !at.isBefore(from) && at.isBefore(until);
  bool isAheadAt(DateTime at) => stoppedAt == null && at.isBefore(from);

  /// Which day of it [at] is, from 1.
  int dayAt(DateTime at) =>
      DateTime(at.year, at.month, at.day).difference(from).inDays + 1;

  DeloadPlan get plan => DeloadPlan(
    setsPercent: setsPercent,
    weightPercent: weightPercent,
    repsPercent: repsPercent,
    dropHardSets: dropHardSets,
    prAttempts: prAttempts,
  );
}

/// The deloads: the one going or planned, and the ones that were.
@DriftAccessor(tables: [DeloadWeeksTable])
class DeloadDao extends DatabaseAccessor<AppDatabase> with _$DeloadDaoMixin {
  DeloadDao(super.db);

  /// The deload going on [at], or the next one planned; never more than one.
  Future<DeloadWeekRow?> currentAt(DateTime at) async {
    for (final row in await _recent()) {
      if (row.isOnAt(at) || row.isAheadAt(at)) return row;
    }
    return null;
  }

  /// The deload going on [at] - not one still to come.
  Future<DeloadWeekRow?> onAt(DateTime at) async {
    final current = await currentAt(at);
    return current != null && current.isOnAt(at) ? current : null;
  }

  Stream<List<DeloadWeekRow>> watchAll() => (select(
    deloadWeeksTable,
  )..orderBy([(t) => OrderingTerm.desc(t.startDay)])).watch();

  /// Every deload, the newest first.
  Future<List<DeloadWeekRow>> all() => (select(
    deloadWeeksTable,
  )..orderBy([(t) => OrderingTerm.desc(t.startDay)])).get();

  Future<List<DeloadWeekRow>> _recent() =>
      (select(deloadWeeksTable)
            ..orderBy([(t) => OrderingTerm.desc(t.startDay)])
            ..limit(3))
          .get();

  /// Plans a deload of [days] from the day of [from]. One already going or
  /// planned gives way: there is only ever one.
  Future<String> start({
    required DateTime from,
    required int days,
    required DeloadPlan plan,
    required String source,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final id = _uuid.v4();
    await transaction(() async {
      final current = await currentAt(at);
      if (current != null) await stop(current.id, at: at);
      await into(deloadWeeksTable).insert(
        DeloadWeeksTableCompanion.insert(
          id: id,
          startDay: DateTime(
            from.year,
            from.month,
            from.day,
          ).millisecondsSinceEpoch,
          days: days < 1 ? 1 : days,
          setsPercent: plan.setsPercent,
          weightPercent: plan.weightPercent,
          repsPercent: plan.repsPercent,
          dropHardSets: plan.dropHardSets,
          prAttempts: plan.prAttempts,
          source: source,
          createdAt: at.millisecondsSinceEpoch,
        ),
      );
    });
    return id;
  }

  /// Ends it at [at]. One that has not begun yet is taken away: it never was.
  Future<void> stop(String id, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final row = await (select(
      deloadWeeksTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (row.isAheadAt(now)) {
      await (delete(deloadWeeksTable)..where((t) => t.id.equals(id))).go();
      return;
    }
    await (update(deloadWeeksTable)..where((t) => t.id.equals(id))).write(
      DeloadWeeksTableCompanion(stoppedAt: Value(now.millisecondsSinceEpoch)),
    );
  }
}
