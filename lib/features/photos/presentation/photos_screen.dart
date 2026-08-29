import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';

part 'photos_screen.g.dart';

@riverpod
Stream<List<ProgressPhotoRow>> progressPhotos(Ref ref) =>
    ref.watch(databaseProvider).recordsDao.watchPhotos();

@riverpod
PhotoActions photoActions(Ref ref) => PhotoActions(ref);

/// Adding and removing progress photos.
///
/// The image file is copied into the app's own documents directory; nothing is
/// written to the camera roll and nothing leaves the device.
class PhotoActions {
  const PhotoActions(this.ref);

  final Ref ref;

  static const _uuid = Uuid();

  Future<String?> add({
    required ImageSource source,
    required PhotoPose pose,
    DateTime? takenAt,
    String? note,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final paths = await ref.read(appPathsProvider.future);
    final dir = await paths.ensurePhotosDirectory();
    final extension = picked.path.split('.').last.toLowerCase();
    final fileName =
        '${_uuid.v4()}.${extension.length <= 4 ? extension : 'jpg'}';

    await File(picked.path).copy('${dir.path}/$fileName');

    return ref
        .read(databaseProvider)
        .recordsDao
        .addPhoto(
          fileName: fileName,
          pose: pose,
          takenAt: takenAt ?? DateTime.now(),
          note: note,
        );
  }

  Future<void> delete(ProgressPhotoRow photo) async {
    final paths = await ref.read(appPathsProvider.future);
    final file = paths.photoFile(photo.fileName);
    if (await file.exists()) await file.delete();
    await ref.read(databaseProvider).recordsDao.deletePhoto(photo.id);
  }

  Future<AppPaths> paths() => ref.read(appPathsProvider.future);
}

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
          if (list.isEmpty || paths == null) {
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

    await ref.read(photoActionsProvider).add(source: source, pose: pose);
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
              errorBuilder: (context, error, stack) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
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
