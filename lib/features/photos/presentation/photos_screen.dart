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
import '../../../core/theme/app_colors.dart';
import '../domain/photo_grouping.dart';
import 'photo_detail_sheet.dart';
import 'photo_providers.dart';

/// Progress photos, grouped by month and day.
class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  /// Which photographs are ticked, or null when you are not choosing.
  ///
  /// A set rather than a flag plus a list: the tiles ask "am I in it" far more
  /// often than anything asks for the order, and the order is the order they
  /// were taken, which the comparison works out for itself.
  Set<String>? _chosen;

  bool get _choosing => _chosen != null;

  void _startChoosing(List<ProgressPhotoRow> newestFirst) {
    // Not from nothing: the two most recent of the pose you have most of is
    // the comparison people are after, and it is the one this screen used to
    // make for you. You can still untick either.
    setState(() => _chosen = defaultComparison(newestFirst).toSet());
  }

  void _toggle(String id) {
    final chosen = _chosen;
    if (chosen == null) return;

    if (chosen.contains(id)) {
      setState(() => chosen.remove(id));
      return;
    }
    if (chosen.length >= kMaxComparedPhotos) {
      showSnack(context, 'Hoogstens $kMaxComparedPhotos foto\'s tegelijk.');
      return;
    }
    setState(() => chosen.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(progressPhotosProvider);
    final paths = ref.watch(appPathsProvider).value;
    final list = photos.value ?? const [];
    final chosen = _chosen;

    return Scaffold(
      appBar: AppBar(
        title: Text(_choosing ? 'Kies foto\'s' : 'Voortgangsfoto\'s'),
        leading: _choosing
            ? IconButton(
                tooltip: 'Stoppen met kiezen',
                onPressed: () => setState(() => _chosen = null),
                icon: const Icon(Icons.close),
              )
            : null,
        actions: [
          if (!_choosing && list.length >= 2)
            IconButton(
              tooltip: 'Vergelijken',
              onPressed: () => _startChoosing(list),
              icon: const Icon(Icons.compare_arrows),
            ),
        ],
      ),
      bottomNavigationBar: chosen == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton.icon(
                  // Below two there is nothing to compare, and a button that
                  // explains why it did nothing is worse than one you can see
                  // is not ready.
                  onPressed: chosen.length < 2
                      ? null
                      : () {
                          setState(() => _chosen = null);
                          context.push(Routes.photoCompareOf(chosen));
                        },
                  icon: const Icon(Icons.compare_arrows),
                  label: Text('Vergelijk (${chosen.length})'),
                ),
              ),
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
                      itemBuilder: (context, index) {
                        final photo = day.photos[index];
                        return _PhotoTile(
                          photo: photo,
                          paths: paths,
                          chosen: chosen?.contains(photo.id),
                          onChoose: () => _toggle(photo.id),
                        );
                      },
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
  const _PhotoTile({
    required this.photo,
    required this.paths,
    required this.chosen,
    required this.onChoose,
  });

  final ProgressPhotoRow photo;
  final AppPaths paths;

  /// Null while you are not choosing, which is also when a tap opens the photo
  /// and a long press offers to delete it.
  final bool? chosen;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = paths.photoFile(photo.fileName);
    final choosing = chosen != null;

    return GestureDetector(
      onTap: choosing
          ? onChoose
          : () => showPhotoDetail(
              context,
              photoId: photo.id,
              takenAt: DateTime.fromMillisecondsSinceEpoch(photo.takenAt),
            ),
      // Deleting stays on the long press it has always been on, and steps
      // aside entirely while you are choosing: one tick away from a
      // confirmation you did not ask for is too close.
      onLongPress: choosing
          ? null
          : () async {
              final ok = await confirm(
                context,
                title: 'Foto verwijderen?',
                message: 'De foto wordt van je toestel verwijderd.',
                confirmLabel: 'Verwijderen',
                destructive: true,
              );
              if (ok) await ref.read(photoActionsProvider).delete(photo);
            },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: (chosen ?? false)
              ? Border.all(color: AppColors.accent, width: 3)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
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
            if (choosing)
              Container(
                color: Colors.black.withValues(alpha: chosen! ? 0.0 : 0.45),
              ),
            if (choosing)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  chosen! ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: chosen! ? AppColors.accent : Colors.white,
                ),
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
