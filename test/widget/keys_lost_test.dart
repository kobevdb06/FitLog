import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/security/recovery_phrase.dart';
import 'package:fitlog/features/lock/presentation/keys_lost_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Keys gone, data still there (DECISIONS 241).
///
/// A device without keys was taken for a new one. Onboarding then made a new
/// key, which never opened the database that was still on the phone, and
/// the only way on was to throw it away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  SecurityStatus status({bool initialised = false, LockMode? mode}) =>
      SecurityStatus(
        initialised: initialised,
        mode: mode ?? LockMode.none,
        biometricEnabled: false,
        hasRecoveryPhrase: initialised,
        consecutiveFailures: 0,
        lastFailureAt: null,
      );

  group('where a start goes', () {
    test('no keys and no data: a new device', () {
      expect(
        startStepFor(
          security: status(),
          hasDirectKey: false,
          databaseExists: false,
        ),
        StartStep.onboarding,
      );
    });

    test('no keys, but data: the keys were lost, not a new device', () {
      expect(
        startStepFor(
          security: status(),
          hasDirectKey: false,
          databaseExists: true,
        ),
        StartStep.recovery,
      );
    });

    test('a key without a PIN that went missing, with data: the same', () {
      expect(
        startStepFor(
          security: status(initialised: true),
          hasDirectKey: false,
          databaseExists: true,
        ),
        StartStep.recovery,
      );
    });

    test('a PIN: the lock screen; a key without one: straight in', () {
      expect(
        startStepFor(
          security: status(initialised: true, mode: LockMode.pin),
          hasDirectKey: false,
          databaseExists: true,
        ),
        StartStep.locked,
      );
      expect(
        startStepFor(
          security: status(initialised: true),
          hasDirectKey: true,
          databaseExists: true,
        ),
        StartStep.open,
      );
    });
  });

  Future<_Stuck> pump(
    WidgetTester tester,
    AppState state,
    Widget screen,
  ) async {
    final controller = _Stuck(state);
    await tester.pumpWidget(
      wrapForTest(
        screen,
        overrides: [appControllerProvider.overrideWith(() => controller)],
      ),
    );
    await tester.pump();
    return controller;
  }

  group('the screen', () {
    testWidgets('says the data is still there, and asks for the twelve '
        'words', (tester) async {
      await pump(
        tester,
        const AppNeedsRecovery(unreadable: false, canUsePhrase: true),
        const KeysLostScreen(),
      );

      expect(find.text('Je sleutel is weg, je gegevens niet'), findsOneWidget);
      expect(find.text('Openen met herstelzin'), findsOneWidget);
      expect(find.text('Opnieuw proberen'), findsNothing);
      expect(find.text('Opnieuw beginnen'), findsOneWidget);
    });

    testWidgets('hands the words over, and shows why they did not fit', (
      tester,
    ) async {
      final controller = await pump(
        tester,
        const AppNeedsRecovery(unreadable: false, canUsePhrase: true),
        const KeysLostScreen(),
      );
      final phrase = generateRecoveryPhrase();

      await tester.enterText(find.byType(TextField), phrase);
      await tester.tap(find.text('Openen met herstelzin'));
      await tester.pumpAndSettle();

      expect(controller.phrases, [phrase]);
      expect(find.text(_Stuck.refusal), findsOneWidget);
    });

    testWidgets('when Android would not read the key: try again as well', (
      tester,
    ) async {
      final controller = await pump(
        tester,
        const AppNeedsRecovery(unreadable: true, canUsePhrase: true),
        const KeysLostScreen(),
      );

      expect(find.text('Android geeft je sleutel niet vrij'), findsOneWidget);
      await tester.tap(find.text('Opnieuw proberen'));
      await tester.pump();
      expect(controller.retried, isTrue);
    });

    testWidgets('without a copy the words could open: what a backup can do', (
      tester,
    ) async {
      await pump(
        tester,
        const AppNeedsRecovery(unreadable: false, canUsePhrase: false),
        const KeysLostScreen(),
      );

      expect(find.text('Openen met herstelzin'), findsNothing);
      expect(find.textContaining('.fitlog-bestand'), findsOneWidget);
    });
  });

  testWidgets('on a narrow phone with large text, everything fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final state in const [
      AppNeedsRecovery(unreadable: true, canUsePhrase: true),
      AppNeedsRecovery(unreadable: false, canUsePhrase: false),
    ]) {
      await pump(tester, state, const KeysLostScreen());
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Opnieuw beginnen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Opnieuw beginnen'), findsOneWidget);
    }
    await pump(
      tester,
      const AppDatabaseMissing(),
      const DatabaseMissingScreen(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('data gone, keys still there: an empty app only when asked', (
    tester,
  ) async {
    final controller = await pump(
      tester,
      const AppDatabaseMissing(),
      const DatabaseMissingScreen(),
    );

    expect(
      find.text('Je gegevens staan niet meer op dit toestel'),
      findsOneWidget,
    );
    await tester.tap(find.text('Verder met lege gegevens'));
    await tester.pump();
    expect(controller.startedEmpty, isTrue);
  });
}

/// An app controller stuck in one state, noting what it was asked.
class _Stuck extends AppController {
  _Stuck(this._state);

  static const refusal =
      'Deze herstelzin hoort niet bij de gegevens op dit toestel.';

  final AppState _state;
  final phrases = <String>[];
  bool retried = false;
  bool startedEmpty = false;

  @override
  AppState build() => _state;

  @override
  Future<String?> recoverWithPhrase(String phrase) async {
    phrases.add(phrase);
    return refusal;
  }

  @override
  Future<void> initialise() async => retried = true;

  @override
  Future<void> startEmpty() async => startedEmpty = true;
}
