import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../chat/data/ai_client.dart';
import '../../chat/presentation/chat_providers.dart';
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
  String? _equipment;
  final _notesController = TextEditingController();

  String? _primaryMuscle;
  final Set<String> _secondaryMuscles = {};
  CategoryChoice _category = const CategoryChoice(ExerciseCategory.barbell);

  /// The two frames, as file names in the photo directory.
  String? _startImage;
  String? _endImage;

  /// Frames the row still points at but that this edit has replaced. They are
  /// deleted on save, never before: until then the row is unchanged and the
  /// user can still walk away from the edit.
  final List<String> _replaced = [];

  /// Which of the two frames came out of a model rather than a camera.
  ///
  /// Per slot, because the line under the name on the detail screen only says
  /// something true as long as a picture it is about is still there. Take the
  /// drawing away, or put a real photo in its place, and it has nothing left
  /// to warn about.
  final Set<_Slot> _drawn = {};

  /// What both drawings of this exercise are drawn from.
  ///
  /// The same number twice gives the same person in the same clothes, so the
  /// only difference between the two pictures is the posture - which is the
  /// one thing they are there for. Asking for a slot again that already has a
  /// drawing rolls a new one: you tapped a second time because you wanted
  /// something else.
  int? _seed;

  bool _loaded = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefill(ExerciseRow row) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = row.name;
    _equipment = row.equipment;
    _notesController.text = row.instructions ?? '';
    _primaryMuscle = row.primaryMuscle;
    _secondaryMuscles.addAll(decodeSecondaryMuscles(row.secondaryMuscles));
    _category = row.categoryChoice;
    _startImage = row.startImageFile;
    _endImage = row.endImageFile;
    if (row.imagesGenerated) {
      if (_startImage != null) _drawn.add(_Slot.start);
      if (_endImage != null) _drawn.add(_Slot.end);
    }
  }

  /// Picks one frame and puts it in [slot].
  ///
  /// The picked file is copied and processed straight away, so what the slot
  /// shows from here on is the file that will be stored - not the temporary
  /// one the picker handed over, which the system may delete at any moment.
  /// What the sheet returns when you pick "laten tekenen".
  static const Object _draw = 'draw';

  /// Draws the illustration and puts it in the slot.
  ///
  /// The name and the muscle are what it is drawn from, so both have to be
  /// filled in first - a picture of "" is a waste of your credit.
  ///
  /// You are shown the sentence before it is sent, and you can rewrite it.
  /// No fixed wording gets every exercise right: asked for an overhead
  /// triceps extension the model drew someone doing a pull-up, and the word
  /// that caused it was "bar". Whoever knows the exercise can take that word
  /// out; the app cannot.
  Future<void> _drawFrame(_Slot slot) async {
    final name = _nameController.text.trim();
    final muscle = _primaryMuscle;
    if (name.isEmpty || muscle == null) {
      setState(
        () => _error =
            'Geef eerst een naam en een spiergroep; daar wordt de '
            'tekening uit gemaakt.',
      );
      return;
    }

    final asked = await promptForText(
      context,
      title: slot == _Slot.start
          ? 'Wat toont de startpositie?'
          : 'Wat toont de eindpositie?',
      initialValue: ImageGenerator.describe(
        name: name,
        equipment: _equipment?.trim(),
        start: slot == _Slot.start,
      ),
      hintText: 'In het Engels - daar tekent het model het best van.',
      confirmLabel: 'Tekenen',
      maxLines: 4,
      maxLength: ImageGenerator.maxPromptLength,
      capitalization: TextCapitalization.none,
    );
    final wanted = asked?.trim();
    if (wanted == null || wanted.isEmpty || !mounted) return;

    final again = _drawn.contains(slot);
    setState(() {
      _busy = true;
      _error = null;
      if (_seed == null || again) _seed = Random().nextInt(1 << 31);
    });
    try {
      final fileName = await ref
          .read(exerciseEditorProvider)
          .drawFrame(
            name: name,
            start: slot == _Slot.start,
            equipment: _equipment?.trim(),
            prompt: wanted,
            seed: _seed,
          );
      if (!mounted) return;
      if (fileName == null) {
        setState(() => _error = 'Er staat geen Hugging Face-token ingesteld.');
        return;
      }
      setState(() {
        _setFrame(slot, fileName);
        _drawn.add(slot);
      });
    } on CoachException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// [canDraw] comes from build, where it is watched.
  ///
  /// Reading it here instead answers "still loading" when nothing is
  /// subscribed to the settings - which would read as "no token" and hide the
  /// option from someone who has one.
  Future<void> _pickFrame(_Slot slot, {required bool canDraw}) async {
    final source = await showAppSheet<Object>(
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
          if (canDraw)
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Laten tekenen'),
              subtitle: const Text(
                'Een tekening van het materiaal, geen foto van de uitvoering. '
                'Kost tegoed bij Hugging Face.',
              ),
              onTap: () => Navigator.of(context).pop(_draw),
            ),
        ],
      ),
    );
    if (source == null) return;
    if (source == _draw) {
      await _drawFrame(slot);
      return;
    }
    if (source is! ImageSource) return;

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
    // Whatever lands here now, it is not the drawing that was in this slot.
    // The caller that draws puts the mark back.
    _drawn.remove(slot);
    final previous = slot == _Slot.start ? _startImage : _endImage;
    if (previous != null) _replaced.add(previous);
    if (slot == _Slot.start) {
      _startImage = fileName;
    } else {
      _endImage = fileName;
    }
  }

  Future<void> _pickEquipment(List<String> options) async {
    final picked = await pickEquipment(
      context,
      current: _equipment,
      equipment: options,
      onAddNew: () => _addEquipment(context),
    );
    if (picked == null) return;
    setState(() => _equipment = picked.name);
  }

  /// Adds it and picks it in one go: you only open this because the one you
  /// need is not on the list.
  Future<void> _addMuscle(BuildContext context) async {
    final name = await promptForText(
      context,
      title: 'Spiergroep toevoegen',
      hintText: 'bijvoorbeeld serratus',
    );
    final trimmed = name?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) return;

    await ref.read(databaseProvider).exercisesDao.addCustomMuscle(trimmed);
    if (mounted) setState(() => _primaryMuscle = trimmed);
  }

  /// Adds a category of your own and picks it, from inside the picker.
  ///
  /// Two questions rather than one: a name, and which of the built-in
  /// categories it counts as. The second one is not decoration - it decides
  /// what a set of this exercise will ask you for.
  Future<void> _addCategory(BuildContext context) async {
    final name = await promptForText(
      context,
      title: 'Categorie toevoegen',
      hintText: 'bijvoorbeeld slee',
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !context.mounted) return;

    final base = await pickCategoryBase(context);
    if (base == null) return;

    await ref
        .read(databaseProvider)
        .exercisesDao
        .addCustomCategory(trimmed, base.wire);
    if (mounted) setState(() => _category = CategoryChoice(base, trimmed));
  }

  Future<void> _addEquipment(BuildContext context) async {
    final name = await promptForText(
      context,
      title: 'Materiaal toevoegen',
      hintText: 'bijvoorbeeld ringen',
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    await ref.read(databaseProvider).exercisesDao.addCustomEquipment(trimmed);
    if (mounted) setState(() => _equipment = trimmed);
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
    final equipment = _equipment?.trim() ?? '';

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
        imagesGenerated: _drawn.isNotEmpty,
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
        imagesGenerated: _drawn.isNotEmpty,
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
    final equipmentOptions =
        ref.watch(equipmentOptionsProvider).value ?? const [];
    final categories =
        ref.watch(categoryOptionsProvider).value ??
        [for (final c in ExerciseCategory.values) CategoryChoice(c)];
    final paths = ref.watch(appPathsProvider).value;
    // Watched, not read: see _pickFrame.
    final canDraw = ref.watch(canDrawImagesProvider);

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
        actions: [TextButton(onPressed: _save, child: const Text('Opslaan'))],
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
          PickerField(
            label: 'Categorie',
            leading: Icon(exerciseCategoryIcon(_category.base)),
            text: _category.label,
            onTap: () async {
              final picked = await pickExerciseCategory(
                context,
                current: _category,
                options: categories,
                onAddNew: () => _addCategory(context),
              );
              if (picked != null) setState(() => _category = picked);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          PickerField(
            label: 'Primaire spiergroep',
            leading: _primaryMuscle == null
                ? null
                : MuscleAvatar(muscle: _primaryMuscle, size: 28),
            text: _primaryMuscle ?? 'Kies een spiergroep',
            muted: _primaryMuscle == null,
            onTap: () async {
              final picked = await pickMuscle(
                context,
                current: _primaryMuscle,
                muscles: muscles,
                onAddNew: () => _addMuscle(context),
              );
              if (picked != null) setState(() => _primaryMuscle = picked);
            },
          ),
          const SectionHeader(
            'Secundaire spiergroepen',
            padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
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
          PickerField(
            label: 'Materiaal',
            leading: Icon(
              _equipment == null ? Icons.block : Icons.fitness_center_outlined,
            ),
            text: _equipment ?? 'Geen materiaal',
            muted: _equipment == null,
            onTap: () => _pickEquipment(equipmentOptions),
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
            padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xs),
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
                    onPick: () => _pickFrame(_Slot.start, canDraw: canDraw),
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
                    onPick: () => _pickFrame(_Slot.end, canDraw: canDraw),
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
