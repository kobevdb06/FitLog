import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../dashboard/domain/home_layout.dart';
import '../../dashboard/presentation/today_providers.dart';

/// Arranging the Start tab: which blocks are on it, and in what order.
class HomeSettingsScreen extends ConsumerWidget {
  const HomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(homeLayoutProvider);

    Future<void> save(HomeLayout next) => ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          AppSettingsTableCompanion(homeLayout: Value(encodeHomeLayout(next))),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startscherm'),
        actions: [
          TextButton(
            onPressed: () => save(defaultHomeLayout),
            child: const Text('Standaard'),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: InfoBanner(
              icon: Icons.drag_indicator,
              message:
                  'Sleep om de volgorde te wijzigen. De begroeting en de '
                  'back-upwaarschuwing staan altijd bovenaan.',
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xl,
              ),
              onReorderItem: (from, to) => save(layout.reordered(from, to)),
              children: [
                for (final block in layout.blocks)
                  SwitchListTile(
                    // The block, not its position: dragging a row must not
                    // make the switch under your finger belong to something
                    // else.
                    key: ValueKey(block.wire),
                    value: layout.shows(block),
                    onChanged: (value) =>
                        save(layout.withVisible(block, visible: value)),
                    title: Text(block.label),
                    subtitle: Text(block.description),
                    secondary: const Icon(Icons.drag_indicator),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
