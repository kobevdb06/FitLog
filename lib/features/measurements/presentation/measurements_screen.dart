import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
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

/// The list of measurement types with their latest value and the change.
class MeasurementsScreen extends ConsumerWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestMeasurementsProvider).value ?? const {};
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lichaamsmetingen')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final type in MeasurementType.values)
            _MeasurementTile(
              type: type,
              latest: latest[type],
              formatters: formatters,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddMeasurementSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Meting'),
      ),
    );
  }
}

class _MeasurementTile extends ConsumerWidget {
  const _MeasurementTile({
    required this.type,
    required this.latest,
    required this.formatters,
  });

  final MeasurementType type;
  final BodyMeasurementRow? latest;
  final Formatters formatters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(measurementHistoryProvider(type)).value ?? const [];
    final difference = history.length >= 2
        ? history.first.value - history.last.value
        : null;

    return ExpansionTile(
      title: Text(type.label),
      subtitle: Text(
        latest == null
            ? 'Nog geen meting'
            : '${formatters.measurement(type, latest!.value)} · '
                  '${Formatters.relativeDay(DateTime.fromMillisecondsSinceEpoch(latest!.measuredAt)).toLowerCase()}',
      ),
      trailing: difference == null
          ? null
          : Text(
              '${difference > 0 ? '+' : ''}'
              '${formatters.measurement(type, difference)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: difference == 0
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : (difference > 0 ? AppColors.success : AppColors.accent),
              ),
            ),
      children: [
        if (history.length >= 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TrendLineChart(
              height: 140,
              points: [
                for (final row in history.reversed)
                  ChartPoint(
                    DateTime.fromMillisecondsSinceEpoch(row.measuredAt),
                    formatters.toDisplayMeasurement(type, row.value),
                  ),
              ],
              valueLabel: (v) => v.toStringAsFixed(0),
            ),
          ),
        for (final row in history.take(12))
          ListTile(
            dense: true,
            title: Text(formatters.measurement(type, row.value)),
            subtitle: Text(
              Formatters.date(
                DateTime.fromMillisecondsSinceEpoch(row.measuredAt),
              ),
            ),
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
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Nog niets gemeten.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
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
              DropdownButtonFormField<MeasurementType>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final t in MeasurementType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => selected = v);
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
