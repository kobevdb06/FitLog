import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../db/models.dart';
import '../formatting/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A line over time. Used for estimated 1RM, volume and body weight.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    this.height = 200,
    this.color = AppColors.accent,
    this.valueLabel,
    this.emptyMessage = 'Nog geen gegevens',
  });

  final List<ChartPoint> points;
  final double height;
  final Color color;

  /// Formats the value shown in the tooltip and on the left axis.
  final String Function(double value)? valueLabel;

  /// What stands where the line would be, when there are no points.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            points.isEmpty
                ? emptyMessage
                : 'Nog te weinig gegevens voor een lijn',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final first = points.first.at.millisecondsSinceEpoch.toDouble();
    final last = points.last.at.millisecondsSinceEpoch.toDouble();
    final values = points.map((p) => p.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxValue - minValue) * 0.15).clamp(1.0, double.infinity);
    final step = ((last - first) / 3).clamp(1, double.infinity).toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: first,
          maxX: last,
          // The dates step from the first point, not from 1970: counted from
          // there, a step could land two days after the first date and print
          // over it ("29 aug" on "31 aug").
          baselineX: first,
          minY: (minValue - padding).clamp(0, double.infinity),
          maxY: maxValue + padding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.colorScheme.outline, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  valueLabel?.call(value) ?? value.round().toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: step,
                getTitlesWidget: (value, meta) {
                  // The last step lands on the last date, give or take a
                  // rounding, and the last date is drawn anyway.
                  if (value != meta.max && meta.max - value < step / 2) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      Formatters.dayMonth(
                        DateTime.fromMillisecondsSinceEpoch(value.round()),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
              getTooltipItems: (spots) => spots
                  .map(
                    (spot) => LineTooltipItem(
                      '${valueLabel?.call(spot.y) ?? spot.y.toStringAsFixed(1)}'
                      '\n${Formatters.date(DateTime.fromMillisecondsSinceEpoch(spot.x.round()))}',
                      theme.textTheme.bodySmall ?? const TextStyle(),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final p in points)
                  FlSpot(p.at.millisecondsSinceEpoch.toDouble(), p.value),
              ],
              isCurved: false,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(
                show: points.length <= 30,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bar per bucket. Used for weekly volume and workouts per week.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 160,
    this.color = AppColors.accent,
    this.valueLabel,
    this.labelEvery = 1,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final Color color;
  final String Function(double value)? valueLabel;

  /// A label under every so many bars, counted back from the newest so the
  /// newest always has one. Thirteen dates in a row do not fit on a phone.
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Nog geen gegevens',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 ||
                      index >= labels.length ||
                      (labels.length - 1 - index) % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      labels[index],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                    valueLabel?.call(rod.toY) ?? rod.toY.round().toString(),
                    theme.textTheme.bodySmall ?? const TextStyle(),
                  ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: values[i] > 0
                        ? color
                        : theme.colorScheme.surfaceContainerHighest,
                    width: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A line without axes or labels: the shape of a series at a glance, one
/// step per value, with a dot on the newest.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.height = 32,
    this.color = AppColors.accent,
  });

  final List<double> values;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(values, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  /// Room for the dot, so it is not cut off at the edges.
  static const double _inset = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final width = size.width - 2 * _inset;
    final height = size.height - 2 * _inset;

    Offset at(int i) => Offset(
      _inset + width * i / (values.length - 1),
      // A flat series is a flat line through the middle, not along the floor.
      high == low
          ? size.height / 2
          : _inset + height * (1 - (values[i] - low) / (high - low)),
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(values.length - 1), _inset, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || !_same(old.values, values);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A tiny inline bar chart without axes, for the dashboard card.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    this.height = 56,
    this.color = AppColors.accent,
  });

  final List<double> values;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: Container(
                height: maxValue <= 0
                    ? 3
                    : (values[i] / maxValue * height).clamp(3, height),
                decoration: BoxDecoration(
                  color: values[i] > 0
                      ? color.withValues(alpha: 0.85)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i != values.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
