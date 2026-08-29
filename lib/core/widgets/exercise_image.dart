import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../db/database.dart';
import '../theme/app_spacing.dart';
import 'common.dart';

/// Where `tool/build_exercise_images.dart` writes its output.
const String kExerciseAssetDir = 'assets/exercises';
const String kExerciseManifestAsset = '$kExerciseAssetDir/manifest.json';

/// Which exercises have a bundled illustration, and in what shape.
///
/// The tool writes this alongside the images so neither the app nor the tests
/// have to guess a file name and hope: an id that is not listed here has no
/// asset on purpose, and the UI falls back to the muscle icon.
class ExerciseImageManifest {
  const ExerciseImageManifest({
    required this.format,
    required this.animated,
    required this.staticOnly,
    required this.withoutImages,
  });

  const ExerciseImageManifest.empty()
    : format = 'webp',
      animated = const {},
      staticOnly = const {},
      withoutImages = const {};

  /// `webp` or, when libwebp was unavailable at build time, `gif`.
  final String format;

  /// Ids with a two-frame looping animation.
  final Set<String> animated;

  /// Ids with a single still frame.
  final Set<String> staticOnly;

  /// Ids the source dataset has no picture for.
  final Set<String> withoutImages;

  bool hasImage(String id) =>
      animated.contains(id) || staticOnly.contains(id);

  bool isAnimated(String id) => animated.contains(id);

  String assetFor(String id) => '$kExerciseAssetDir/$id.$format';

  String thumbFor(String id) => '$kExerciseAssetDir/${id}_thumb.$format';

  static ExerciseImageManifest parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    Set<String> read(String key) =>
        ((json[key] as List?) ?? const []).cast<String>().toSet();

    return ExerciseImageManifest(
      format: json['format'] as String? ?? 'webp',
      animated: read('animated'),
      staticOnly: read('static_only'),
      withoutImages: read('without_images'),
    );
  }

  /// Returns an empty manifest when the assets were never generated, so a
  /// checkout without them still runs.
  static Future<ExerciseImageManifest> load() async {
    try {
      return parse(await rootBundle.loadString(kExerciseManifestAsset));
    } on Object {
      return const ExerciseImageManifest.empty();
    }
  }
}

/// The small still image used in lists and search results.
///
/// Never animated: decoding dozens of animations while scrolling is what makes
/// a list stutter.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({
    super.key,
    required this.exercise,
    required this.manifest,
    this.size = 44,
  });

  final ExerciseRow exercise;
  final ExerciseImageManifest? manifest;
  final double size;

  @override
  Widget build(BuildContext context) {
    final manifest = this.manifest;
    final fallback = MuscleAvatar(
      muscle: exercise.primaryMuscle,
      size: size,
    );

    if (exercise.isCustom ||
        manifest == null ||
        !manifest.hasImage(exercise.id)) {
      return fallback;
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Image.asset(
        manifest.thumbFor(exercise.id),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Decoding at display size instead of full asset size.
        cacheWidth: (size * devicePixelRatio).round(),
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => fallback,
      ),
    );
  }
}

/// The looping two-frame illustration on the exercise detail screen.
///
/// Tapping pauses it on the frame that is showing, because a loop is
/// distracting while you are reading the instructions underneath.
class ExerciseAnimation extends StatefulWidget {
  const ExerciseAnimation({
    super.key,
    required this.exercise,
    required this.manifest,
    this.height = 200,
  });

  final ExerciseRow exercise;
  final ExerciseImageManifest? manifest;
  final double height;

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation> {
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final manifest = widget.manifest;
    if (widget.exercise.isCustom ||
        manifest == null ||
        !manifest.hasImage(widget.exercise.id)) {
      return _Fallback(exercise: widget.exercise, height: widget.height);
    }

    final animated = manifest.isAnimated(widget.exercise.id);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Semantics(
      label: 'Illustratie van ${widget.exercise.name}',
      child: GestureDetector(
        onTap: animated ? () => setState(() => _paused = !_paused) : null,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Container(
                height: widget.height,
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                // Flutter pauses a multi-frame image when TickerMode is off,
                // which is exactly what tap-to-pause needs.
                child: TickerMode(
                  enabled: !_paused,
                  child: Image.asset(
                    manifest.assetFor(widget.exercise.id),
                    height: widget.height,
                    fit: BoxFit.contain,
                    cacheWidth: (360 * devicePixelRatio).round(),
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stack) => _Fallback(
                      exercise: widget.exercise,
                      height: widget.height,
                    ),
                  ),
                ),
              ),
            ),
            if (animated)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _paused ? Icons.play_arrow : Icons.pause,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _paused ? 'Gepauzeerd' : 'Tik om te pauzeren',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.exercise, required this.height});

  final ExerciseRow exercise;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: MuscleAvatar(muscle: exercise.primaryMuscle, size: height * 0.4),
    );
  }
}
