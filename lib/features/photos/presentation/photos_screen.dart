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

          final byMonth = <String, List<ProgressPhotoRow>>{};
          for (final photo in list) {
            final key = Formatters.monthYear(
              DateTime.fromMillisecondsSinceEpoch(photo.takenAt),
            );
            byMonth.putIfAbsent(key, () => []).add(photo);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final entry in byMonth.entries) ...[
                SectionHeader(entry.key),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entry.value.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.72,
                        ),
                    itemBuilder: (context, index) => _PhotoTile(
                      photo: entry.value[index],
                      paths: paths,
                    ),
                  ),
                ),
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
    final pose = await showAppSheet<PhotoPose>(
      context: context,
      title: 'Welke pose?',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final pose in PhotoPose.values)
            ListTile(
              title: Text(pose.label),
              onTap: () => Navigator.of(context).pop(pose),
            ),
        ],
      ),
    );
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

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo, required this.paths});

  final ProgressPhotoRow photo;
  final AppPaths paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = paths.photoFile(photo.fileName);

    return GestureDetector(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  '${PhotoPose.fromWire(photo.pose).label}\n'
                  '${Formatters.date(DateTime.fromMillisecondsSinceEpoch(photo.takenAt))}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
