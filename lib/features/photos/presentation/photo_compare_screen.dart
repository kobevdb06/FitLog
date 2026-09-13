import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../domain/photo_grouping.dart';
import 'photo_providers.dart';
import 'photo_viewer_screen.dart';

/// Two photos side by side with their dates and the weight difference.
class PhotoCompareScreen extends ConsumerStatefulWidget {
  const PhotoCompareScreen({super.key});

  @override
  ConsumerState<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends ConsumerState<PhotoCompareScreen> {
  PhotoPose? _pose;
  String? _leftId;
  String? _rightId;

  ProgressPhotoRow? _find(List<ProgressPhotoRow> photos, String? id) {
    for (final photo in photos) {
      if (photo.id == id) return photo;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(progressPhotosProvider).value ?? const [];
    final paths = ref.watch(appPathsProvider).value;

    // The pose is the comparison, not one of its halves: a front against a
    // back has nothing to say, and the screen used to let you build exactly
    // that - two photos of the same morning, "0 dagen ertussen, 0 kg".
    final pose = _pose ?? mostComparablePose(all);
    final photos = [
      for (final photo in all)
        if (PhotoPose.fromWire(photo.pose) == pose) photo,
    ];

    if (paths == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vergelijken')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (all.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vergelijken')),
        body: const EmptyState(
          icon: Icons.compare_arrows,
          title: 'Te weinig foto\'s',
          message: 'Je hebt minstens twee foto\'s nodig om te vergelijken.',
        ),
      );
    }

    // Oldest against newest of this pose, which is what people are after.
    final left =
        _find(photos, _leftId) ?? (photos.isEmpty ? null : photos.last);
    final right =
        _find(photos, _rightId) ?? (photos.isEmpty ? null : photos.first);

    return Scaffold(
      appBar: AppBar(title: const Text('Vergelijken')),
      body: Column(
        children: [
          _PoseBar(
            pose: pose,
            counts: photosPerPose(all),
            onChanged: (picked) => setState(() {
              _pose = picked;
              // The chosen moments belonged to the old pose.
              _leftId = null;
              _rightId = null;
            }),
          ),
          if (left == null || right == null || photos.length < 2)
            Expanded(
              child: EmptyState(
                icon: Icons.compare_arrows,
                title: 'Te weinig van deze pose',
                message:
                    'Je hebt twee foto\'s van dezelfde pose nodig. Van '
                    '${pose.label.toLowerCase()} heb je er '
                    '${photos.length}.',
              ),
            )
          else ...[
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _Side(
                      photo: left,
                      photos: photos,
                      paths: paths,
                      onChanged: (id) => setState(() => _leftId = id),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _Side(
                      photo: right,
                      photos: photos,
                      paths: paths,
                      onChanged: (id) => setState(() => _rightId = id),
                    ),
                  ),
                ],
              ),
            ),
            _Difference(left: left, right: right),
          ],
        ],
      ),
    );
  }
}

/// Which pose you are comparing, and how many you have of each.
class _PoseBar extends StatelessWidget {
  const _PoseBar({
    required this.pose,
    required this.counts,
    required this.onChanged,
  });

  final PhotoPose pose;
  final Map<PhotoPose, int> counts;
  final ValueChanged<PhotoPose> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      // A Row clipped the third chip off the right edge of a phone. A Wrap
      // moves one down instead of hiding it, whatever the screen width or the
      // reader's text size.
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final option in PhotoPose.values)
            ChoiceChip(
              selected: option == pose,
              onSelected: (_) => onChanged(option),
              visualDensity: VisualDensity.compact,
              labelStyle: Theme.of(context).textTheme.bodyMedium,
              // The count is the honest part: it says in advance which poses
              // there is anything to compare.
              label: Text('${option.label} (${counts[option] ?? 0})'),
            ),
        ],
      ),
    );
  }
}

/// One half of the comparison: the picture, and which moment it is.
///
/// The pose is not repeated here - the bar above the two halves says it once,
/// and it is the same for both by definition.
class _Side extends StatelessWidget {
  const _Side({
    required this.photo,
    required this.photos,
    required this.paths,
    required this.onChanged,
  });

  final ProgressPhotoRow photo;
  final List<ProgressPhotoRow> photos;
  final AppPaths paths;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          // Whole, not filled. Cover looked tidier and quietly cut the sides
          // off: half a screen is a narrow window on a portrait photo, and if
          // you are not standing dead centre you can end up comparing two
          // walls. A tap opens the picture on its own, where there is room.
          child: GestureDetector(
            onTap: () => PhotoViewerScreen.open(
              context,
              file: paths.photoFile(photo.fileName),
              title:
                  '${PhotoPose.fromWire(photo.pose).label} · '
                  '${Formatters.date(DateTime.fromMillisecondsSinceEpoch(photo.takenAt))}',
            ),
            child: Image.file(
              paths.photoFile(photo.fileName),
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (context, error, stack) =>
                  const MissingPhotoPlaceholder(),
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            final picked = await pickPhoto(
              context,
              current: photo.id,
              photos: photos,
              fileFor: paths.photoFile,
            );
            if (picked != null) onChanged(picked);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Formatters.date(
                      DateTime.fromMillisecondsSinceEpoch(photo.takenAt),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
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
