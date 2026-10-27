import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';

part 'measurements_screen.g.dart';

@riverpod
Stream<Map<MeasurementType, BodyMeasurementRow>> latestMeasurements(Ref ref) =>
    ref.watch(databaseProvider).recordsDao.watchLatestMeasurements();

@riverpod
Stream<List<BodyMeasurementRow>> measurementHistory(
  Ref ref,
  MeasurementType type,
) => ref.watch(databaseProvider).recordsDao.watchMeasurements(type: type);

/// Your measurements on your body: weight and body fat above, and every
/// girth beside the part it is taken of.
///
/// A measure you have opens its history; one you do not, the sheet to take
/// it. There is no list of twelve rows - ten of them saying there was no
/// measurement yet - and no button floating over them.
class MeasurementsScreen extends ConsumerWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestMeasurementsProvider).value ?? const {};
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Lichaamsmetingen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, type) in const [
                  MeasurementType.weight,
                  MeasurementType.bodyFat,
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _StatTile(type: type, latest: latest[type]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: _BodyMap(latest: latest),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tik op een maat om ze te meten, of om het verloop te zien. '
            'Links en rechts zoals in een spiegel.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// What a tap on a measure does: its history when there is one, the sheet
/// to take it when there is not.
void _open(
  BuildContext context,
  WidgetRef ref,
  MeasurementType type, {
  required bool measured,
}) {
  if (measured) {
    showMeasurementHistory(context, ref, type);
  } else {
    showAddMeasurementSheet(context, ref, type: type);
  }
}

/// Weight or body fat: the latest, and when.
class _StatTile extends ConsumerWidget {
  const _StatTile({required this.type, required this.latest});

  final MeasurementType type;
  final BodyMeasurementRow? latest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final row = latest;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _open(context, ref, type, measured: row != null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(type.label, style: muted),
          if (row == null)
            Text(
              '+ meten',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            )
          else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                formatters.measurement(type, row.value),
                style: theme.textTheme.titleLarge,
              ),
            ),
            Text(
              Formatters.relativeDay(
                DateTime.fromMillisecondsSinceEpoch(row.measuredAt),
              ).toLowerCase(),
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}

/// The girths on each side of the figure, top to bottom.
const _leftSide = [
  MeasurementType.neck,
  MeasurementType.leftArm,
  MeasurementType.waist,
  MeasurementType.leftThigh,
  MeasurementType.leftCalf,
];
const _rightSide = [
  MeasurementType.chest,
  MeasurementType.rightArm,
  MeasurementType.hips,
  MeasurementType.rightThigh,
  MeasurementType.rightCalf,
];

/// The short name beside the figure: "Arm links" does not fit beside it
/// with large text, "Arm L" does.
String _short(MeasurementType type) => switch (type) {
  MeasurementType.leftArm => 'Arm L',
  MeasurementType.rightArm => 'Arm R',
  MeasurementType.leftThigh => 'Dij L',
  MeasurementType.rightThigh => 'Dij R',
  MeasurementType.leftCalf => 'Kuit L',
  MeasurementType.rightCalf => 'Kuit R',
  _ => type.label,
};

/// Where on the body each girth is taken, in a figure 100 wide and 200
/// tall.
const Map<MeasurementType, Offset> _anchors = {
  MeasurementType.neck: Offset(45, 30),
  MeasurementType.chest: Offset(60, 50),
  MeasurementType.leftArm: Offset(19, 64),
  MeasurementType.rightArm: Offset(81, 64),
  MeasurementType.waist: Offset(30, 86),
  MeasurementType.hips: Offset(70, 104),
  MeasurementType.leftThigh: Offset(40, 128),
  MeasurementType.rightThigh: Offset(60, 128),
  MeasurementType.leftCalf: Offset(40, 172),
  MeasurementType.rightCalf: Offset(60, 172),
};

/// The figure, with each girth beside it and a line to where it is taken.
///
/// The labels stand in even rows on either side, as tall as two lines of
/// text, and the figure is as tall as the rows: larger text makes all of
/// it larger instead of laying one label over the next.
class _BodyMap extends StatelessWidget {
  const _BodyMap({required this.latest});

  final Map<MeasurementType, BodyMeasurementRow> latest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final row =
        2 * scaler.scale(theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.45 +
        AppSpacing.md;
    final height = row * _leftSide.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Narrower than the anchors' 100 by 200, so the labels keep room.
        final figure = Rect.fromCenter(
          center: Offset(width / 2, height / 2),
          width: height * 0.42,
          height: height,
        );
        final column = figure.left - AppSpacing.sm;
        Offset anchor(MeasurementType type) => Offset(
          figure.left + _anchors[type]!.dx / 100 * figure.width,
          figure.top + _anchors[type]!.dy / 200 * figure.height,
        );

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BodyPainter(
                    figure: figure,
                    lines: [
                      for (final (i, type) in _leftSide.indexed)
                        (
                          from: Offset(column, row * i + row / 2),
                          to: anchor(type),
                          measured: latest.containsKey(type),
                        ),
                      for (final (i, type) in _rightSide.indexed)
                        (
                          from: Offset(width - column, row * i + row / 2),
                          to: anchor(type),
                          measured: latest.containsKey(type),
                        ),
                    ],
                    body: theme.colorScheme.primary,
                    line: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              for (final (i, type) in _leftSide.indexed)
                Positioned(
                  left: 0,
                  top: row * i,
                  width: column,
                  height: row,
                  child: _Girth(type: type, latest: latest[type], end: false),
                ),
              for (final (i, type) in _rightSide.indexed)
                Positioned(
                  right: 0,
                  top: row * i,
                  width: column,
                  height: row,
                  child: _Girth(type: type, latest: latest[type], end: true),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One girth beside the figure: its name, and its latest or "+ meten".
class _Girth extends ConsumerWidget {
  const _Girth({required this.type, required this.latest, required this.end});

  final MeasurementType type;
  final BodyMeasurementRow? latest;

  /// On the right of the figure, so against its right edge.
  final bool end;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final row = latest;
    final value = row == null ? null : formatters.measurement(type, row.value);
    final align = end ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Semantics(
      button: true,
      label: '${type.label}, ${value ?? 'nog niet gemeten'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(context, ref, type, measured: row != null),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: align,
            children: [
              Text(
                _short(type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: end
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Text(
                  value ?? '+ meten',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: value == null ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Line = ({Offset from, Offset to, bool measured});

/// A plain figure from the front, and the lines from each label to where
/// the girth is taken: a filled dot where there is a measurement.
class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.figure,
    required this.lines,
    required this.body,
    required this.line,
  });

  final Rect figure;
  final List<_Line> lines;
  final Color body;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(double x, double y) => Offset(
      figure.left + x / 100 * figure.width,
      figure.top + y / 200 * figure.height,
    );
    RRect part(double l, double t, double r, double b, double radius) =>
        RRect.fromRectAndRadius(
          Rect.fromPoints(at(l, t), at(r, b)),
          Radius.circular(radius / 100 * figure.width),
        );

    // Shoulders that slope from the neck, a waist, and the hips.
    final torso = Path()
      ..moveTo(at(42, 33).dx, at(42, 33).dy)
      ..lineTo(at(58, 33).dx, at(58, 33).dy)
      ..cubicTo(
        at(68, 34).dx,
        at(68, 34).dy,
        at(74, 37).dx,
        at(74, 37).dy,
        at(74, 46).dx,
        at(74, 46).dy,
      )
      ..cubicTo(
        at(73, 62).dx,
        at(73, 62).dy,
        at(70, 76).dx,
        at(70, 76).dy,
        at(69, 88).dx,
        at(69, 88).dy,
      )
      ..cubicTo(
        at(69, 96).dx,
        at(69, 96).dy,
        at(71, 102).dx,
        at(71, 102).dy,
        at(71, 110).dx,
        at(71, 110).dy,
      )
      ..lineTo(at(29, 110).dx, at(29, 110).dy)
      ..cubicTo(
        at(29, 102).dx,
        at(29, 102).dy,
        at(31, 96).dx,
        at(31, 96).dy,
        at(31, 88).dx,
        at(31, 88).dy,
      )
      ..cubicTo(
        at(30, 76).dx,
        at(30, 76).dy,
        at(27, 62).dx,
        at(27, 62).dy,
        at(26, 46).dx,
        at(26, 46).dy,
      )
      ..cubicTo(
        at(26, 37).dx,
        at(26, 37).dy,
        at(32, 34).dx,
        at(32, 34).dy,
        at(42, 33).dx,
        at(42, 33).dy,
      )
      ..close();
    // One outline for the whole figure: where a thigh meets a calf, or the
    // neck the head, no edge is drawn through it.
    var figurePath = Path()
      ..addOval(
        Rect.fromCenter(
          center: at(50, 15),
          width: 20 / 100 * figure.width,
          height: 24 / 200 * figure.height,
        ),
      );
    for (final shape in [
      torso,
      Path()..addRRect(part(45, 24, 55, 36, 3)),
      Path()..addRRect(part(15, 39, 24, 102, 5)),
      Path()..addRRect(part(76, 39, 85, 102, 5)),
      Path()..addRRect(part(31, 104, 49, 152, 8)),
      Path()..addRRect(part(51, 104, 69, 152, 8)),
      Path()..addRRect(part(33, 146, 47, 196, 7)),
      Path()..addRRect(part(53, 146, 67, 196, 7)),
    ]) {
      figurePath = Path.combine(PathOperation.union, figurePath, shape);
    }

    canvas.drawPath(figurePath, Paint()..color = body.withValues(alpha: 0.10));
    canvas.drawPath(
      figurePath,
      Paint()
        ..color = body.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final stroke = Paint()
      ..color = line
      ..strokeWidth = 1;
    final dot = Paint()..color = body;
    final ring = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final l in lines) {
      canvas.drawLine(l.from, l.to, stroke);
      if (l.measured) {
        canvas.drawCircle(l.to, 4, dot);
      } else {
        canvas.drawCircle(
          l.to,
          3.5,
          Paint()..color = body.withValues(alpha: 0.10),
        );
        canvas.drawCircle(l.to, 3.5, ring);
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.figure != figure ||
      old.body != body ||
      old.line != line ||
      !listEquals(old.lines, lines);
}

/// One measure in full: the latest and how it changed, its line, every
/// time it was taken, and taking it again.
Future<void> showMeasurementHistory(
  BuildContext context,
  WidgetRef ref,
  MeasurementType type,
) async {
  final again = await showAppSheet<bool>(
    context: context,
    title: type.label,
    builder: (context) => _History(type: type),
  );
  if (again == true && context.mounted) {
    await showAddMeasurementSheet(context, ref, type: type);
  }
}

class _History extends ConsumerWidget {
  const _History({required this.type});

  final MeasurementType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final history =
        ref.watch(measurementHistoryProvider(type)).value ?? const [];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    DateTime at(BodyMeasurementRow row) =>
        DateTime.fromMillisecondsSinceEpoch(row.measuredAt);

    String? change() {
      if (history.length < 2) return null;
      final difference = history.first.value - history.last.value;
      final since = 'sinds ${Formatters.dayMonth(at(history.last))}';
      if (difference.abs() < 0.05) return 'gelijk $since';
      return '${difference > 0 ? '+' : ''}'
          '${formatters.measurement(type, difference)} $since';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (history.isEmpty)
            Text('Nog niets gemeten.', style: muted)
          else ...[
            Text(
              formatters.measurement(type, history.first.value),
              style: theme.textTheme.headlineSmall,
            ),
            Text(
              [
                Formatters.relativeDay(at(history.first)).toLowerCase(),
                ?change(),
              ].join(' · '),
              style: muted,
            ),
          ],
          if (history.length >= 2) ...[
            const SizedBox(height: AppSpacing.md),
            TrendLineChart(
              height: 140,
              points: [
                for (final row in history.reversed)
                  ChartPoint(
                    at(row),
                    formatters.toDisplayMeasurement(type, row.value),
                  ),
              ],
              valueLabel: (v) => v.toStringAsFixed(0),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (final row in history.take(12))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(formatters.measurement(type, row.value)),
              subtitle: Text(Formatters.date(at(row))),
              trailing: IconButton(
                tooltip: 'Verwijderen',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'Meting verwijderen?',
                    message: 'Deze meting verdwijnt uit je grafiek.',
                    confirmLabel: 'Verwijderen',
                    destructive: true,
                  );
                  if (ok) {
                    await ref
                        .read(databaseProvider)
                        .recordsDao
                        .deleteMeasurement(row.id);
                  }
                },
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.add),
            label: const Text('Meting toevoegen'),
          ),
        ],
      ),
    );
  }
}

/// The bottom sheet that adds one measurement.
Future<void> showAddMeasurementSheet(
  BuildContext context,
  WidgetRef ref, {
  MeasurementType? type,
}) async {
  final formatters = ref.read(formattersProvider);
  var selected = type ?? MeasurementType.weight;
  var value = const KeypadValue.empty();
  var date = DateTime.now();
  final noteController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Meting toevoegen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Type',
                text: selected.label,
                onTap: () async {
                  final picked = await pickMeasurementType(
                    context,
                    current: selected,
                    unitLabel: formatters.measurementUnitLabel,
                  );
                  if (picked == null || picked == selected) return;
                  // The value belongs to the old type - 82 kg does not become
                  // 82 cm because you changed your mind about what you were
                  // measuring.
                  setState(() {
                    selected = picked;
                    value = const KeypadValue.empty();
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () async {
                  final result = await showKeypadSheet(
                    context: context,
                    kind: selected.unit == MeasurementUnit.kg
                        ? KeypadFieldKind.weight
                        : KeypadFieldKind.distance,
                    initialValue: value,
                    unitLabel: formatters.measurementUnitLabel(selected),
                    title: selected.label,
                    steps: selected.unit == MeasurementUnit.kg
                        ? const [0.1, 0.5, 1]
                        : const [0.5, 1],
                  );
                  if (result != null) setState(() => value = result);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Waarde',
                    suffixText: formatters.measurementUnitLabel(selected),
                  ),
                  child: Text(
                    value.isEmpty ? 'Tik om in te vullen' : value.text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Datum'),
                  child: Text(Formatters.date(date)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Notitie'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () async {
                  final number = value.number;
                  if (number == null) {
                    showSnack(context, 'Vul een waarde in.', isError: true);
                    return;
                  }
                  await ref
                      .read(databaseProvider)
                      .recordsDao
                      .addMeasurement(
                        type: selected,
                        value: formatters.fromDisplayMeasurement(
                          selected,
                          number,
                        ),
                        measuredAt: date,
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Opslaan'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  noteController.dispose();
}
