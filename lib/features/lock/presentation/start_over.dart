import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/widgets/dialogs.dart';

/// Throws everything on this device away and starts from the first screen:
/// the way out of a database that cannot be opened.
///
/// Two confirmations and the word typed out, the same as wiping from the
/// settings: there is no undo and no copy anywhere else.
Future<void> confirmStartOver(BuildContext context, WidgetRef ref) async {
  final first = await confirm(
    context,
    title: 'Opnieuw beginnen?',
    message:
        'Alles wat FitLog op dit toestel bewaart wordt gewist en je begint '
        'bij het eerste scherm. Er is geen kopie elders.',
    confirmLabel: 'Doorgaan',
    destructive: true,
  );
  if (!first || !context.mounted) return;

  final second = await confirmByTyping(
    context,
    title: 'Zeker weten?',
    message: 'Typ WISSEN om te bevestigen. Dit kan niet ongedaan gemaakt worden.',
    word: 'WISSEN',
  );
  if (!second) return;

  await ref.read(appControllerProvider.notifier).wipeEverything();
}
