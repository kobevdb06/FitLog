import 'package:flutter/material.dart';

import '../calc/rpe.dart';
import '../db/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Yes/no confirmation. Returns true only when the user actually confirms.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Bevestigen',
  String cancelLabel = 'Annuleren',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A single line of text input.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? hintText,
  String confirmLabel = 'Opslaan',
  int maxLines = 1,
  TextCapitalization capitalization = TextCapitalization.sentences,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        textCapitalization: capitalization,
        decoration: InputDecoration(hintText: hintText),
        onSubmitted: maxLines == 1
            ? (value) => Navigator.of(context).pop(value)
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// The last gate before something irreversible: the user has to type a word.
Future<bool> confirmByTyping(
  BuildContext context, {
  required String title,
  required String message,
  required String word,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _TypeToConfirmDialog(title: title, message: message, word: word),
  );
  return result ?? false;
}

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog({
    required this.title,
    required this.message,
    required this.word,
  });

  final String title;
  final String message;
  final String word;

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: widget.word),
            onChanged: (value) => setState(
              () => _matches = value.trim().toUpperCase() == widget.word,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Definitief wissen'),
        ),
      ],
    );
  }
}

/// A bottom sheet with the app's standard padding and a title.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            builder(context),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    ),
  );
}

/// A short message at the bottom of the screen.
void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
        duration: const Duration(seconds: 3),
      ),
    );
}

/// The set type picker.
///
/// Reached by tapping the set number, which is the primary route, and by
/// long-pressing it, which keeps working for people who learned that first.
Future<SetType?> pickSetType(BuildContext context, {required SetType current}) {
  return showAppSheet<SetType>(
    context: context,
    title: 'Type set',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in SetType.values)
          ListTile(
            leading: SizedBox(
              width: 28,
              child: Text(
                type.marker ?? '1',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: setTypeColor(context, type),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(type.label),
            subtitle: Text(setTypeDescription(type)),
            selected: type == current,
            onTap: () => Navigator.of(context).pop(type),
          ),
      ],
    ),
  );
}

/// Picks how an exercise is done, which decides what a set asks you for.
Future<ExerciseCategory?> pickExerciseCategory(
  BuildContext context, {
  required ExerciseCategory current,
}) {
  return showAppSheet<ExerciseCategory>(
    context: context,
    title: 'Hoe doe je deze oefening?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final category in ExerciseCategory.values)
          ListTile(
            title: Text(category.label),
            subtitle: Text(exerciseCategoryDescription(category)),
            selected: category == current,
            onTap: () => Navigator.of(context).pop(category),
          ),
      ],
    ),
  );
}

/// What a set of this kind asks you to fill in.
String exerciseCategoryDescription(ExerciseCategory category) {
  if (category.hasDistance) return 'Afstand en tijd';
  if (category.hasDuration) return 'Tijd';
  return 'Gewicht en herhalingen';
}

/// Asks how hard a set was, by asking what people can actually answer.
///
/// Not a number pad. "How heavy did that feel" has no anchor and nobody agrees
/// what a 7 is; "how many more could you have done" is something you counted
/// while you were doing it. The number stored is still the RPE, so nothing
/// downstream has to know the question was phrased the other way round.
///
/// Everything at or below 6 is one choice on purpose. The difference between
/// four reps in reserve and six is not something anyone can judge, and
/// offering both invents data.
Future<double?> pickRpe(BuildContext context, {required double? current}) {
  return showAppSheet<double>(
    context: context,
    title: 'Hoeveel had je er nog gekund?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (value, reserve, note) in kRpeChoices)
          ListTile(
            leading: SizedBox(
              width: 34,
              child: Text(
                value == kMinUsableRpe ? '≤6' : '${value.round()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            title: Text(reserve),
            subtitle: Text(note),
            selected: current == value,
            onTap: () => Navigator.of(context).pop(value),
          ),
        if (current != null) ...[
          const Divider(height: 1),
          ListTile(
            leading: const SizedBox(
              width: 34,
              child: Icon(Icons.backspace_outlined, size: 18),
            ),
            title: const Text('Geen cijfer'),
            onTap: () => Navigator.of(context).pop(kRpeCleared),
          ),
        ],
      ],
    ),
  );
}

/// What [pickRpe] returns when you choose to leave the set unscored. A plain
/// null already means "you closed the sheet without choosing".
const double kRpeCleared = -1;

/// The choices, hardest first. The third field says what the effort is about
/// and never what it feels like: people readily confuse heavy with painful,
/// and a label that says "zwaar" invites them to score a sore elbow.
const List<(double, String, String)> kRpeChoices = [
  (10, 'Geen enkele meer', 'De laatste rep was de laatste'),
  (9, 'Nog 1 rep', 'Eén in reserve'),
  (8, 'Nog 2 reps', 'Twee in reserve'),
  (7, 'Nog 3 reps', 'Drie in reserve'),
  (kMinUsableRpe, 'Nog veel', 'Vier of meer - niet nader te schatten'),
];

/// The colour the SET column uses per type.
Color setTypeColor(BuildContext context, SetType type) => switch (type) {
  // Muted: a warm-up is not the work, and should not draw the eye.
  SetType.warmup => Theme.of(context).colorScheme.onSurfaceVariant,
  SetType.normal => Theme.of(context).colorScheme.onSurface,
  SetType.drop => AppColors.accent,
  SetType.failure => AppColors.record,
};

String setTypeDescription(SetType type) => switch (type) {
  SetType.warmup => 'Telt niet mee voor volume of records',
  SetType.normal => 'Gewone werkset',
  SetType.drop => 'Direct verder met minder gewicht',
  SetType.failure => 'Doorgegaan tot je er geen meer kon',
};
