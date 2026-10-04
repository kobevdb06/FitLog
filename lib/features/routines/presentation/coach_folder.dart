import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_spacing.dart';

/// The folders you see: the coach's only while there is a coach.
///
/// Without a key it is hidden, not gone. Nothing in it is deleted, and it
/// comes back with the key.
List<RoutineFolderRow> visibleFolders(
  List<RoutineFolderRow> folders, {
  required bool coach,
}) => [
  for (final folder in folders)
    if (coach || !folder.isCoach) folder,
];

/// Asks before a routine of yours goes where the coach may change it.
///
/// The button stays off until the box is ticked: handing a routine to a
/// language model is a choice, and one tap on a sheet is too easy to make by
/// accident.
Future<bool> confirmHandToCoach(
  BuildContext context, {
  required String routineName,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => _HandToCoach(routineName: routineName),
  );
  return ok ?? false;
}

class _HandToCoach extends StatefulWidget {
  const _HandToCoach({required this.routineName});

  final String routineName;

  @override
  State<_HandToCoach> createState() => _HandToCoachState();
}

class _HandToCoachState extends State<_HandToCoach> {
  var _understood = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.routineName.trim().isEmpty
        ? 'deze routine'
        : '"${widget.routineName.trim()}"';

    return AlertDialog(
      title: const Text('Routine aan de coach geven?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'In de map Coach mag de coach $name aanpassen: oefeningen, '
              'sets, herhalingen en gewichten. Dat doet een taalmodel, en dat '
              'kan ook mislukken - het kan de routine verknoeien.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hoe ze was voor elke wijziging, blijft bewaard. Dat zet je '
              'terug via Vorige versies in het menu van de routine.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: (value) =>
                  setState(() => _understood = value ?? false),
              title: const Text(
                'Ik weet dat de coach deze routine kan aanpassen, en ook kan '
                'verknoeien.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          child: const Text('In de map Coach zetten'),
        ),
      ],
    );
  }
}
