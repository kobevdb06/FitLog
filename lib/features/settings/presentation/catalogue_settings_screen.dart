/// Muscle groups and kit the app did not come with.
///
/// The pickers used to offer only what the bundled catalogue happened to
/// contain, so a group nothing used could not be chosen at all - and one you
/// invented while making an exercise vanished again the moment that exercise
/// was archived. What you add here stays, whether or not anything uses it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../exercises/presentation/exercise_providers.dart';

class CatalogueSettingsScreen extends ConsumerWidget {
  const CatalogueSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscles = ref.watch(customMusclesProvider).value ?? const [];
    final equipment = ref.watch(customEquipmentProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Eigen spieren en materiaal')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: InfoBanner(
              icon: Icons.info_outline,
              message:
                  'Wat je hier toevoegt kan je kiezen bij een eigen oefening. '
                  'Een spiergroep krijgt een eigen kleur, maar staat niet op '
                  'het lichaamsmodel en rekent met de standaard hersteltijd '
                  'van 48 uur.',
            ),
          ),
          const SectionHeader('Spiergroepen'),
          if (muscles.isEmpty)
            const _Leeg('Nog geen eigen spiergroepen.')
          else
            for (final muscle in muscles)
              ListTile(
                leading: MuscleAvatar(muscle: muscle.name, size: 32),
                title: Text(muscle.name),
                trailing: IconButton(
                  tooltip: 'Verwijderen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeMuscle(context, ref, muscle.name),
                ),
              ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: () => _addMuscle(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Spiergroep toevoegen'),
            ),
          ),
          const SectionHeader('Materiaal'),
          if (equipment.isEmpty)
            const _Leeg('Nog geen eigen materiaal.')
          else
            for (final kit in equipment)
              ListTile(
                leading: const Icon(Icons.fitness_center_outlined),
                title: Text(kit.name),
                trailing: IconButton(
                  tooltip: 'Verwijderen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeEquipment(context, ref, kit.name),
                ),
              ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: () => _addEquipment(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Materiaal toevoegen'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMuscle(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: 'Spiergroep toevoegen',
      hintText: 'bijvoorbeeld serratus',
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(databaseProvider).exercisesDao.addCustomMuscle(name);
  }

  Future<void> _addEquipment(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: 'Materiaal toevoegen',
      hintText: 'bijvoorbeeld ringen',
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(databaseProvider).exercisesDao.addCustomEquipment(name);
  }

  /// Refused while something still uses it: an exercise pointing at a name
  /// nothing else knows is worse than a list with one entry too many.
  Future<void> _removeMuscle(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final dao = ref.read(databaseProvider).exercisesDao;
    final inUse = await dao.exercisesUsingMuscle(name);
    if (!context.mounted) return;

    if (inUse > 0) {
      showSnack(
        context,
        '$name wordt nog door $inUse '
        '${inUse == 1 ? 'oefening' : 'oefeningen'} gebruikt.',
      );
      return;
    }

    final ok = await confirm(
      context,
      title: '$name verwijderen?',
      message: 'De spiergroep verdwijnt uit de keuzelijsten.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (ok) await dao.removeCustomMuscle(name);
  }

  Future<void> _removeEquipment(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final dao = ref.read(databaseProvider).exercisesDao;
    final inUse = await dao.exercisesUsingEquipment(name);
    if (!context.mounted) return;

    if (inUse > 0) {
      showSnack(
        context,
        '$name wordt nog door $inUse '
        '${inUse == 1 ? 'oefening' : 'oefeningen'} gebruikt.',
      );
      return;
    }

    final ok = await confirm(
      context,
      title: '$name verwijderen?',
      message: 'Het materiaal verdwijnt uit de keuzelijsten.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (ok) await dao.removeCustomEquipment(name);
  }
}

class _Leeg extends StatelessWidget {
  const _Leeg(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
