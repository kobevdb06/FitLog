import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../data/photo_store.dart';
import '../domain/photo_grouping.dart';
import 'photo_detail_sheet.dart';
import 'photo_providers.dart';

/// Progress photos, grouped per month.
class PhotosScreen extends ConsumerWidget {
  const PhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(progressPhotosProvider);
    final paths = ref.watch(appPathsProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voortgangsfoto\'s'),
        actions: [
          IconButton(
            tooltip: 'Vergelijken',
            onPressed: () => context.push(Routes.photoCompare),
            icon: const Icon(Icons.compare_arrows),
          ),
        ],
      ),
      body: photos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (list) {
          // The documents directory is still being resolved; showing the
          // empty state here would claim there are no photos when there are.
          if (paths == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.photo_camera_outlined,
              title: 'Nog geen foto\'s',
              message:
                  'Een foto om de paar weken laat verandering zien die de '
                  'weegschaal mist.',
              actionLabel: 'Foto toevoegen',
              onAction: () => _add(context, ref),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final month in groupPhotos(list)) ...[
                SectionHeader(Formatters.monthYear(month.month)),
                for (final day in month.days) ...[
                  _DayHeader(day: day.day),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: day.photos.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.72,
                          ),
                      itemBuilder: (context, index) =>
                          _PhotoTile(photo: day.photos[index], paths: paths),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Foto'),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final pose = await pickPose(context);
    if (pose == null || !context.mounted) return;

    final source = await showAppSheet<ImageSource>(
      context: context,
      title: 'Waar komt de foto vandaan?',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Nu een foto maken'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Uit de galerij kiezen'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;

    try {
      await ref.read(photoActionsProvider).add(source: source, pose: pose);
    } on UnreadableImageException {
      if (context.mounted) {
        showSnack(
          context,
          'Dat bestand kon niet als foto gelezen worden.',
          isError: true,
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        showSnack(context, 'Foto opslaan mislukte: $error', isError: true);
      }
    }
  }
}

/// The day above one row of tiles.
///
/// Smaller than the month above it: the month is where you are in the list,
/// the day is which pictures belong together.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relative = Formatters.relativeDay(day);
    final recent = relative == Formatters.date(day) ? null : relative;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            Formatters.weekdayDayMonth(day),
            style: theme.textTheme.labelLarge,
          ),
          // Only while it still means something. Past a week `relativeDay`
          // falls back to the date, and repeating the date next to the date
          // says nothing.
          if (recent != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              recent.toLowerCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo, required this.paths});

  final ProgressPhotoRow photo;
  final AppPaths paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = paths.photoFile(photo.fileName);

    return GestureDetector(
      onTap: () => showPhotoDetail(
        context,
        photoId: photo.id,
        takenAt: DateTime.fromMillisecondsSinceEpoch(photo.takenAt),
      ),
      onLongPress: () async {
        final ok = await confirm(
          context,
          title: 'Foto verwijderen?',
          message: 'De foto wordt van je toestel verwijderd.',
          confirmLabel: 'Verwijderen',
          destructive: true,
        );
        if (ok) await ref.read(photoActionsProvider).delete(photo);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 320,
              errorBuilder: (context, error, stack) =>
                  const MissingPhotoPlaceholder(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: Colors.black.withValues(alpha: 0.55),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        // The date is gone: the day above the grid already
                        // says it, on every tile underneath it.
                        PhotoPose.fromWire(photo.pose).label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    // Small marks for what is behind the picture, so a note
                    // you wrote is not invisible until you open it.
                    if (photo.workoutId != null)
                      const Icon(
                        Icons.fitness_center,
                        size: 12,
                        color: Colors.white70,
                      ),
                    if (photo.note != null && photo.note!.trim().isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: Icon(
                          Icons.sticky_note_2_outlined,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
