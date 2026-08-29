import 'package:flutter/material.dart';

/// The whole palette of the app.
///
/// Deliberately small: neutral greys carry the layout, one accent drives every
/// action and progress indicator, green marks completion and amber marks a
/// personal record. No gradients, no second accent.
abstract final class AppColors {
  /// The single accent colour used for primary actions and progress.
  static const accent = Color(0xFF3D7DFF);
  static const accentDim = Color(0xFF2A5CBF);

  /// A completed set.
  static const success = Color(0xFF2FBF71);

  /// A personal record.
  static const record = Color(0xFFF5A623);

  static const danger = Color(0xFFE5484D);

  /// Superset marker colours, indexed by superset group.
  static const supersets = <Color>[
    Color(0xFF7C5CFF),
    Color(0xFF00A9A5),
    Color(0xFFE0629B),
    Color(0xFFB07D2B),
  ];

  // --- Dark (default) -------------------------------------------------------
  static const darkBackground = Color(0xFF0E0F12);
  static const darkSurface = Color(0xFF17191E);
  static const darkSurfaceHigh = Color(0xFF20232A);
  static const darkOutline = Color(0xFF2E323B);
  static const darkOnSurface = Color(0xFFECEDEF);
  static const darkOnSurfaceMuted = Color(0xFF9BA1AC);

  // --- Light ----------------------------------------------------------------
  static const lightBackground = Color(0xFFF6F7F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFEFF1F4);
  static const lightOutline = Color(0xFFD8DCE2);
  static const lightOnSurface = Color(0xFF16181C);
  static const lightOnSurfaceMuted = Color(0xFF61666F);

  /// A stable colour per muscle group, used for the exercise icons and the
  /// muscle map on the workout summary.
  /// The keys are the Dutch muscle names produced by
  /// `tool/build_exercise_seed.dart`.
  static const muscleColors = <String, Color>{
    'borst': Color(0xFFE05B5B),
    'lats': Color(0xFF3D7DFF),
    'bovenrug': Color(0xFF5A7CC0),
    'onderrug': Color(0xFF476AAE),
    'trapezius': Color(0xFF6E93E0),
    'schouders': Color(0xFFF5A623),
    'biceps': Color(0xFF7C5CFF),
    'triceps': Color(0xFF9B5CFF),
    'onderarmen': Color(0xFF6E7BFF),
    'buik': Color(0xFF00A9A5),
    'quadriceps': Color(0xFF2FBF71),
    'hamstrings': Color(0xFF1E9E5A),
    'bilspieren': Color(0xFFE0629B),
    'kuiten': Color(0xFF4CAF8A),
    'abductoren': Color(0xFFC46FB0),
    'adductoren': Color(0xFFA85FA0),
    'nek': Color(0xFF8A8F98),
  };

  static Color forMuscle(String? muscle) =>
      muscleColors[muscle?.toLowerCase()] ?? const Color(0xFF8A8F98);
}
