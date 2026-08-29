import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
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

  bool _loaded = false;
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
      );
    }

    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final muscles = ref.watch(muscleOptionsProvider).value ?? const [];

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
