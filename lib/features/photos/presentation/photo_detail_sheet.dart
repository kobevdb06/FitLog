/// A look at one photograph, without leaving the grid.
///
/// Tapping a tile used to do nothing at all - only a long press did something,
/// and that was deleting it. This is what a tap does instead: the picture at a
/// size you can read, when it was taken, what you wrote about it, and which
/// session it belongs to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import 'photo_editor_screen.dart';
import 'photo_providers.dart';
import 'photo_viewer_screen.dart';

Future<void> showPhotoDetail(
  BuildContext context, {
  required String photoId,
  required DateTime takenAt,
}) {
  return showAppSheet<void>(
    context: context,
    // The date rather than the word "foto": the sheet holds one picture and
    // you already know it is a picture. When it was taken is the thing you
    // came to find out.
    title: Formatters.fullDate(takenAt),
    builder: (context) => _PhotoDetail(photoId: photoId),
  );
}

class _PhotoDetail extends ConsumerWidget {
  const _PhotoDetail({required this.photoId});

  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched rather than passed in: the editor writes to the database and
    // this sheet is still open underneath it when it comes back.
    final photo = ref.watch(progressPhotoProvider(photoId)).value;
    final paths = ref.watch(appPathsProvider).value;

    if (photo == null || paths == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final takenAt = DateTime.fromMillisecondsSinceEpoch(photo.takenAt);
    final pose = PhotoPose.fromWire(photo.pose);
    final file = paths.photoFile(photo.fileName);
    final note = photo.note?.trim();
    final workout = ref.watch(photoWorkoutProvider(photo.workoutId)).value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tall enough to see, short enough to leave room for what is written
          // underneath it. A tap goes to the whole screen.
          GestureDetector(
            onTap: () => PhotoViewerScreen.open(
              context,
              file: file,
              title: '${pose.label} · ${Formatters.date(takenAt)}',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.42,
                width: double.infinity,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const MissingPhotoPlaceholder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pose.label, style: theme.textTheme.titleMedium),
                    Text(
                      Formatters.relativeDay(takenAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _edit(context, ref, photo),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Bewerken'),
              ),
            ],
          ),
          if (workout != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () {
                Navigator.of(context).pop();
                context.push(Routes.workoutDetail(workout.id));
              },
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workout.name, style: theme.textTheme.titleSmall),
                        Text(
                          'Die dag getraind',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(note, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ProgressPhotoRow photo,
  ) async {
    final deleted = await PhotoEditorScreen.open(context, photo);
    // The sheet is watching a row that no longer exists, so it would sit there
    // spinning forever waiting for it to come back.
    if (deleted && context.mounted) Navigator.of(context).pop();
  }
}
