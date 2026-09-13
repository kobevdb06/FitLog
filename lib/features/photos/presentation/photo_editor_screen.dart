/// Everything about a photograph except the photograph.
///
/// The picture itself is not editable: you replace it by taking another one.
/// What is editable is what turns a picture into a record - when it was taken,
/// which pose it is, what you want to remember about it, and which session it
/// belongs to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import 'photo_providers.dart';

class PhotoEditorScreen extends ConsumerStatefulWidget {
  const PhotoEditorScreen({super.key, required this.photo});

  /// Returns true when the photo was deleted, so the caller can close too.
  static Future<bool> open(BuildContext context, ProgressPhotoRow photo) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => PhotoEditorScreen(photo: photo)),
    );
    return deleted ?? false;
  }

  final ProgressPhotoRow photo;

  @override
  ConsumerState<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends ConsumerState<PhotoEditorScreen> {
  late PhotoPose _pose;
  late DateTime _takenAt;
  late String? _workoutId;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _pose = PhotoPose.fromWire(widget.photo.pose);
    _takenAt = DateTime.fromMillisecondsSinceEpoch(widget.photo.takenAt);
    _workoutId = widget.photo.workoutId;
    _note = TextEditingController(text: widget.photo.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workouts =
        ref.watch(workoutsAroundPhotoProvider(_takenAt)).value ?? const [];
    final linked = workouts.where((w) => w.id == _workoutId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto bewerken'),
        actions: [TextButton(onPressed: _save, child: const Text('Opslaan'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PickerField(
            label: 'Pose',
            text: _pose.label,
            onTap: () async {
              final picked = await pickPose(context, current: _pose);
              if (picked != null) setState(() => _pose = picked);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          PickerField(
            label: 'Datum',
            leading: const Icon(Icons.event_outlined),
            text: Formatters.fullDate(_takenAt),
            onTap: _pickDate,
          ),
          const SizedBox(height: AppSpacing.lg),
          PickerField(
            label: 'Workout',
            leading: Icon(
              linked == null
                  ? Icons.link_off_outlined
                  : Icons.fitness_center_outlined,
            ),
            // A linked session that is not in the list any more was moved to
            // another day or deleted; saying "geen" beats naming nothing.
            text: linked?.name ?? 'Geen workout',
            muted: linked == null,
            onTap: () => _pickWorkout(workouts),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sessies van rond deze dag. Zo weet je later niet alleen wanneer '
            'de foto genomen is, maar ook wat je er die dag voor deed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _note,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notitie',
              alignLabelWithHint: true,
              hintText: 'Bijvoorbeeld: ochtend, nuchter, zelfde licht',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: _delete,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Foto verwijderen'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _takenAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    // Keep the time of day: it is what orders two photos taken the same
    // morning, and a date picker has nothing to say about it.
    setState(() {
      _takenAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _takenAt.hour,
        _takenAt.minute,
      );
    });
  }

  Future<void> _pickWorkout(List<WorkoutRow> workouts) async {
    if (workouts.isEmpty) {
      showSnack(context, 'Geen sessies rond deze dag.');
      return;
    }

    final picked = await pickWorkoutForPhoto(
      context,
      current: _workoutId,
      workouts: workouts,
    );
    if (picked == null) return;
    setState(() => _workoutId = picked.id);
  }

  Future<void> _save() async {
    final note = _note.text.trim();
    await ref
        .read(photoActionsProvider)
        .update(
          widget.photo.id,
          pose: _pose,
          takenAt: _takenAt,
          note: note.isEmpty ? null : note,
          workoutId: _workoutId,
        );
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Foto verwijderen?',
      message: 'De foto wordt van je toestel verwijderd.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (!ok) return;

    await ref.read(photoActionsProvider).delete(widget.photo);
    if (mounted) Navigator.of(context).pop(true);
  }
}
