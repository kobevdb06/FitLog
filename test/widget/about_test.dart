import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/links.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/settings/presentation/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Over FitLog: what the app sends, and the way to the whole of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    LinkOpener? opener,
  }) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        linkOpenerProvider.overrideWithValue(opener),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(wrapWithContainer(container, const AboutScreen()));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('de privacyverklaring opent over de app', (tester) async {
    final opener = _Opener();
    await pump(tester, opener: opener);

    final button = find.text('Privacyverklaring');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(opener.over, [kPrivacyUrl]);
    expect(opener.instead, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zonder iets om ze te openen, geen knop', (tester) async {
    await pump(tester);

    expect(find.text('Privacyverklaring'), findsNothing);
  });

  testWidgets('en zegt niet meer dat er geen internet is', (tester) async {
    await pump(tester);

    expect(find.textContaining('Zonder INTERNET'), findsNothing);
    expect(find.textContaining('Het scannen zelf'), findsOneWidget);
  });
}

class _Opener implements LinkOpener {
  final over = <String>[];
  final instead = <String>[];

  @override
  Future<bool> open(String url) async {
    instead.add(url);
    return true;
  }

  @override
  Future<bool> openOver(String url) async {
    over.add(url);
    return true;
  }
}
