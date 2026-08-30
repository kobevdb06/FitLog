import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../db/database.dart';
import '../theme/app_spacing.dart';
import '../util/paths.dart';
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

/// The frame files a user-made exercise points at, in order.
///
/// The bundled catalogue draws from the asset manifest; an exercise the user
/// made has no assets and carries its own pictures instead. Everything below
/// checks for those first, so a picture the user added always wins over the
/// fallback badge.
List<File> exerciseFrames(ExerciseRow exercise, AppPaths? paths) {
  if (paths == null) return const [];
  return [
    for (final name in [exercise.startImageFile, exercise.endImageFile])
      if (name != null) paths.photoFile(name),
  ];
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
    this.paths,
    this.size = 44,
  });

  final ExerciseRow exercise;
  final ExerciseImageManifest? manifest;

  /// Needed only to resolve the frames of a user-made exercise.
  final AppPaths? paths;

  final double size;

  @override
  Widget build(BuildContext context) {
    final manifest = this.manifest;
    final fallback = MuscleAvatar(
      muscle: exercise.primaryMuscle,
      size: size,
    );
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    final frames = exerciseFrames(exercise, paths);
    if (frames.isNotEmpty) {
      // The start position, never the loop: a list that animates its rows is
      // unreadable while it scrolls.
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: Image.file(
          frames.first,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * devicePixelRatio).round(),
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => fallback,
        ),
      );
    }

    if (exercise.isCustom ||
        manifest == null ||
        !manifest.hasImage(exercise.id)) {
      return fallback;
    }

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
/// Two sources feed it. A catalogue exercise has a bundled animation, which
/// Flutter decodes and loops itself. An exercise the user made has two plain
/// JPEGs instead, so the loop is driven here - same 700ms beat, so the two
/// look alike side by side.
///
/// Tapping pauses either of them on the frame that is showing, because a loop
/// is distracting while you are reading the instructions underneath.
class ExerciseAnimation extends StatefulWidget {
  const ExerciseAnimation({
    super.key,
    required this.exercise,
    required this.manifest,
    this.paths,
    this.height = 200,
  });

  final ExerciseRow exercise;
  final ExerciseImageManifest? manifest;

  /// Needed only to resolve the frames of a user-made exercise.
  final AppPaths? paths;

  final double height;

  /// How long one frame is held. The bundled animations are built at this
  /// interval, so the two kinds run at the same speed.
  static const Duration frameDuration = Duration(milliseconds: 700);

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation> {
  bool _paused = false;
  int _frame = 0;
  Timer? _timer;

  List<File> get _frames => exerciseFrames(widget.exercise, widget.paths);

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(ExerciseAnimation old) {
    super.didUpdateWidget(old);
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// The timer only runs while there are two frames to alternate and the user
  /// has not paused it; a single frame is a still picture, not a loop.
  void _syncTimer() {
    final shouldRun = !_paused && _frames.length == 2;
    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(ExerciseAnimation.frameDuration, (_) {
        if (mounted) setState(() => _frame = 1 - _frame);
      });
    } else if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _syncTimer();
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    if (frames.isNotEmpty) return _buildOwnFrames(frames);

    final manifest = widget.manifest;
    if (widget.exercise.isCustom ||
        manifest == null ||
        !manifest.hasImage(widget.exercise.id)) {
      return _Fallback(exercise: widget.exercise, height: widget.height);
    }
    return _buildBundled(manifest);
  }

  Widget _buildOwnFrames(List<File> frames) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final animated = frames.length == 2;

    return _Frame(
      label: widget.exercise.name,
      height: widget.height,
      animated: animated,
      paused: _paused,
      onTap: animated ? _togglePause : null,
      // Both frames stay built, so switching between them is a repaint rather
      // than a decode. Decoding on the beat would show as a stutter.
      child: IndexedStack(
        index: animated ? _frame : 0,
        alignment: Alignment.center,
        children: [
          for (final file in frames)
            Image.file(
              file,
              height: widget.height,
              fit: BoxFit.contain,
              cacheWidth: (360 * devicePixelRatio).round(),
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => _Fallback(
                exercise: widget.exercise,
                height: widget.height,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBundled(ExerciseImageManifest manifest) {
    final animated = manifest.isAnimated(widget.exercise.id);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return _Frame(
      label: widget.exercise.name,
      height: widget.height,
      animated: animated,
      paused: _paused,
      onTap: animated ? _togglePause : null,
      // Flutter pauses a multi-frame image when TickerMode is off, which is
      // exactly what tap-to-pause needs.
      child: TickerMode(
        enabled: !_paused,
        child: Image.asset(
          manifest.assetFor(widget.exercise.id),
          height: widget.height,
          fit: BoxFit.contain,
          cacheWidth: (360 * devicePixelRatio).round(),
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) =>
              _Fallback(exercise: widget.exercise, height: widget.height),
        ),
      ),
    );
  }
}

/// The card the illustration sits in, with the pause hint over it.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.label,
    required this.height,
    required this.animated,
    required this.paused,
    required this.onTap,
    required this.child,
  });

  final String label;
  final double height;
  final bool animated;
  final bool paused;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Illustratie van $label',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Container(
                height: height,
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: child,
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
                          paused ? Icons.play_arrow : Icons.pause,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          paused ? 'Gepauzeerd' : 'Tik om te pauzeren',
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
