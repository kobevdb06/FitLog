import 'dart:io';

import 'package:fitlog/core/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen whose data did not load says so in a sentence, with a way to try
/// again (DECISIONS 291).
void main() {
  testWidgets('a sentence, the detail small, and Opnieuw proberen', (
    tester,
  ) async {
    var tried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorState(
            error: StateError('database is locked'),
            onRetry: () => tried++,
          ),
        ),
      ),
    );

    expect(find.text('Dit lukte niet'), findsOneWidget);
    expect(find.textContaining('database is locked'), findsOneWidget);
    await tester.tap(find.text('Opnieuw proberen'));
    expect(tried, 1);
  });

  test('no screen shows a raw error as all it has', () {
    final raw = RegExp(r"Center\(child: Text\('\$error'\)\)");
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            raw.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
