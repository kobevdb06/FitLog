import 'dart:io';

import 'package:fitlog/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Small points from the Fable report, U10 (DECISIONS 293).
void main() {
  Iterable<(String, String)> sources() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        yield (entity.path, entity.readAsStringSync());
      }
    }
  }

  test('niet ongedaan gemaakt worden, en overgeslagen', () {
    for (final (path, source) in sources()) {
      expect(source, isNot(contains('ongedaan gemaakt.')), reason: path);
      expect(source, isNot(contains("'Geskipt'")), reason: path);
      expect(source, isNot(contains("'geskipt'")), reason: path);
    }
  });

  test('the phone shows no white screen before a dark app', () {
    for (final path in [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      final xml = File(path).readAsStringSync();
      expect(xml, isNot(contains('@android:color/white')), reason: path);
      expect(xml, isNot(contains('?android:colorBackground')), reason: path);
    }
  });

  testWidgets('less motion asked for: a page just appears', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    const child = Text('pagina');
    final route = MaterialPageRoute<void>(builder: (_) => child);
    final builder =
        AppTheme.dark.pageTransitionsTheme.builders[TargetPlatform.android]!;
    final built = builder.buildTransitions(
      route,
      context,
      const AlwaysStoppedAnimation(0.5),
      const AlwaysStoppedAnimation(0),
      child,
    );
    expect(identical(built, child), isTrue);
  });
}
