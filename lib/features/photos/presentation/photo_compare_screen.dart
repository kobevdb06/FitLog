import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/common.dart';
import 'photos_screen.dart';

/// Two photos side by side with their dates and the weight difference.
class PhotoCompareScreen extends ConsumerStatefulWidget {
  const PhotoCompareScreen({super.key});

  @override
  ConsumerState<PhotoCompareScreen> createState() =>
      _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends ConsumerState<PhotoCompareScreen> {
  String? _leftId;
  String? _rightId;

  ProgressPhotoRow? _find(List<ProgressPhotoRow> photos, String? id) {
    if (id == null) return null;
    for (final p in photos) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(progressPhotosProvider).value ?? const [];
    final paths = ref.watch(appPathsProvider).value;

    if (photos.length < 2 || paths == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vergelijken')),
        body: const EmptyState(
          icon: Icons.compare_arrows,
          title: 'Te weinig foto\'s',
          message: 'Je hebt minstens twee foto\'s nodig om te vergelijken.',
        ),
      );
    }

    // Default to the oldest and the newest, which is what people want to see.
    _leftId ??= photos.last.id;
    _rightId ??= photos.first.id;

    final left = _find(photos, _leftId) ?? photos.last;
    final right = _find(photos, _rightId) ?? photos.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Vergelijken')),
      body: Column(
        children: [
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
      ),
    );
  }
}

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
          child: Image.file(
            paths.photoFile(photo.fileName),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stack) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: DropdownButton<String>(
            isExpanded: true,
            value: photo.id,
            underline: const SizedBox.shrink(),
            items: [
              for (final p in photos)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    '${Formatters.date(DateTime.fromMillisecondsSinceEpoch(p.takenAt))}'
                    ' · ${PhotoPose.fromWire(p.pose).label}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
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
        dao.weightNearest(
          DateTime.fromMillisecondsSinceEpoch(left.takenAt),
        ),
        dao.weightNearest(
          DateTime.fromMillisecondsSinceEpoch(right.takenAt),
        ),
      ]),
      builder: (context, snapshot) {
        final days =
            DateTime.fromMillisecondsSinceEpoch(right.takenAt)
                .difference(
                  DateTime.fromMillisecondsSinceEpoch(left.takenAt),
                )
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
                    value:
                        '${delta > 0 ? '+' : ''}${formatters.weight(delta)}',
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
