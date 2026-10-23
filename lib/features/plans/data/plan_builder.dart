import '../../../core/db/database.dart';

/// Building a schema step by step: what Goedkeuren does, and what the coach
/// is asked next.
///
/// The outline first, then one session at a time, each approved before the
/// next is made. Goedkeuren returns the next question for the coach - in the
/// user's words, kept in the conversation like one they typed - or null when
/// there is nothing left to make.
abstract final class PlanBuilder {
  static Future<String?> approveOutline(AppDatabase db, String planId) async {
    await db.plansDao.approveOutline(planId, DateTime.now());
    final next = await _next(db, planId);
    return next == null ? null : 'De opzet is goed. Maak nu ${next.name}.';
  }

  static Future<String?> approveSession(
    AppDatabase db,
    String planId,
    String routineId,
  ) async {
    final session = await db.routinesDao.getRoutine(routineId);
    await db.plansDao.markSession(routineId, PlanSessionState.approved);
    final next = await _next(db, planId);
    if (session == null || next == null) return null;
    return '${session.name} is goed. Maak nu ${next.name}.';
  }

  /// The first session of the outline that has not been made yet.
  static Future<RoutineRow?> _next(AppDatabase db, String planId) async =>
      (await db.plansDao.sessions(planId))
          .where((s) => s.sessionState == PlanSessionState.planned)
          .firstOrNull;
}
