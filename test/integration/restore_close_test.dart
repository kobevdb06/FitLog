import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Restoring a backup sat on "Database sluiten" and never moved.
///
/// The order was the problem: the connection was closed while the whole app
/// was still watching it through `databaseProvider`. These pin down the order
/// and the promise that it cannot wait forever either way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  test('the state is dropped before the connection is closed', () async {
    // Everything that reads the database goes through databaseProvider, and
    // that throws the moment the state is no longer AppReady. Watching the
    // state tells us the listeners were let go first.
    final source = File(
      'lib/core/app/app_controller.dart',
    ).readAsStringSync();
    final body = source.substring(
      source.indexOf('Future<void> closeForRestore()'),
      source.indexOf('/// The open database, or null while locked'),
    );

    final stateAt = body.indexOf('state = const AppLoading()');
    final closeAt = body.indexOf('db.close()');

    expect(stateAt, isNonNegative);
    expect(closeAt, isNonNegative);
    expect(
      stateAt,
      lessThan(closeAt),
      reason: 'closing while the app still watches is what hung the restore',
    );
  });

  test('the close cannot wait forever', () async {
    final source = File(
      'lib/core/app/app_controller.dart',
    ).readAsStringSync();

    expect(source, contains('kCloseForRestoreTimeout'));
    expect(kCloseForRestoreTimeout.inSeconds, inInclusiveRange(5, 60));
  });

  test('closing lets go of the database and the key', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appControllerProvider.notifier);
    await controller.closeForRestore().timeout(
      const Duration(seconds: 30),
      onTimeout: () => fail('closeForRestore bleef zelf hangen'),
    );

    expect(container.read(appControllerProvider), isA<AppLoading>());
    expect(controller.databaseOrNull, isNull);
    expect(controller.currentDek, isNull);
    expect(
      () => container.read(databaseProvider),
      throwsA(anything),
      reason: 'nothing may reach the database while it is being replaced',
    );
  });
}
