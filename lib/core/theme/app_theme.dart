import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Builds the light and dark [ThemeData]. Dark is the default.
abstract final class AppTheme {
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceHigh = isDark
        ? AppColors.darkSurfaceHigh
        : AppColors.lightSurfaceHigh;
    final outline = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final onSurface = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final onSurfaceMuted = isDark
        ? AppColors.darkOnSurfaceMuted
        : AppColors.lightOnSurfaceMuted;
    // In light mode the darker accent, green, amber and red, which read on
    // white; in the dark the bright ones (DECISIONS 305).
    final accent = isDark ? AppColors.accent : AppColors.lightAccent;
    final edge = isDark ? AppColors.darkEdge : AppColors.lightEdge;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: isDark ? AppColors.accentDim : const Color(0xFFDCE7FF),
      onPrimaryContainer: isDark ? Colors.white : AppColors.accentDim,
      secondary: accent,
      onSecondary: Colors.white,
      tertiary: isDark ? AppColors.record : AppColors.lightRecord,
      onTertiary: isDark ? Colors.black : Colors.white,
      error: isDark ? AppColors.danger : AppColors.lightDanger,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceHigh,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainer: surface,
      surfaceContainerLow: background,
      surfaceContainerLowest: background,
      onSurfaceVariant: onSurfaceMuted,
      outline: outline,
      outlineVariant: outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      // Rows that end in a chevron pointing right should open something that
      // comes from the right. Android's own default is a zoom, which says
      // nothing about direction and leaves the arrow meaning nothing.
      //
      // One place rather than per route: every list in the app - routines,
      // the catalogue, your history, the settings - is the same gesture, and
      // they would drift apart if each one decided for itself. The screens
      // that rise from the bottom carry their own page and are untouched by
      // this.
      //
      // With less motion asked for in Android's settings, a page just
      // appears: that was respected in two places only (DECISIONS 293).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FromTheRight(),
          TargetPlatform.iOS: _FromTheRight(),
          TargetPlatform.macOS: _FromTheRight(),
        },
      ),
    );

    final text = _textTheme(base.textTheme, onSurface);

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
      // The overflow menus were the one surface still wearing Material's
      // defaults: square-ish, tinted a colour nothing else in the app uses,
      // and spaced for a tablet. They are cards like every other raised thing
      // here, and they sit closer together.
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: outline),
        ),
        labelTextStyle: WidgetStatePropertyAll(text.bodyMedium),
        iconColor: onSurfaceMuted,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceMuted,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: onSurfaceMuted),
        minVerticalPadding: AppSpacing.md,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? accent
                : onSurfaceMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? accent
                : onSurfaceMuted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // White on the accent was 3.8:1 (DECISIONS 305).
          backgroundColor: AppColors.accentFill,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, AppSpacing.minTouch),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouch),
          foregroundColor: onSurface,
          side: BorderSide(color: outline),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouch),
          textStyle: text.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouch),
          side: BorderSide(color: outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: AppColors.accent.withValues(alpha: 0.20),
        side: BorderSide(color: outline),
        labelStyle: text.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: text.bodyMedium?.copyWith(color: onSurfaceMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        // The card's outline was 1.2:1 against the fill: a field you could
        // hardly see (DECISIONS 305).
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: edge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: edge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : onSurfaceMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : surfaceHigh,
        ),
        // Off, it was 1.1:1 against the card (DECISIONS 305).
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : edge,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onSurface,
        unselectedLabelColor: onSurfaceMuted,
        indicatorColor: accent,
        dividerColor: outline,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
      ),
    );
  }

  /// Every number in this app is rendered with tabular figures so that columns
  /// do not dance while the user types.
  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme _textTheme(TextTheme base, Color onSurface) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: _tabular,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: _tabular,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: _tabular,
          ),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(fontFeatures: _tabular),
          bodyMedium: base.bodyMedium?.copyWith(fontFeatures: _tabular),
          bodySmall: base.bodySmall?.copyWith(fontFeatures: _tabular),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);
  }
}

/// From the right, as a chevron says - or, with less motion asked for, no
/// movement at all.
class _FromTheRight extends PageTransitionsBuilder {
  const _FromTheRight();

  static const _slide = CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _slide.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
