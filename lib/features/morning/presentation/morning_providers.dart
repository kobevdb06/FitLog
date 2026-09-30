import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../health/presentation/health_providers.dart';
import '../data/morning_reporter.dart';
import '../data/morning_run.dart';

part 'morning_providers.g.dart';

/// The last week or so of reports, newest first.
@riverpod
Stream<List<MorningReport>> morningReports(Ref ref) => ref
    .watch(databaseProvider)
    .reportsDao
    .watchReports()
    .map((rows) => [for (final row in rows) MorningReport.fromRow(row)]);

class MorningState {
  const MorningState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

/// Making a report now, from the button on the recovery screen.
@Riverpod(keepAlive: true)
class MorningController extends _$MorningController {
  @override
  MorningState build() => const MorningState();

  Future<MorningReport?> makeNow({DateTime? now}) async {
    if (state.busy) return null;
    state = const MorningState(busy: true);
    try {
      final report = await runMorning(
        db: ref.read(databaseProvider),
        source: ref.read(healthSourceProvider),
        clientFactory: ref.read(coachClientFactoryProvider),
        now: now,
      );
      if (ref.mounted) state = const MorningState();
      return report;
    } on Object catch (error) {
      if (ref.mounted) {
        state = MorningState(error: 'Het rapport opstellen lukte niet: $error');
      }
      return null;
    }
  }
}
