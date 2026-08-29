import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/security/biometric_service.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/lock/presentation/pin_pad.dart';
import 'package:fitlog/features/onboarding/presentation/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A device without biometrics, so the flow is deterministic.
class _NoBiometrics implements BiometricService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<Never>> availableTypes() async => const [];

  @override
  Future<bool> authenticate({String reason = ''}) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late InMemorySecretStore store;

  setUp(() => store = InMemorySecretStore());

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secretStoreProvider.overrideWithValue(store),
          biometricServiceProvider.overrideWithValue(_NoBiometrics()),
        ],
        child: wrapForTest(const OnboardingFlow()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(
        find.descendant(
          of: find.byType(PinPad),
          matching: find.text(digit),
        ),
      );
      await tester.pump();
    }
  }

  testWidgets('the welcome screen states that nothing leaves the device', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.text('Log je krachttraining.'), findsOneWidget);
    expect(
      find.textContaining('blijven op dit toestel'),
      findsOneWidget,
    );
    expect(find.text('Beginnen'), findsOneWidget);
  });

  testWidgets('the PIN is preselected on the security step', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Beginnen'));
    await tester.pumpAndSettle();

    expect(find.text('Pincode instellen'), findsWidgets);
    expect(find.text('Overslaan'), findsOneWidget);
    // The recommended option is the one that is already ticked.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('entering six digits moves on to the confirmation step', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Beginnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doorgaan'));
    await tester.pumpAndSettle();

    expect(find.text('Kies een pincode van zes cijfers'), findsOneWidget);

    await tapPin(tester, '123456');
    await tester.pumpAndSettle();

    expect(find.text('Typ dezelfde pincode nog eens'), findsOneWidget);
  });

  testWidgets('two different PINs are refused and the flow starts over', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Beginnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doorgaan'));
    await tester.pumpAndSettle();

    await tapPin(tester, '123456');
    await tester.pumpAndSettle();
    await tapPin(tester, '654321');
    await tester.pumpAndSettle();

    expect(find.text('Kies een pincode van zes cijfers'), findsOneWidget);
    expect(
      find.text('De pincodes zijn niet gelijk. Probeer opnieuw.'),
      findsOneWidget,
    );
  });

  testWidgets('a matching PIN leads to the twelve recovery words', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Beginnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doorgaan'));
    await tester.pumpAndSettle();

    await tapPin(tester, '123456');
    await tester.pumpAndSettle();
    await tapPin(tester, '123456');
    await tester.pumpAndSettle();

    expect(find.text('Schrijf deze twaalf woorden op papier.'), findsOneWidget);
    expect(
      find.textContaining('Wij kunnen ze niet voor je opzoeken'),
      findsOneWidget,
    );
    expect(find.text('Ik heb ze opgeschreven'), findsOneWidget);

    // Twelve numbered slots.
    for (var i = 1; i <= 12; i++) {
      expect(find.text('$i'), findsWidgets, reason: 'woord $i');
    }
  });

  testWidgets('skipping the PIN still hands over a recovery phrase', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Beginnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overslaan'));
    await tester.pump();
    await tester.tap(find.text('Doorgaan'));
    await tester.pumpAndSettle();

    expect(find.text('Schrijf deze twaalf woorden op papier.'), findsOneWidget);
  });

  testWidgets('nothing is written to the key store before the flow finishes', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Beginnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doorgaan'));
    await tester.pumpAndSettle();
    await tapPin(tester, '123456');
    await tester.pumpAndSettle();
    await tapPin(tester, '123456');
    await tester.pumpAndSettle();

    expect(store.values, isEmpty);
    expect(await KeyManager(store).status().then((s) => s.initialised), isFalse);
  });
}
