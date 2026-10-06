import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/week_facts_builder.dart';
import '../data/week_reviewer.dart';
import '../domain/week_facts.dart';

part 'review_providers.g.dart';

/// The week from [start], worked out from the logbook as it is now.
@riverpod
Future<WeekFacts> weekFacts(Ref ref, DateTime start) =>
    buildWeekFacts(ref.watch(databaseProvider), start);

/// What the coach wrote about the week from [start], if it did.
@riverpod
Stream<WeekReview?> weekReview(Ref ref, DateTime start) => ref
    .watch(databaseProvider)
    .reportsDao
    .watchWeekReview(start)
    .map((row) => row == null ? null : WeekReview.fromRow(row));

class WeekReviewState {
  const WeekReviewState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

/// Having the coach write about a week.
@Riverpod(keepAlive: true)
class WeekReviewController extends _$WeekReviewController {
  @override
  WeekReviewState build() => const WeekReviewState();

  Future<WeekReview?> write(DateTime start, {DateTime? now}) async {
    if (state.busy) return null;
    state = const WeekReviewState(busy: true);
    try {
      final review = await WeekReviewer(
        ref.read(databaseProvider),
        clientFactory: ref.read(coachClientFactoryProvider),
      ).write(start, now: now);
      if (ref.mounted) state = const WeekReviewState();
      return review;
    } on Object catch (error) {
      if (ref.mounted) {
        state = WeekReviewState(
          error: 'Het weekoverzicht laten schrijven lukte niet: $error',
        );
      }
      return null;
    }
  }
}
