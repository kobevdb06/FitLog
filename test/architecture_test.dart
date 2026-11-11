import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every import of a file in lib, as the path from the root it points at:
/// `lib/features/chat/data/coach.dart`. Packages other than FitLog and the
/// Dart libraries are left out.
Map<String, List<String>> _imports() {
  final out = <String, List<String>>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll(r'\', '/');
    final targets = <String>[];
    for (final m in RegExp(
      r"^import '([^']+)'",
      multiLine: true,
    ).allMatches(file.readAsStringSync())) {
      final target = m.group(1)!;
      if (target.startsWith('package:fitlog/')) {
        targets.add('lib/${target.substring('package:fitlog/'.length)}');
      } else if (!target.contains(':')) {
        targets.add(Uri.parse(path).resolve(target).path);
      }
    }
    out[path] = targets;
  }
  return out;
}

/// The feature a path in lib/features belongs to, or null.
String? _feature(String path) {
  final parts = path.split('/');
  return parts.length > 3 && parts[0] == 'lib' && parts[1] == 'features'
      ? parts[2]
      : null;
}

/// How the code hangs together (DECISIONS 300 and 301).
void main() {
  test('core never reaches into a feature', () {
    // The app controller fetched the photo store from features/photos: the
    // base of the app depended on one of the rooms built on it.
    final offenders = [
      for (final MapEntry(key: file, value: targets) in _imports().entries)
        if (file.startsWith('lib/core/'))
          for (final target in targets)
            if (target.startsWith('lib/features/')) '$file: $target',
    ];
    expect(offenders, isEmpty);
  });

  test("the schema's build on the coach, not the other way round", () {
    final offenders = [
      for (final MapEntry(key: file, value: targets) in _imports().entries)
        if (_feature(file) == 'chat')
          for (final target in targets)
            if (_feature(target) == 'plans') '$file: $target',
    ];
    expect(offenders, isEmpty);
  });

  test('no two features start to import each other', () {
    // The pairs that already did when this test came (Fable report B5).
    // They are untangled when their files are worked on anyway; one that
    // is gone comes off this list, and none comes on.
    const known = {
      'chat <-> dashboard',
      'chat <-> exercises',
      'chat <-> progress',
      'chat <-> prompts',
      'chat <-> review',
      'chat <-> routines',
      'chat <-> settings',
      'chat <-> workout',
      'dashboard <-> prompts',
      'dashboard <-> readiness',
      'dashboard <-> routines',
      'deload <-> history',
      'exercises <-> workout',
      'health <-> morning',
      'health <-> progress',
      'morning <-> progress',
      'morning <-> prompts',
      'plans <-> routines',
      'progress <-> prompts',
      'progress <-> readiness',
      'prompts <-> readiness',
      'prompts <-> review',
    };
    final uses = <String, Set<String>>{};
    for (final MapEntry(key: file, value: targets) in _imports().entries) {
      final from = _feature(file);
      if (from == null) continue;
      for (final target in targets) {
        final to = _feature(target);
        if (to != null && to != from) uses.putIfAbsent(from, () => {}).add(to);
      }
    }
    final pairs = {
      for (final MapEntry(key: a, value: bs) in uses.entries)
        for (final b in bs)
          if (a.compareTo(b) < 0 && (uses[b]?.contains(a) ?? false))
            '$a <-> $b',
    };
    expect(pairs.difference(known), isEmpty, reason: 'new pairs');
    expect(known.difference(pairs), isEmpty, reason: 'take these off');
  });
}
