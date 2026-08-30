import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../data/routine_import.dart';
import '../domain/routine_code.dart';
import 'qr_view.dart';

/// The code your friend points their camera at.
///
/// The bytes are base64 before they go in, which costs a third in size and
/// buys the certainty that any scanner hands them back unchanged: a raw binary
/// payload depends on the reader offering the bytes rather than a string, and
/// that is not something to find out in a gym.
class ShareRoutineScreen extends ConsumerWidget {
  const ShareRoutineScreen({super.key, required this.routineId});

  final String routineId;

  static Future<void> open(BuildContext context, String routineId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShareRoutineScreen(routineId: routineId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Delen via QR')),
      body: FutureBuilder<SharedRoutine>(
        future: sharedRoutineFor(ref.read(databaseProvider), routineId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Delen lukt niet',
              message: '${snapshot.error}',
            );
          }
          final routine = snapshot.data;
          if (routine == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (routine.exercises.isEmpty) {
            return const EmptyState(
              icon: Icons.qr_code_2,
              title: 'Niets te delen',
              message: 'Zet eerst een oefening in deze routine.',
            );
          }

          final payload = base64Url.encode(encodeRoutine(routine));

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(routine.name, style: theme.textTheme.headlineSmall),
              Text(
                [
                  '${routine.exercises.length} oefeningen',
                  if (routine.customCount > 0)
                    '${routine.customCount} eigen ${routine.customCount == 1 ? 'oefening' : 'oefeningen'}',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    // White regardless of the theme: a scanner needs the
                    // contrast the code was designed for.
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: QrView(data: payload, size: 280),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const InfoBanner(
                icon: Icons.wifi_off,
                message:
                    'De code bevat de routine zelf: oefeningen, sets en '
                    'rusttijden. Er gaat niets over het internet, en jouw '
                    'gewichten blijven van jou.',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Laat je vriend in FitLog op Scannen tikken en deze code '
                'lezen. Zet je scherm zo helder mogelijk.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
