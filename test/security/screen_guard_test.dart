import 'dart:io';

import 'package:fitlog/core/security/screen_guard.dart';
import 'package:fitlog/features/lock/presentation/pin_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The PIN and the twelve words, kept off other people's screens: no
/// screenshots while they are up, no picture in the recent apps with a PIN,
/// and the words on the clipboard for a minute only (DECISIONS 265).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    ScreenGuard.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenGuard.channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenGuard.channel, null);
  });

  List<Object?> secure() => [
    for (final call in calls)
      if (call.method == 'secure') call.arguments,
  ];

  Widget pad() => MaterialApp(
    home: Scaffold(
      body: PinPad(entered: '', onDigit: (_) {}, onBackspace: () {}),
    ),
  );

  testWidgets('a PIN pad keeps the window secure while it is there', (
    tester,
  ) async {
    await tester.pumpWidget(pad());
    expect(secure(), [true]);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(secure(), [true, false]);
  });

  testWidgets('a dialog over a secure screen does not let go of it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SecureScreen(child: SecureScreen(child: SizedBox())),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: SecureScreen(child: SizedBox())),
    );
    expect(secure(), [true], reason: 'one still asks');

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(secure(), [true, false]);
  });

  test('with a PIN the recent apps show no picture of FitLog', () async {
    await ScreenGuard.followPin(pin: true);
    await ScreenGuard.followPin(pin: false);

    expect(
      [for (final c in calls) (c.method, c.arguments)],
      [('recents', false), ('recents', true)],
    );
  });

  test('the words go on the clipboard as sensitive, for a minute', () async {
    await ScreenGuard.copySecret('een twee drie');

    expect(calls.single.method, 'copySecret');
    expect(calls.single.arguments, {
      'text': 'een twee drie',
      'clearAfterMs': 60000,
    });
  });

  test('and nowhere is the phrase put on the clipboard as it is', () {
    for (final path in [
      'lib/features/onboarding/presentation/onboarding_flow.dart',
      'lib/features/settings/presentation/security_settings_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('ClipboardData(text: phrase)')),
        reason: path,
      );
      expect(source, contains('ScreenGuard.copySecret(phrase)'), reason: path);
    }
  });

  test('every screen that shows or asks for the words is secure', () {
    for (final path in [
      'lib/features/onboarding/presentation/onboarding_flow.dart',
      'lib/features/settings/presentation/security_settings_screen.dart',
      'lib/features/lock/presentation/recovery_unlock_screen.dart',
      'lib/features/lock/presentation/keys_lost_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('SecureScreen('),
        reason: path,
      );
    }
  });
}
