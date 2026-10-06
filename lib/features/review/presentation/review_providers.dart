import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../data/week_facts_builder.dart';
import '../domain/week_facts.dart';

part 'review_providers.g.dart';

/// The week from [start], worked out from the logbook as it is now.
@riverpod
Future<WeekFacts> weekFacts(Ref ref, DateTime start) =>
    buildWeekFacts(ref.watch(databaseProvider), start);
