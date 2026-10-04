import 'package:drift/drift.dart';

import '../database.dart';
import 'recovery_dao.dart';

part 'reports_dao.drift.dart';

/// The morning reports: one per day, newest first.
@DriftAccessor(tables: [MorningReportsTable])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(super.db);

  /// Stores the report of [day]. Making it again that day replaces it.
  Future<void> saveReport({
    required DateTime day,
    required DateTime createdAt,
    required String facts,
    String? coachText,
    String? coachError,
    String? importError,
    int? requests,
    int? inputTokens,
    int? outputTokens,
  }) => into(morningReportsTable).insertOnConflictUpdate(
    MorningReportsTableCompanion.insert(
      id: RecoveryDao.dayKey(day),
      createdAt: createdAt.millisecondsSinceEpoch,
      facts: facts,
      coachText: Value(coachText),
      coachError: Value(coachError),
      importError: Value(importError),
      requests: Value(requests),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
    ),
  );

  Future<MorningReportRow?> reportFor(DateTime day) => (select(
    morningReportsTable,
  )..where((t) => t.id.equals(RecoveryDao.dayKey(day)))).getSingleOrNull();

  /// The reports made from [from] up to [to], exclusive, newest first.
  Stream<List<MorningReportRow>> watchReportsBetween(
    DateTime from,
    DateTime to,
  ) =>
      (select(morningReportsTable)
            ..where(
              (t) =>
                  t.createdAt.isBiggerOrEqualValue(
                    from.millisecondsSinceEpoch,
                  ) &
                  t.createdAt.isSmallerThanValue(to.millisecondsSinceEpoch),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// The newest [limit] reports, newest first.
  Stream<List<MorningReportRow>> watchReports({int limit = 8}) =>
      (select(morningReportsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();
}
