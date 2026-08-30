import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../photos/data/photo_store.dart';
import 'exercise_providers.dart';

/// Creating or editing an exercise the user made themselves.
class CustomExerciseScreen extends ConsumerStatefulWidget {
  const CustomExerciseScreen({super.key, this.exerciseId});

  /// Pushes the editor and returns the id of the exercise that was saved.
  static Future<String?> open(BuildContext context, {String? exerciseId}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CustomExerciseScreen(exerciseId: exerciseId),
      ),
    );
  }

  final String? exerciseId;

  @override
  ConsumerState<CustomExerciseScreen> createState() =>
      _CustomExerciseScreenState();
}

class _CustomExerciseScreenState extends ConsumerState<CustomExerciseScreen> {
  final _nameController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _notesController = TextEditingController();

  String? _primaryMuscle;
  final Set<String> _secondaryMuscles = {};
  ExerciseCategory _category = ExerciseCategory.barbell;

  /// The two frames, as file names in the photo directory.
  String? _startImage;
  String? _endImage;

  /// Frames the row still points at but that this edit has replaced. They are
  /// deleted on save, never before: until then the row is unchanged and the
  /// user can still walk away from the edit.
  final List<String> _replaced = [];

  bool _loaded = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _equipmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefill(ExerciseRow row) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = row.name;
    _equipmentController.text = row.equipment ?? '';
    _notesController.text = row.instructions ?? '';
    _primaryMuscle = row.primaryMuscle;
    _secondaryMuscles.addAll(decodeSecondaryMuscles(row.secondaryMuscles));
    _category = ExerciseCategory.fromWire(row.category);
    _startImage = row.startImageFile;
    _endImage = row.endImageFile;
  }

  /// Picks one frame and puts it in [slot].
  ///
  /// The picked file is copied and processed straight away, so what the slot
  /// shows from here on is the file that will be stored - not the temporary
  /// one the picker handed over, which the system may delete at any moment.
  Future<void> _pickFrame(_Slot slot) async {
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

    setState(() => _busy = true);
    try {
      final fileName = await ref
          .read(exerciseEditorProvider)
          .pickFrame(
            source: source,
            exerciseId: widget.exerciseId,
            isStart: slot == _Slot.start,
          );
      if (fileName == null || !mounted) return;
      setState(() => _setFrame(slot, fileName));
    } on UnreadableImageException {
      if (mounted) {
        showSnack(
          context,
          'Dat bestand kon niet als foto gelezen worden.',
          isError: true,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, 'Foto opslaan mislukte: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setFrame(_Slot slot, String? fileName) {
    final previous = slot == _Slot.start ? _startImage : _endImage;
    if (previous != null) _replaced.add(previous);
    if (slot == _Slot.start) {
      _startImage = fileName;
    } else {
      _endImage = fileName;
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Geef de oefening een naam.');
      return;
    }
    final primary = _primaryMuscle;
    if (primary == null) {
      setState(() => _error = 'Kies een primaire spiergroep.');
      return;
    }

    final editor = ref.read(exerciseEditorProvider);
    final equipment = _equipmentController.text.trim();

    String id;
    if (widget.exerciseId == null) {
      id = await editor.create(
        name: name,
        primaryMuscle: primary,
        secondaryMuscles: _secondaryMuscles.toList(),
        category: _category,
        equipment: equipment.isEmpty ? null : equipment,
        instructions: _notesController.text,
        startImageFile: _startImage,
        endImageFile: _endImage,
      );
    } else {
      id = widget.exerciseId!;
      await editor.update(
        id: id,
        name: name,
        primaryMuscle: primary,
        secondaryMuscles: _secondaryMuscles.toList(),
        category: _category,
        equipment: equipment.isEmpty ? null : equipment,
        instructions: _notesController.text,
        startImageFile: _startImage,
        endImageFile: _endImage,
      );
    }

    // Only now, with the row pointing somewhere else, are the files it used to
    // point at safe to remove.
    for (final fileName in _replaced) {
      if (fileName == _startImage || fileName == _endImage) continue;
      await editor.discardFrame(fileName);
    }

    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final muscles = ref.watch(muscleOptionsProvider).value ?? const [];
    final paths = ref.watch(appPathsProvider).value;

    if (widget.exerciseId != null) {
      final existing = ref
          .watch(exerciseByIdProvider(widget.exerciseId!))
          .value;
      if (existing != null) _prefill(existing);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exerciseId == null ? 'Eigen oefening' : 'Oefening bewerken',
        ),
        actions: [
          TextButton(onPressed: _save, child: const Text('Opslaan')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Naam'),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<ExerciseCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Categorie'),
            items: [
              for (final c in ExerciseCategory.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: _primaryMuscle,
            decoration: const InputDecoration(
              labelText: 'Primaire spiergroep',
            ),
            items: [
              for (final m in muscles)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (value) => setState(() => _primaryMuscle = value),
          ),
          const SectionHeader(
            'Secundaire spiergroepen',
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.sm,
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final m in muscles)
                FilterChip(
                  label: Text(m),
                  selected: _secondaryMuscles.contains(m),
                  onSelected: (selected) => setState(() {
                    selected
                        ? _secondaryMuscles.add(m)
                        : _secondaryMuscles.remove(m);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _equipmentController,
            decoration: const InputDecoration(
              labelText: 'Materiaal',
              hintText: 'bijvoorbeeld halterstang',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _notesController,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notitie of uitvoering',
            ),
          ),
          const SectionHeader(
            'Uitvoering in beeld',
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.xs,
            ),
          ),
          Text(
            'Twee foto\'s - de start- en de eindpositie - lopen af als een '
            'animatie, net als bij de oefeningen uit de catalogus.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FrameSlot(
                    label: 'Startpositie',
                    fileName: _startImage,
                    paths: paths,
                    enabled: !_busy,
                    onPick: () => _pickFrame(_Slot.start),
                    onClear: () => setState(() => _setFrame(_Slot.start, null)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _FrameSlot(
                    label: 'Eindpositie',
                    fileName: _endImage,
                    paths: paths,
                    enabled: !_busy,
                    onPick: () => _pickFrame(_Slot.end),
                    onClear: () => setState(() => _setFrame(_Slot.end, null)),
                  ),
                ),
              ],
            ),
          ),
          if (_startImage == null || _endImage == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Met één foto blijft het een stilstaand beeld.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            InfoBanner(
              message: _error!,
              icon: Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
          ],
          if (widget.exerciseId != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Oefening verwijderen?',
                  message:
                      'Als de oefening al in een workout voorkomt, wordt ze '
                      'verborgen in plaats van verwijderd, zodat je '
                      'geschiedenis intact blijft.',
                  confirmLabel: 'Verwijderen',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                final deleted = await ref
                    .read(exerciseEditorProvider)
                    .removeOrArchive(widget.exerciseId!);
                if (!context.mounted) return;
                showSnack(
                  context,
                  deleted ? 'Oefening verwijderd' : 'Oefening verborgen',
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Oefening verwijderen'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Slot { start, end }

/// One of the two picture slots: a preview once filled, a prompt while empty.
class _FrameSlot extends StatelessWidget {
  const _FrameSlot({
    required this.label,
    required this.fileName,
    required this.paths,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String? fileName;
  final AppPaths? paths;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = fileName;
    final file = name == null ? null : paths?.photoFile(name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: InkWell(
            onTap: enabled ? onPick : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: file == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Foto kiezen',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Image.file(
                      file,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stack) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (file != null)
          TextButton.icon(
            onPressed: enabled ? onClear : null,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Verwijderen'),
          ),
      ],
    );
  }
}
