import 'package:drift/native.dart';
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Shared setup for the widget tests: a real drift database on an unencrypted
/// in-memory connection (the encryption itself is covered by
/// `test/db/encryption_test.dart`) and the same theme and locale the app uses.
Future<void> initialiseTestLocale() async {
  Intl.defaultLocale = 'nl';
  await initializeDateFormatting('nl');
}

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

/// The MaterialApp the screens expect, without a ProviderScope of its own.
Widget appFrame(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    locale: const Locale('nl'),
    supportedLocales: const [Locale('nl')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

/// Wraps [child] in a single ProviderScope plus the MaterialApp.
///
/// Nesting two scopes would give the widget under test a different container
/// than the test holds, so there is exactly one here.
Widget wrapForTest(
  Widget child, {
  AppDatabase? database,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      if (database != null) databaseProvider.overrideWithValue(database),
      ...overrides,
    ],
    child: appFrame(child),
  );
}

/// Same as [wrapForTest], but driven by a container the test owns so it can
/// read providers directly.
Widget wrapWithContainer(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: appFrame(child),
  );
}
