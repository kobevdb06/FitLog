import 'dart:io';

import 'package:flutter/material.dart';

import '../calc/rpe.dart';
import '../calc/schedule.dart';
import '../db/database.dart';
import '../db/models.dart';
import '../formatting/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'common.dart';

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
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextPrompt(
      title: title,
      initialValue: initialValue,
      hintText: hintText,
      confirmLabel: confirmLabel,
      maxLines: maxLines,
      capitalization: capitalization,
    ),
  );
}

/// The dialog owns its controller, because the dialog outlives the answer.
///
/// Disposing it right after the await looked right and was not: the route is
/// still fading out and rebuilds the field a few more times, each one reaching
/// into a controller that is already gone.
class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.confirmLabel,
    required this.maxLines,
    required this.capitalization,
  });

  final String title;
  final String? initialValue;
  final String? hintText;
  final String confirmLabel;
  final int maxLines;
  final TextCapitalization capitalization;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        textCapitalization: widget.capitalization,
        decoration: InputDecoration(hintText: widget.hintText),
        onSubmitted: widget.maxLines == 1
            ? (value) => Navigator.of(context).pop(value)
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Two descriptions at once, because they only mean something as a pair.
///
/// Returns start and end as they were left, or null when the user backed out.
Future<(String, String)?> promptForPair(
  BuildContext context, {
  required String title,
  required String note,
  required String start,
  required String end,
  String confirmLabel = 'Tekenen',
}) {
  return showDialog<(String, String)>(
    context: context,
    builder: (context) => _PairPrompt(
      title: title,
      note: note,
      start: start,
      end: end,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PairPrompt extends StatefulWidget {
  const _PairPrompt({
    required this.title,
    required this.note,
    required this.start,
    required this.end,
    required this.confirmLabel,
  });

  final String title;
  final String note;
  final String start;
  final String end;
  final String confirmLabel;

  @override
  State<_PairPrompt> createState() => _PairPromptState();
}

class _PairPromptState extends State<_PairPrompt> {
  late final _start = TextEditingController(text: widget.start);
  late final _end = TextEditingController(text: widget.end);

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _start,
              maxLines: 3,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(labelText: 'Startpositie'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _end,
              maxLines: 3,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(labelText: 'Eindpositie'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_start.text, _end.text)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
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
///
/// [options] is the built-in eight followed by the categories the user named
/// themselves; one of your own says underneath it which of the eight it counts
/// as, because that is what decides the columns you will be filling in.
Future<CategoryChoice?> pickExerciseCategory(
  BuildContext context, {
  required CategoryChoice current,
  required List<CategoryChoice> options,
  VoidCallback? onAddNew,
}) {
  return showAppSheet<CategoryChoice>(
    context: context,
    title: 'Hoe doe je deze oefening?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final choice in options)
          ListTile(
            leading: Icon(exerciseCategoryIcon(choice.base)),
            title: Text(choice.label),
            subtitle: Text(
              choice.isOwn
                  ? 'Van jezelf, rekent als ${choice.base.label.toLowerCase()}'
                  : exerciseCategoryDescription(choice.base),
            ),
            selected: choice == current,
            onTap: () => Navigator.of(context).pop(choice),
          ),
        // Right here rather than only in the settings: you notice a category
        // is missing while you are making the exercise that needs it.
        if (onAddNew != null) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Nieuwe categorie'),
            onTap: () {
              Navigator.of(context).pop();
              onAddNew();
            },
          ),
        ],
      ],
    ),
  );
}

/// Which of the built-in categories a new category of your own counts as.
Future<ExerciseCategory?> pickCategoryBase(BuildContext context) {
  return showAppSheet<ExerciseCategory>(
    context: context,
    title: 'Waarmee reken je mee?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final category in ExerciseCategory.values)
          ListTile(
            leading: Icon(exerciseCategoryIcon(category)),
            title: Text(category.label),
            subtitle: Text(exerciseCategoryDescription(category)),
            onTap: () => Navigator.of(context).pop(category),
          ),
      ],
    ),
  );
}

/// What you are about to measure.
///
/// A sheet rather than a dropdown: twelve entries in a Material dropdown is a
/// grey slab over the page in a style the app uses nowhere else, and it sits
/// right above two fields that already open a sheet when you tap them.
///
/// [unitLabel] comes from the caller because the unit follows your settings:
/// the same weight is kg for one person and lb for the next.
Future<MeasurementType?> pickMeasurementType(
  BuildContext context, {
  required MeasurementType current,
  required String Function(MeasurementType) unitLabel,
}) {
  return showAppSheet<MeasurementType>(
    context: context,
    title: 'Wat wil je meten?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in MeasurementType.values)
          ListTile(
            title: Text(type.label),
            trailing: Text(
              unitLabel(type),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            selected: type == current,
            onTap: () => Navigator.of(context).pop(type),
          ),
      ],
    ),
  );
}

/// A picture for each kind of exercise.
///
/// Material has exactly one gym glyph and it is a dumbbell, so only half of
/// these are portraits of the equipment. The rest say what the thing does -
/// something that holds you up, a clock, a runner - which is what you are
/// choosing between anyway.
IconData exerciseCategoryIcon(ExerciseCategory category) => switch (category) {
  // A bar with weight spaced along it, which is as close as this set gets.
  ExerciseCategory.barbell => Icons.linear_scale,
  ExerciseCategory.dumbbell => Icons.fitness_center,
  ExerciseCategory.machine => Icons.precision_manufacturing,
  ExerciseCategory.cable => Icons.cable,
  ExerciseCategory.bodyweight => Icons.sports_gymnastics,
  ExerciseCategory.assistedBodyweight => Icons.support,
  ExerciseCategory.duration => Icons.timer_outlined,
  ExerciseCategory.cardio => Icons.directions_run,
};

/// Which muscle an exercise works hardest.
///
/// The names come from the catalogue rather than from an enum, so there is no
/// drawing to put next to them - but the app already gives every muscle a
/// colour and two letters, on every exercise row there is. The same mark here
/// means the thing you pick looks like the thing you will see afterwards.
Future<String?> pickMuscle(
  BuildContext context, {
  required String? current,
  required List<String> muscles,
  String title = 'Welke spier werkt het hardst?',
  VoidCallback? onAddNew,
}) {
  return showAppSheet<String>(
    context: context,
    title: title,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final muscle in muscles)
          ListTile(
            leading: MuscleAvatar(muscle: muscle, size: 32),
            title: Text(muscle),
            selected: muscle == current,
            onTap: () => Navigator.of(context).pop(muscle),
          ),
        // Right here rather than only in the settings: you notice a group is
        // missing while you are making the exercise that needs it.
        if (onAddNew != null) ...[
          const Divider(height: 1),
          ListTile(
            leading: const SizedBox(width: 32, child: Icon(Icons.add)),
            title: const Text('Nieuwe spiergroep'),
            onTap: () {
              Navigator.of(context).pop();
              onAddNew();
            },
          ),
        ],
      ],
    ),
  );
}

/// Which kit an exercise needs, or none at all.
Future<({String? name})?> pickEquipment(
  BuildContext context, {
  required String? current,
  required List<String> equipment,
  VoidCallback? onAddNew,
}) {
  return showAppSheet<({String? name})>(
    context: context,
    title: 'Waarmee doe je deze oefening?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const SizedBox(width: 32, child: Icon(Icons.block)),
          title: const Text('Geen materiaal'),
          selected: current == null,
          onTap: () => Navigator.of(context).pop((name: null)),
        ),
        for (final kit in equipment)
          ListTile(
            leading: const SizedBox(
              width: 32,
              child: Icon(Icons.fitness_center_outlined),
            ),
            title: Text(kit),
            selected: kit == current,
            onTap: () => Navigator.of(context).pop((name: kit)),
          ),
        if (onAddNew != null) ...[
          const Divider(height: 1),
          ListTile(
            leading: const SizedBox(width: 32, child: Icon(Icons.add)),
            title: const Text('Nieuw materiaal'),
            onTap: () {
              Navigator.of(context).pop();
              onAddNew();
            },
          ),
        ],
      ],
    ),
  );
}

/// One of the four answers, or none of them.
Future<Sex?> pickSex(BuildContext context, {required Sex? current}) {
  return showAppSheet<Sex>(
    context: context,
    title: 'Geslacht',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final sex in Sex.values)
          ListTile(
            title: Text(sex.label),
            selected: sex == current,
            onTap: () => Navigator.of(context).pop(sex),
          ),
      ],
    ),
  );
}

/// Which folder a routine sits in, or none at all.
///
/// The top level is a real answer rather than the absence of one, so it is the
/// first line of the sheet instead of a way to back out of it. That is also why
/// this returns a wrapper: a plain null is what you get when you close the
/// sheet without choosing, and "no folder" has to be distinguishable from it.
Future<({String? id})?> pickFolder(
  BuildContext context, {
  required String? current,
  required List<RoutineFolderRow> folders,
}) {
  return showAppSheet<({String? id})>(
    context: context,
    title: 'In welke map?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.folder_off_outlined),
          title: const Text('Geen map'),
          selected: current == null,
          onTap: () => Navigator.of(context).pop((id: null)),
        ),
        for (final folder in folders)
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(folder.name),
            selected: folder.id == current,
            onTap: () => Navigator.of(context).pop((id: folder.id)),
          ),
      ],
    ),
  );
}

/// Which photo to put in this half of the comparison.
///
/// With a thumbnail on every line, because a date and a pose do not tell you
/// which picture you are about to get - and the whole screen is about looking
/// at them.
Future<String?> pickPhoto(
  BuildContext context, {
  required String current,
  required List<ProgressPhotoRow> photos,
  required File Function(String fileName) fileFor,
}) {
  return showAppSheet<String>(
    context: context,
    title: 'Welke foto?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final photo in photos)
          ListTile(
            leading: SizedBox(
              width: 40,
              height: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Image.file(
                  fileFor(photo.fileName),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const MissingPhotoPlaceholder(compact: true),
                ),
              ),
            ),
            title: Text(
              Formatters.date(
                DateTime.fromMillisecondsSinceEpoch(photo.takenAt),
              ),
            ),
            subtitle: Text(PhotoPose.fromWire(photo.pose).label),
            selected: photo.id == current,
            onTap: () => Navigator.of(context).pop(photo.id),
          ),
      ],
    ),
  );
}

/// Front, side or back.
Future<PhotoPose?> pickPose(BuildContext context, {PhotoPose? current}) {
  return showAppSheet<PhotoPose>(
    context: context,
    title: 'Welke pose?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final pose in PhotoPose.values)
          ListTile(
            title: Text(pose.label),
            selected: pose == current,
            onTap: () => Navigator.of(context).pop(pose),
          ),
      ],
    ),
  );
}

/// Which session a photograph belongs to.
///
/// "Geen workout" is the first line rather than a way to back out, for the
/// same reason the folder picker works that way: closing the sheet means
/// "never mind", and the two cannot be the same answer.
Future<({String? id})?> pickWorkoutForPhoto(
  BuildContext context, {
  required String? current,
  required List<WorkoutRow> workouts,
}) {
  return showAppSheet<({String? id})>(
    context: context,
    title: 'Bij welke workout hoort deze foto?',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.link_off_outlined),
          title: const Text('Geen workout'),
          selected: current == null,
          onTap: () => Navigator.of(context).pop((id: null)),
        ),
        for (final workout in workouts)
          ListTile(
            leading: const Icon(Icons.fitness_center_outlined),
            title: Text(workout.name),
            subtitle: Text(
              Formatters.relativeDay(
                DateTime.fromMillisecondsSinceEpoch(workout.startedAt),
              ),
            ),
            selected: workout.id == current,
            onTap: () => Navigator.of(context).pop((id: workout.id)),
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

/// One line in an overflow menu.
///
/// Every menu in the app is built from this, so they are the same height and
/// line up the same way. The icon is not decoration: a list of ten sentences
/// all starting with a verb is read word by word, and a column of icons is
/// read at a glance.
PopupMenuItem<T> menuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  bool destructive = false,
}) {
  return PopupMenuItem<T>(
    value: value,
    height: 44,
    child: Builder(
      builder: (context) {
        final colour = destructive
            ? AppColors.danger
            : Theme.of(context).colorScheme.onSurface;
        return Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: destructive
                  ? AppColors.danger
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colour),
              ),
            ),
          ],
        );
      },
    ),
  );
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

/// The days a routine is planned on.
///
/// Several at once, so the sheet holds the choice until you say you are done
/// rather than closing on the first tap. Returns null when you back out, which
/// is a different answer from an empty set: that one means "no day at all".
Future<WeekdaySet?> pickWeekdays(
  BuildContext context, {
  required WeekdaySet current,
}) {
  return showAppSheet<WeekdaySet>(
    context: context,
    title: 'Op welke dagen doe je dit?',
    builder: (context) {
      var chosen = current;
      return StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (
                    var weekday = DateTime.monday;
                    weekday <= DateTime.sunday;
                    weekday++
                  )
                    _WeekdayChip(
                      weekday: weekday,
                      selected: chosen.has(weekday),
                      onTap: () =>
                          setState(() => chosen = chosen.toggle(weekday)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                chosen.isEmpty
                    ? 'Zonder dagen staat deze routine niet in je week, en '
                          'blijft je startscherm je favorieten tonen.'
                    : 'Op die dagen staat deze routine op je startscherm. '
                          'Meerdere routines op dezelfde dag mag.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(chosen),
                child: const Text('Klaar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.weekday,
    required this.selected,
    required this.onTap,
  });

  final int weekday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: selected ? AppColors.accent : scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              Formatters.weekdayShort(weekday),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
