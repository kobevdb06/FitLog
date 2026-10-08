import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/settings/data/app_icon.dart';
import 'package:fitlog/features/settings/presentation/app_icon_providers.dart';
import 'package:fitlog/features/settings/presentation/display_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Android, as far as the icon goes.
class _Switcher implements AppIconSwitcher {
  AppIcon icon = AppIcon.dark;
  final used = <AppIcon>[];

  @override
  Future<AppIcon> current() async => icon;

  @override
  Future<void> use(AppIcon next) async {
    used.add(next);
    icon = next;
  }
}

/// The icon on the home screen, chosen under Weergave en eenheden apart
/// from the theme.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late _Switcher switcher;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    switcher = _Switcher();
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppIconSwitcher? using,
  }) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        appIconSwitcherProvider.overrideWithValue(using),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      wrapWithContainer(container, const DisplaySettingsScreen()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // Built when used: a semantics finder needs semantics switched on.
  Finder dark() => find.bySemanticsLabel('App-icoon donker');
  Finder light() => find.bySemanticsLabel('App-icoon licht');

  testWidgets('beide iconen, en het huidige gekozen', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, using: switcher);

    expect(find.text('App-icoon'), findsOneWidget);
    expect(tester.getSemantics(dark()), isSemantics(isSelected: true));
    expect(tester.getSemantics(light()), isSemantics(isSelected: false));
    semantics.dispose();
  });

  testWidgets('wisselen vraagt het eerst, en wisselt dan', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, using: switcher);

    await tester.tap(light());
    await tester.pumpAndSettle();
    expect(find.text('App-icoon wisselen?'), findsOneWidget);
    expect(
      find.textContaining('FitLog start daarbij opnieuw op'),
      findsOneWidget,
    );
    expect(switcher.used, isEmpty, reason: 'nothing before the yes');

    await tester.tap(find.text('Wisselen'));
    await tester.pumpAndSettle();

    expect(switcher.used, [AppIcon.light]);
    expect(tester.getSemantics(light()), isSemantics(isSelected: true));
    semantics.dispose();
  });

  testWidgets('annuleren laat het icoon staan', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, using: switcher);

    await tester.tap(light());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();

    expect(switcher.used, isEmpty);
    expect(tester.getSemantics(dark()), isSemantics(isSelected: true));
    semantics.dispose();
  });

  testWidgets('het icoon dat er al staat, vraagt niets', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, using: switcher);

    await tester.tap(dark());
    await tester.pumpAndSettle();

    expect(find.text('App-icoon wisselen?'), findsNothing);
    expect(switcher.used, isEmpty);
    semantics.dispose();
  });

  testWidgets('waar niets te wisselen valt, staat de keuze er niet', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('App-icoon'), findsNothing);
    expect(find.text('Thema'), findsOneWidget);
  });
}
