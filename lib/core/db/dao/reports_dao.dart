import 'package:drift/drift.dart';

import '../database.dart';
import 'recovery_dao.dart';

part 'reports_dao.drift.dart';

/// The morning reports, one per day, and the coach's word on each week.
@DriftAccessor(tables: [MorningReportsTable, WeekReviewsTable])
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

  /// Stores what the coach wrote about the week from [start]. Writing it again
  /// replaces it.
  Future<void> saveWeekReview({
    required DateTime start,
    required DateTime createdAt,
    required String facts,
    String? coachText,
    String? coachError,
    int? requests,
    int? inputTokens,
    int? outputTokens,
  }) => into(weekReviewsTable).insertOnConflictUpdate(
    WeekReviewsTableCompanion.insert(
      id: RecoveryDao.dayKey(start),
      weekStart: start.millisecondsSinceEpoch,
      createdAt: createdAt.millisecondsSinceEpoch,
      facts: facts,
      coachText: Value(coachText),
      coachError: Value(coachError),
      requests: Value(requests),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
    ),
  );

  Future<WeekReviewRow?> weekReviewFor(DateTime start) => (select(
    weekReviewsTable,
  )..where((t) => t.id.equals(RecoveryDao.dayKey(start)))).getSingleOrNull();

  Stream<WeekReviewRow?> watchWeekReview(DateTime start) => (select(
    weekReviewsTable,
  )..where((t) => t.id.equals(RecoveryDao.dayKey(start)))).watchSingleOrNull();
}
