import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';

part 'plan_providers.g.dart';

/// Every schema, the last changed first.
@riverpod
Stream<List<TrainingPlanRow>> plans(Ref ref) =>
    ref.watch(databaseProvider).plansDao.watchPlans();

@riverpod
Stream<TrainingPlanRow?> plan(Ref ref, String id) =>
    ref.watch(databaseProvider).plansDao.watchPlan(id);

/// The schema being followed, if any.
@riverpod
Stream<TrainingPlanRow?> runningPlan(Ref ref) =>
    ref.watch(databaseProvider).plansDao.watchRunning();

/// The sessions of a schema, in its order.
@riverpod
Stream<List<RoutineRow>> planSessions(Ref ref, String planId) =>
    ref.watch(databaseProvider).plansDao.watchSessions(planId);

/// The conversations of the schema's, the last added to first.
@riverpod
Stream<List<ChatThreadRow>> planThreads(Ref ref) =>
    ref.watch(databaseProvider).chatDao.watchPlanThreads();
