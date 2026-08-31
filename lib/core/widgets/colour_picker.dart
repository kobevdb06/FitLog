import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The dot that shows a routine's colour, and stands in for one that has none.
class ColourDot extends StatelessWidget {
  const ColourDot({super.key, required this.colorIndex, this.size = 12});

  final int? colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colour = AppColors.routineColor(colorIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour ?? Colors.transparent,
        shape: BoxShape.circle,
        border: colour == null
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
    );
  }
}

/// The row of colours a routine can be given, with "none" first.
class ColourPicker extends StatelessWidget {
  const ColourPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget swatch(int? index) {
      final colour = AppColors.routineColor(index);
      final isSelected = selected == index;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: InkWell(
          onTap: () => onChanged(index),
          customBorder: const CircleBorder(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colour ?? Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: colour == null
                ? Icon(
                    Icons.block,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          swatch(null),
          for (var i = 0; i < AppColors.routinePalette.length; i++) swatch(i),
        ],
      ),
    );
  }
}
