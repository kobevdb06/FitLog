import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/routing/router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The screen you land on when the database will not open.
///
/// A database the key does not fit never opens, however often you ask. The
/// screen offered only "Opnieuw proberen", so an app in that state was stuck
/// there for good and reinstalling was the only way out - which throws
/// everything away anyway, only without saying so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  Future<void> pump(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(
      wrapForTest(
        const StartupFailureScreen(),
        overrides: [appControllerProvider.overrideWith(() => _Stuck(state))],
      ),
    );
    await tester.pump();
  }

  testWidgets('says what went wrong and offers to try again', (tester) async {
    await pump(tester, const AppFailed('WrongDatabaseKeyException'));

    expect(find.text('FitLog kan niet starten'), findsOneWidget);
    expect(find.text('WrongDatabaseKeyException'), findsOneWidget);
    expect(find.text('Opnieuw proberen'), findsOneWidget);
  });

  testWidgets('and offers a way out that is not reinstalling', (tester) async {
    await pump(tester, const AppFailed('WrongDatabaseKeyException'));

    expect(find.text('Opnieuw beginnen'), findsOneWidget);
  });

  testWidgets('which asks twice before it wipes anything', (tester) async {
    await pump(tester, const AppFailed('WrongDatabaseKeyException'));

    await tester.tap(find.text('Opnieuw beginnen'));
    await tester.pumpAndSettle();

    expect(find.text('Opnieuw beginnen?'), findsOneWidget);
    await tester.tap(find.text('Doorgaan'));
    await tester.pumpAndSettle();

    // The second one wants the word typed out, the same as wiping from the
    // settings.
    expect(find.text('Zeker weten?'), findsOneWidget);
    expect(find.textContaining('WISSEN'), findsWidgets);
  });

  testWidgets('and the way out is there even when retrying is not', (
    tester,
  ) async {
    await pump(tester, const AppFailed('Onherstelbaar', canRetry: false));

    expect(find.text('Opnieuw proberen'), findsNothing);
    expect(find.text('Opnieuw beginnen'), findsOneWidget);
  });
}

/// An app controller that is simply stuck in one state.
class _Stuck extends AppController {
  _Stuck(this._state);

  final AppState _state;

  @override
  AppState build() => _state;
}
