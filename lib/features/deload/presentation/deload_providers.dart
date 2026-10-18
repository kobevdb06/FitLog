import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';

part 'deload_providers.g.dart';

/// The deload going on now, or the next one planned; null without either.
@Riverpod(keepAlive: true)
Stream<DeloadWeekRow?> currentDeload(Ref ref) =>
    ref.watch(databaseProvider).deloadDao.watchAll().map((rows) {
      final now = DateTime.now();
      for (final row in rows) {
        if (row.isOnAt(now) || row.isAheadAt(now)) return row;
      }
      return null;
    });
