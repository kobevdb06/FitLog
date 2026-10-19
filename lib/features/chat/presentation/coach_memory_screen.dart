/// Instellingen → AI-coach → Geheugen: what the coach remembers about you,
/// note by note, and whether it remembers at all.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import 'chat_providers.dart';

/// The icon of what a note is about.
IconData coachNoteIcon(String kind) => switch (CoachNoteKind.of(kind)) {
  CoachNoteKind.goal => Icons.flag_outlined,
  CoachNoteKind.limit => Icons.healing_outlined,
  CoachNoteKind.schedule => Icons.event_outlined,
  CoachNoteKind.kit => Icons.home_outlined,
  CoachNoteKind.style => Icons.chat_outlined,
  CoachNoteKind.other => Icons.sticky_note_2_outlined,
};

/// Asks for the words of a note: a new one, or [note] changed.
Future<String?> askForNote(BuildContext context, {String? note}) =>
    promptForText(
      context,
      title: note == null ? 'Notitie toevoegen' : 'Notitie aanpassen',
      initialValue: note,
      hintText: 'Bijvoorbeeld: traint thuis met dumbbells tot 24 kg',
      maxLength: kCoachNoteLength,
      maxLines: 3,
    );

class CoachMemoryScreen extends ConsumerWidget {
  const CoachMemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final on = ref.watch(settingsProvider).value?.coachMemory ?? true;
    final notes = ref.watch(coachNotesProvider).value ?? const [];
    final dao = ref.read(databaseProvider).coachNotesDao;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Future<void> add() async {
      if (notes.length >= kCoachNoteMax) {
        showSnack(
          context,
          'Het geheugen is vol: $kCoachNoteMax notities. Pas er een aan of '
          'laat er een vergeten.',
        );
        return;
      }
      final text = await askForNote(context);
      if (text == null || text.trim().isEmpty) return;
      await dao.add(text);
    }

    Future<void> forgetAll() async {
      final ok = await confirm(
        context,
        title: 'Alles vergeten?',
        message:
            'De coach vergeet alle ${notes.length} notities. Je gesprekken '
            'blijven staan.',
        confirmLabel: 'Alles vergeten',
        destructive: true,
      );
      if (ok) await dao.forgetAll();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Geheugen')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          SwitchListTile(
            title: const Text('De coach onthoudt dingen'),
            subtitle: Text(
              on
                  ? 'Korte notities over wat je zelf zei: doelen, blessures, '
                        'wanneer je traint. Ze gaan mee met elke vraag naar '
                        'Google.'
                  : 'Uit. De notities blijven bewaard, maar gaan niet mee en '
                        'de coach schrijft er geen bij.',
            ),
            value: on,
            onChanged: (value) => ref
                .read(databaseProvider)
                .settingsDao
                .updateSettings(
                  AppSettingsTableCompanion(coachMemory: Value(value)),
                ),
          ),
          SectionHeader(
            notes.isEmpty
                ? 'Nog geen notities'
                : '${notes.length} van $kCoachNoteMax notities',
          ),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Vertel de coach iets wat blijft gelden - "onthoud dat mijn '
                'knie gevoelig is" - en het komt hier.',
                style: muted,
              ),
            ),
          for (final note in notes)
            ListTile(
              leading: Icon(coachNoteIcon(note.kind)),
              title: Text(note.note),
              subtitle: Text(
                Formatters.relativeDay(
                  DateTime.fromMillisecondsSinceEpoch(note.updatedAt),
                ),
              ),
              onTap: () async {
                final text = await askForNote(context, note: note.note);
                if (text == null || text.trim().isEmpty) return;
                await dao.change(note.id, text);
              },
              trailing: IconButton(
                tooltip: 'Vergeten',
                icon: const Icon(Icons.close),
                onPressed: () => dao.forget(note.id),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: add,
                  icon: const Icon(Icons.add),
                  label: const Text('Notitie toevoegen'),
                ),
                if (notes.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: forgetAll,
                    child: const Text('Alles vergeten'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
