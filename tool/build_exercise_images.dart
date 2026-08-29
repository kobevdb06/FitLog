// Build-time tool. Downloads the two frames free-exercise-db ships per
// exercise (start position and end position), scales them down and writes an
// animated asset plus a static thumbnail per exercise.
//
// Run with:  dart run tool/build_exercise_images.dart
//
// Together with tool/build_exercise_seed.dart this is the only code in the
// repository that touches the network, and neither ever runs inside the app.
//
// Source: https://github.com/yuhonas/free-exercise-db (Unlicense, public
// domain).
//
// Output:
//   assets/exercises/<id>.webp         animated, 2 frames, looping
//   assets/exercises/<id>_thumb.webp   frame 0 only, static
//   assets/exercises/manifest.json     what exists and what is deliberately
//                                      missing, so the app never guesses
//
// Encoding needs `img2webp` and `cwebp` from libwebp. They are looked up on
// PATH and then under .build_cache/tools/. Without them the tool falls back to
// 2-frame GIFs, which are far bigger and palette-limited; see
// docs/DECISIONS.md.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const _baseUrl =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises';

const _seedPath = 'assets/data/exercises.json';
const _outputDir = 'assets/exercises';
const _cacheDir = '.build_cache';

/// The brief's hard ceiling for the whole asset directory.
const int _budgetBytes = 35 * 1024 * 1024;

const int _maxParallelDownloads = 8;
const int _downloadAttempts = 3;

class Options {
  const Options({
    this.frameWidth = 320,
    this.thumbWidth = 160,
    this.quality = 72,
    this.thumbQuality = 75,
    this.frameMs = 700,
    this.limit,
  });

  final int frameWidth;
  final int thumbWidth;
  final int quality;
  final int thumbQuality;
  final int frameMs;

  /// Only process the first N exercises. Used while iterating on the tool.
  final int? limit;

  Options copyWith({int? frameWidth, int? quality}) => Options(
    frameWidth: frameWidth ?? this.frameWidth,
    thumbWidth: thumbWidth,
    quality: quality ?? this.quality,
    thumbQuality: thumbQuality,
    frameMs: frameMs,
    limit: limit,
  );
}

void main(List<String> args) async {
  var options = Options(
    frameWidth: _intArg(args, '--width') ?? 320,
    thumbWidth: _intArg(args, '--thumb-width') ?? 160,
    quality: _intArg(args, '--quality') ?? 72,
    frameMs: _intArg(args, '--frame-ms') ?? 700,
    limit: _intArg(args, '--limit'),
  );

  final tools = WebpTools.locate();
  if (tools == null) {
    stderr.writeln(
      'img2webp/cwebp niet gevonden. Val terug op GIF; dat is fors groter.\n'
      'Installeer libwebp (brew install webp, apt install webp) of pak de '
      'Windows-binaries en zet ze in $_cacheDir/tools/.',
    );
  } else {
    stdout.writeln('libwebp gevonden: ${tools.img2webp}');
  }

  final seed =
      jsonDecode(await File(_seedPath).readAsString()) as Map<String, dynamic>;
  var exercises = (seed['exercises'] as List).cast<Map<String, dynamic>>();
  if (options.limit != null) {
    exercises = exercises.take(options.limit!).toList();
  }
  stdout.writeln('${exercises.length} oefeningen in de seed.');

  // --- 1. Fetch every frame, cached -----------------------------------------
  final wanted = <String>{};
  for (final exercise in exercises) {
    wanted.addAll((exercise['images'] as List).cast<String>());
  }
  stdout.writeln('${wanted.length} frames nodig.');

  final downloaded = await _downloadAll(wanted.toList());
  stdout.writeln('${downloaded.length} frames beschikbaar in de cache.');

  // --- 2. Encode, retrying smaller if the budget is blown --------------------
  var report = await _encodeAll(exercises, downloaded, options, tools);

  // The knobs from the brief, in the order it prescribes. WebP is already the
  // first one; these are the remaining two that keep every exercise animated.
  if (report.totalBytes > _budgetBytes) {
    stdout.writeln(
      'Budget overschreden (${_mb(report.totalBytes)}). Breedte terug naar 280.',
    );
    options = options.copyWith(frameWidth: 280);
    report = await _encodeAll(exercises, downloaded, options, tools);
  }
  if (report.totalBytes > _budgetBytes) {
    stdout.writeln(
      'Nog steeds over budget (${_mb(report.totalBytes)}). Kwaliteit naar 60.',
    );
    options = options.copyWith(quality: 60);
    report = await _encodeAll(exercises, downloaded, options, tools);
  }

  // --- 3. Manifest, so the app and the test never guess ----------------------
  await File(p.join(_outputDir, 'manifest.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'source': 'https://github.com/yuhonas/free-exercise-db',
      'license': 'Unlicense (public domain)',
      'generated_by': 'tool/build_exercise_images.dart',
      'format': report.format,
      'frame_width': options.frameWidth,
      'thumb_width': options.thumbWidth,
      'frame_ms': options.frameMs,
      'animated': report.animated.toList()..sort(),
      'static_only': report.staticOnly.toList()..sort(),
      'without_images': report.withoutImages.toList()..sort(),
      'failed': report.failed.keys.toList()..sort(),
    }),
  );

  stdout
    ..writeln('')
    ..writeln('Formaat:      ${report.format}')
    ..writeln('Geanimeerd:   ${report.animated.length}')
    ..writeln('Alleen stil:  ${report.staticOnly.length}')
    ..writeln('Geen beeld:   ${report.withoutImages.length}')
    ..writeln('Mislukt:      ${report.failed.length}')
    ..writeln('Totale maat:  ${_mb(report.totalBytes)} '
        '(budget ${_mb(_budgetBytes)})');

  if (report.failed.isNotEmpty) {
    stderr.writeln('Mislukte oefeningen: ${report.failed.keys.join(', ')}');
    exitCode = 1;
  }
  if (report.totalBytes > _budgetBytes) {
    stderr.writeln(
      'BUDGET OVERSCHREDEN. Volgende knop uit de opdracht: animaties beperken '
      'tot de 300 meest gebruikte oefeningen.',
    );
    exitCode = 1;
  }
}

// --- Downloading -------------------------------------------------------------

/// Returns the relative image paths that are present in the cache.
Future<Set<String>> _downloadAll(List<String> paths) async {
  final cache = Directory(p.join(_cacheDir, 'src'));
  await cache.create(recursive: true);

  final available = <String>{};
  final queue = <String>[];
  for (final path in paths) {
    if (await _cacheFile(path).exists()) {
      available.add(path);
    } else {
      queue.add(path);
    }
  }
  if (queue.isEmpty) {
    stdout.writeln('Alles stond al in de cache.');
    return available;
  }
  stdout.writeln('${queue.length} nog te downloaden.');

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  var done = 0;
  var failed = 0;

  Future<void> worker() async {
    while (true) {
      if (queue.isEmpty) return;
      final path = queue.removeLast();
      final ok = await _download(client, path);
      if (ok) {
        available.add(path);
      } else {
        failed++;
      }
      done++;
      if (done % 100 == 0) {
        stdout.writeln('  $done/${done + queue.length} ...');
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < _maxParallelDownloads; i++) worker(),
  ]);
  client.close();

  if (failed > 0) stderr.writeln('$failed frames konden niet opgehaald worden.');
  return available;
}

File _cacheFile(String imagePath) =>
    File(p.join(_cacheDir, 'src', imagePath.replaceAll('/', '__')));

Future<bool> _download(HttpClient client, String imagePath) async {
  for (var attempt = 1; attempt <= _downloadAttempts; attempt++) {
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/$imagePath'));
      final response = await request.close();
      if (response.statusCode != 200) {
        // A 404 will not fix itself; anything else might.
        if (response.statusCode == 404) {
          await response.drain<void>();
          return false;
        }
        await response.drain<void>();
        throw HttpException('HTTP ${response.statusCode}');
      }
      final bytes = await _collect(response);
      final file = _cacheFile(imagePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } on Object catch (error) {
      if (attempt == _downloadAttempts) {
        stderr.writeln('  mislukt: $imagePath ($error)');
        return false;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
  return false;
}

Future<Uint8List> _collect(HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

// --- Encoding ----------------------------------------------------------------

class EncodeReport {
  EncodeReport(this.format);

  final String format;
  final Set<String> animated = {};
  final Set<String> staticOnly = {};
  final Set<String> withoutImages = {};

  /// Exercise id to the reason its assets could not be produced.
  final Map<String, String> failed = {};
  int totalBytes = 0;
}

Future<EncodeReport> _encodeAll(
  List<Map<String, dynamic>> exercises,
  Set<String> available,
  Options options,
  WebpTools? tools,
) async {
  final out = Directory(_outputDir);
  if (await out.exists()) await out.delete(recursive: true);
  await out.create(recursive: true);

  final work = Directory(p.join(_cacheDir, 'frames'));
  if (await work.exists()) await work.delete(recursive: true);
  await work.create(recursive: true);

  final report = EncodeReport(tools == null ? 'gif' : 'webp');
  final extension = tools == null ? 'gif' : 'webp';
  var index = 0;

  for (final exercise in exercises) {
    final id = exercise['id'] as String;
    final frames = (exercise['images'] as List)
        .cast<String>()
        .where(available.contains)
        .toList();

    if (frames.isEmpty) {
      report.withoutImages.add(id);
      continue;
    }

    try {
      // Resizing happens on another isolate: 1700 decodes on the main one make
      // the tool feel hung.
      //
      // Every frame of one exercise is forced to the exact size of frame 0.
      // The source frames occasionally differ by a pixel in height, and
      // img2webp refuses to animate frames whose dimensions do not match.
      final resized = <String>[];
      int? targetHeight;
      for (var i = 0; i < frames.length; i++) {
        final target = p.join(work.path, '${id}_$i.png');
        targetHeight = await _resizeTo(
          source: _cacheFile(frames[i]),
          target: File(target),
          width: options.frameWidth,
          height: targetHeight,
        );
        resized.add(target);
      }

      final thumbSource = p.join(work.path, '${id}_thumb.png');
      await _resizeTo(
        source: _cacheFile(frames.first),
        target: File(thumbSource),
        width: options.thumbWidth,
      );

      final animationPath = p.join(_outputDir, '$id.$extension');
      final thumbPath = p.join(_outputDir, '${id}_thumb.$extension');

      if (tools != null) {
        if (resized.length >= 2) {
          await tools.animate(
            frames: resized,
            output: animationPath,
            durationMs: options.frameMs,
            quality: options.quality,
          );
          report.animated.add(id);
        } else {
          await tools.still(
            input: resized.first,
            output: animationPath,
            quality: options.quality,
          );
          report.staticOnly.add(id);
        }
        await tools.still(
          input: thumbSource,
          output: thumbPath,
          quality: options.thumbQuality,
        );
      } else {
        await _writeGif(resized, animationPath, options.frameMs);
        resized.length >= 2
            ? report.animated.add(id)
            : report.staticOnly.add(id);
        await _writeGif([thumbSource], thumbPath, options.frameMs);
      }
    } on Object catch (error) {
      // One bad exercise must not cost the other 875. The failure is recorded
      // and reported, and the run still exits non-zero.
      report.failed[id] = '$error';
      stderr.writeln('  overgeslagen: $id ($error)');
    }

    if (++index % 100 == 0) stdout.writeln('  gecodeerd: $index');
  }

  await for (final entity in out.list()) {
    if (entity is File) report.totalBytes += await entity.length();
  }
  return report;
}

/// Scales [source] to [width] and writes it as PNG, so the only lossy step is
/// the final WebP encode.
///
/// Pass [height] to pin the result to an exact size; returns the height that
/// was produced so the next frame can be matched to it.
Future<int> _resizeTo({
  required File source,
  required File target,
  required int width,
  int? height,
}) async {
  final bytes = await source.readAsBytes();
  final result = await Isolate.run(() {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final scaled = img.copyResize(
      decoded,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
    return (png: img.encodePng(scaled, level: 6), height: scaled.height);
  });
  if (result == null) {
    throw StateError('Kon ${source.path} niet decoderen');
  }
  await target.writeAsBytes(result.png, flush: true);
  return result.height;
}

/// The fallback when libwebp is absent: a 2-frame GIF.
Future<void> _writeGif(
  List<String> framePaths,
  String output,
  int frameMs,
) async {
  final encoder = img.GifEncoder(
    repeat: 0,
    samplingFactor: 10,
    numColors: 64,
  );
  for (final path in framePaths) {
    final frame = img.decodeImage(await File(path).readAsBytes());
    if (frame == null) continue;
    // GifEncoder takes the delay in hundredths of a second.
    encoder.addFrame(frame, duration: (frameMs / 10).round());
  }
  final bytes = encoder.finish();
  if (bytes != null) await File(output).writeAsBytes(bytes, flush: true);
}

// --- libwebp -----------------------------------------------------------------

class WebpTools {
  const WebpTools({required this.img2webp, required this.cwebp});

  final String img2webp;
  final String cwebp;

  static WebpTools? locate() {
    final img2webp = _find('img2webp');
    final cwebp = _find('cwebp');
    if (img2webp == null || cwebp == null) return null;
    return WebpTools(img2webp: img2webp, cwebp: cwebp);
  }

  static String? _find(String name) {
    final exe = Platform.isWindows ? '$name.exe' : name;

    // On PATH?
    final which = Platform.isWindows ? 'where' : 'which';
    try {
      final result = Process.runSync(which, [name]);
      if (result.exitCode == 0) {
        final first = (result.stdout as String).trim().split('\n').first.trim();
        if (first.isNotEmpty && File(first).existsSync()) return first;
      }
    } on ProcessException {
      // Fall through to the bundled copy.
    }

    // Unpacked into the build cache?
    final tools = Directory(p.join(_cacheDir, 'tools'));
    if (tools.existsSync()) {
      for (final entity in tools.listSync(recursive: true)) {
        if (entity is File && p.basename(entity.path) == exe) {
          return entity.path;
        }
      }
    }
    return null;
  }

  Future<void> animate({
    required List<String> frames,
    required String output,
    required int durationMs,
    required int quality,
  }) async {
    final args = <String>['-loop', '0'];
    for (final frame in frames) {
      args.addAll(['-d', '$durationMs', '-lossy', '-q', '$quality', frame]);
    }
    args.addAll(['-o', output]);
    await _run(img2webp, args);
  }

  Future<void> still({
    required String input,
    required String output,
    required int quality,
  }) => _run(cwebp, ['-quiet', '-q', '$quality', input, '-o', output]);

  static Future<void> _run(String executable, List<String> args) async {
    final result = await Process.run(executable, args);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        args,
        '${result.stderr}',
        result.exitCode,
      );
    }
  }
}

// --- Small helpers -----------------------------------------------------------

int? _intArg(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == name && i + 1 < args.length) {
      return int.tryParse(args[i + 1]);
    }
    if (args[i].startsWith('$name=')) {
      return int.tryParse(args[i].substring(name.length + 1));
    }
  }
  return null;
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
