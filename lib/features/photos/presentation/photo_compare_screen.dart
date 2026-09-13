/// The photographs you picked, next to each other.
///
/// It used to pick for you - oldest against newest - and let you swap either
/// half from a dropdown. That made it easy to put a front against a back and
/// read "0 dagen ertussen, 0 kg" off it. You choose them in the grid now, so
/// what is on screen is what you asked for.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/common.dart';
import '../domain/photo_grouping.dart';
import 'photo_providers.dart';
import 'photo_viewer_screen.dart';
import 'photo_wipe.dart';

/// How a pair is laid out. Three or more are always a row.
enum _Layout { sideBySide, wipe }

class PhotoCompareScreen extends ConsumerStatefulWidget {
  const PhotoCompareScreen({super.key, required this.photoIds});

  final List<String> photoIds;

  @override
  ConsumerState<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends ConsumerState<PhotoCompareScreen> {
  _Layout _layout = _Layout.sideBySide;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(progressPhotosProvider).value ?? const [];
    final paths = ref.watch(appPathsProvider).value;

    if (paths == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vergelijken')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final chosen = chosenPhotos(all: all, ids: widget.photoIds);

    if (chosen.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vergelijken')),
        body: const EmptyState(
          icon: Icons.compare_arrows,
          title: 'Te weinig foto\'s',
          message: 'Kies er minstens twee in het raster om te vergelijken.',
        ),
      );
    }

    final pair = chosen.length == 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vergelijken'),
        actions: [
          // Only for a pair: a seam between three pictures is not a thing.
          if (pair)
            IconButton(
              tooltip: _layout == _Layout.wipe
                  ? 'Naast elkaar'
                  : 'Over elkaar schuiven',
              onPressed: () => setState(() {
                _layout = _layout == _Layout.wipe
                    ? _Layout.sideBySide
                    : _Layout.wipe;
              }),
              icon: Icon(
                _layout == _Layout.wipe
                    ? Icons.view_column_outlined
                    : Icons.compare_outlined,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (mixedPoses(chosen)) _MixedPoseNote(photos: chosen),
          Expanded(
            child: pair && _layout == _Layout.wipe
                ? _Wipe(photos: chosen, paths: paths)
                : _Row(photos: chosen, paths: paths),
          ),
          _Difference(left: chosen.first, right: chosen.last),
        ],
      ),
    );
  }
}

/// Said once, at the top, and never enforced.
///
/// A front against a back says little, but it is your comparison. The app used
/// to build that for you, which is a different thing from letting you.
class _MixedPoseNote extends StatelessWidget {
  const _MixedPoseNote({required this.photos});

  final List<ProgressPhotoRow> photos;

  @override
  Widget build(BuildContext context) {
    final poses = {
      for (final photo in photos) PhotoPose.fromWire(photo.pose).label,
    };
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Je vergelijkt ${poses.join(' met ')}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two or more, in the order they were taken.
///
/// Past two it scrolls sideways rather than dividing the width further: four
/// photographs squeezed into one screen are four postage stamps, and a
/// comparison you cannot see is not one.
class _Row extends StatelessWidget {
  const _Row({required this.photos, required this.paths});

  final List<ProgressPhotoRow> photos;
  final AppPaths paths;

  @override
  Widget build(BuildContext context) {
    final pair = photos.length <= 2;
    // Two and a bit on screen, so the edge of the next one says there is more.
    final columns = pair ? photos.length : 2.4;
    final width = MediaQuery.of(context).size.width / columns;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: pair ? const NeverScrollableScrollPhysics() : null,
      itemCount: photos.length,
      separatorBuilder: (context, index) => const VerticalDivider(width: 1),
      itemBuilder: (context, index) => SizedBox(
        width: width,
        child: _Side(photo: photos[index], paths: paths),
      ),
    );
  }
}

class _Wipe extends StatelessWidget {
  const _Wipe({required this.photos, required this.paths});

  final List<ProgressPhotoRow> photos;
  final AppPaths paths;

  @override
  Widget build(BuildContext context) {
    final left = photos.first;
    final right = photos.last;

    return Column(
      children: [
        Expanded(
          child: PhotoWipe(
            left: paths.photoFile(left.fileName),
            right: paths.photoFile(right.fileName),
            onTapLeft: () => _open(context, left),
            onTapRight: () => _open(context, right),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_dateOf(left), style: Theme.of(context).textTheme.bodySmall),
              Text(
                _dateOf(right),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dateOf(ProgressPhotoRow photo) =>
      Formatters.date(DateTime.fromMillisecondsSinceEpoch(photo.takenAt));

  void _open(BuildContext context, ProgressPhotoRow photo) {
    PhotoViewerScreen.open(
      context,
      file: paths.photoFile(photo.fileName),
      title: '${PhotoPose.fromWire(photo.pose).label} · ${_dateOf(photo)}',
    );
  }
}

/// One picture and the day it was taken.
class _Side extends StatelessWidget {
  const _Side({required this.photo, required this.paths});

  final ProgressPhotoRow photo;
  final AppPaths paths;

  @override
  Widget build(BuildContext context) {
    final takenAt = DateTime.fromMillisecondsSinceEpoch(photo.takenAt);
    final file = paths.photoFile(photo.fileName);

    return Column(
      children: [
        Expanded(
          // Whole, not filled. Cover looked tidier and quietly cut the sides
          // off: a column this narrow is a small window on a portrait photo,
          // and off-centre subjects went with the crop.
          child: GestureDetector(
            onTap: () => PhotoViewerScreen.open(
              context,
              file: file,
              title:
                  '${PhotoPose.fromWire(photo.pose).label} · '
                  '${Formatters.date(takenAt)}',
            ),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (context, error, stack) =>
                  const MissingPhotoPlaceholder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            Formatters.date(takenAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Difference extends ConsumerWidget {
  const _Difference({required this.left, required this.right});

  final ProgressPhotoRow left;
  final ProgressPhotoRow right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    final dao = ref.watch(databaseProvider).recordsDao;

    return FutureBuilder<List<BodyMeasurementRow?>>(
      future: Future.wait([
        dao.weightNearest(DateTime.fromMillisecondsSinceEpoch(left.takenAt)),
        dao.weightNearest(DateTime.fromMillisecondsSinceEpoch(right.takenAt)),
      ]),
      builder: (context, snapshot) {
        final days = DateTime.fromMillisecondsSinceEpoch(right.takenAt)
            .difference(DateTime.fromMillisecondsSinceEpoch(left.takenAt))
            .inDays
            .abs();

        final a = snapshot.data?[0];
        final b = snapshot.data?[1];
        final delta = (a == null || b == null) ? null : b.value - a.value;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatTile(value: '$days', label: 'Dagen ertussen'),
                if (delta != null)
                  StatTile(
                    value: '${delta > 0 ? '+' : ''}${formatters.weight(delta)}',
                    label: 'Gewichtsverschil',
                    emphasis: true,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
