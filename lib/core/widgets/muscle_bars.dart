import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../formatting/formatters.dart';

/// One muscle's line in [MuscleBars].
class MuscleBar {
  const MuscleBar({
    required this.muscle,
    required this.value,
    required this.label,
    this.usual = 0,
    this.lagging = false,
  });

  final String muscle;

  /// How long the bar is.
  final double value;

  /// Where the mark goes: what is usual for the muscle. 0 for no mark.
  final double usual;

  /// The number at the end of the line.
  final String label;

  /// Clearly short of [usual]: the bar and the number turn amber.
  final bool lagging;
}

/// A bar per muscle, with a mark where its usual is. A muscle clearly short
/// of its usual is coloured.
///
/// The bars share one scale, the usual marks included, so the longest bar or
/// mark reaches the end of the line.
class MuscleBars extends StatelessWidget {
  const MuscleBars({super.key, required this.bars});

  final List<MuscleBar> bars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = bars
        .expand((m) => [m.value, m.usual])
        .fold<double>(1, (a, b) => a > b ? a : b);
    // Room for "12,5" in a large font, without a wider column for a short
    // number in a small one.
    final scaler = MediaQuery.textScalerOf(context);
    final labelWidth = scaler.scale(36);
    // And the names as wide as the widest of them - a fixed 96 cut
    // "Hamstrings" to "Hamstrin…" in a large font - but never more than
    // two fifths of the line, so the bars keep their room.
    final nameStyle = theme.textTheme.bodyMedium;
    var widest = 0.0;
    for (final m in bars) {
      final painter = TextPainter(
        text: TextSpan(text: Formatters.muscle(m.muscle), style: nameStyle),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }

    return LayoutBuilder(
      builder: (context, constraints) => _bars(
        theme,
        scale,
        labelWidth,
        nameWidth: (widest + 8).clamp(0.0, constraints.maxWidth * 0.4),
      ),
    );
  }

  Widget _bars(
    ThemeData theme,
    double scale,
    double labelWidth, {
    required double nameWidth,
  }) {
    return Column(
      children: [
        for (final m in bars)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: nameWidth,
                  child: Text(
                    Formatters.muscle(m.muscle),
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final colour = m.lagging
                          ? AppColors.record
                          : theme.colorScheme.primary;
                      return SizedBox(
                        height: 14,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              width: box.maxWidth * m.value / scale,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colour,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            if (m.usual > 0)
                              Positioned(
                                left: (box.maxWidth * m.usual / scale - 1)
                                    .clamp(0, box.maxWidth - 2),
                                child: Container(
                                  width: 2,
                                  height: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    m.label,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: m.lagging ? AppColors.record : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
