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

  /// What a filled button is filled with, white on it: 4.8:1 and 4.7:1,
  /// where the accent and the red gave 3.8:1 and 3.9:1 (DECISIONS 305).
  static const accentFill = Color(0xFF2F6BEB);
  static const dangerFill = Color(0xFFD93036);

  /// The accent, green, amber and red as text, icons and lines on the light
  /// background, where the bright ones fell to 2:1 - the record amber to
  /// 1.8:1. Dark mode keeps the bright ones (DECISIONS 305).
  static const lightAccent = Color(0xFF2563EB);
  static const lightSuccess = Color(0xFF1B7F49);
  static const lightRecord = Color(0xFF9A5B00);

  /// A shade darker than [dangerFill]: as text that one was 4.4:1 on the
  /// grey background.
  static const lightDanger = Color(0xFFCF2C32);

  /// The edge of a field or a switch: 3:1 against what it holds and what
  /// it sits on, where the outline of a card gave 1.2:1 (DECISIONS 305).
  static const darkEdge = Color(0xFF6B7280);
  static const lightEdge = Color(0xFF7D838E);

  static bool _light(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  /// [accent] as text, an icon or a line, in the theme of [context].
  static Color accentOf(BuildContext context) =>
      _light(context) ? lightAccent : accent;

  /// [success] as text, an icon or a line, in the theme of [context].
  static Color successOf(BuildContext context) =>
      _light(context) ? lightSuccess : success;

  /// [record] as text, an icon or a line, in the theme of [context].
  static Color recordOf(BuildContext context) =>
      _light(context) ? lightRecord : record;

  /// [danger] as text, an icon or a line, in the theme of [context].
  static Color dangerOf(BuildContext context) =>
      _light(context) ? lightDanger : danger;

  /// [colour] darkened until it reads at 4.5:1 on [ground]: for letters in
  /// a colour that has to stay recognisable, like a muscle's.
  static Color readableOn(Color colour, Color ground) {
    var readable = colour;
    for (
      var step = 1;
      step <= 20 && _contrast(readable, ground) < 4.5;
      step++
    ) {
      readable = Color.lerp(colour, const Color(0xFF000000), step / 20)!;
    }
    return readable;
  }

  /// WCAG's contrast ratio.
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
  }

  /// Superset marker colours, indexed by superset group.
  static const supersets = <Color>[
    Color(0xFF7C5CFF),
    Color(0xFF00A9A5),
    Color(0xFFE0629B),
    Color(0xFFB07D2B),
  ];

  /// The colours a routine can be given, and with it every session started
  /// from it.
  ///
  /// Stored as the position in this list rather than as a colour value, so a
  /// later change of palette reaches routines that were already coloured, and
  /// so nothing in the database can name a colour the app does not have.
  static const routinePalette = <Color>[
    Color(0xFF3D7DFF), // blauw
    Color(0xFF00A9A5), // groenblauw
    Color(0xFF3BA55D), // groen
    Color(0xFFB07D2B), // amber
    Color(0xFFE0629B), // roze
    Color(0xFF7C5CFF), // paars
    Color(0xFFE5484D), // rood
    Color(0xFF8A8F98), // grijs
  ];

  /// The colour for a stored index, or null when there is none or the index is
  /// from a palette this version does not have.
  static Color? routineColor(int? index) =>
      index == null || index < 0 || index >= routinePalette.length
      ? null
      : routinePalette[index];

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

  /// The colour a muscle group is drawn in, everywhere.
  ///
  /// A group the user added has no entry above, and grey for all of them would
  /// make them indistinguishable from each other and from "unknown". So the
  /// name picks one: same name, same colour, on every screen and between runs.
  ///
  /// Deliberately not `hashCode` - Dart makes no promise that it is the same
  /// from one run to the next, and a muscle that changes colour when you
  /// reopen the app is worse than grey.
  static Color forMuscle(String? muscle) {
    final key = muscle?.toLowerCase();
    if (key == null || key.isEmpty) return const Color(0xFF8A8F98);

    final known = muscleColors[key];
    if (known != null) return known;

    var sum = 0;
    for (final unit in key.codeUnits) {
      sum = (sum * 31 + unit) % 0x7FFFFFFF;
    }
    return _ownMuscleColours[sum % _ownMuscleColours.length];
  }

  /// What a muscle group of your own is drawn in.
  ///
  /// The routine palette without its grey: grey is what the app uses for "no
  /// muscle", and a group that lands on it would read as nothing at all.
  static const _ownMuscleColours = <Color>[
    Color(0xFF3D7DFF),
    Color(0xFF00A9A5),
    Color(0xFF3BA55D),
    Color(0xFFB07D2B),
    Color(0xFFE0629B),
    Color(0xFF7C5CFF),
    Color(0xFFE5484D),
  ];
}
