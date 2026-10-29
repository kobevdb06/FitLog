import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/links.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/settings/presentation/about_screen.dart';
import 'package:fitlog/features/settings/presentation/feedback_providers.dart';
import 'package:fitlog/features/settings/presentation/settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// What a tester needs from the app: a way to tell the maker something, and a
/// way to find out whether there is a newer version.
///
/// Neither makes a connection. One hands a filled-in e-mail to the mail app,
/// to send or not; the other opens the download page in the browser.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {LinkOpener? opener}) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        linkOpenerProvider.overrideWithValue(opener),
        phoneDescriptionProvider.overrideWith(
          (ref) async => 'Google Pixel 7 · Android 15',
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      wrapWithContainer(container, const SettingsScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('iets melden', () {
    testWidgets('opent een e-mail met je versie en je toestel erin', (
      tester,
    ) async {
      final opener = _Opener();
      await pump(tester, opener: opener);

      await tapText(tester, 'Iets melden');

      final mail = Uri.parse(opener.instead.single);
      expect(mail.scheme, 'mailto');
      expect(mail.path, 'kobe.vandenberk@gmail.com');
      final query = Uri.splitQueryString(mail.query);
      expect(query['subject'], 'FitLog ${AboutScreen.appVersion}: iets gemeld');
      expect(query['body'], contains('Wat gebeurde er?'));
      expect(query['body'], contains('FitLog ${AboutScreen.appVersion}'));
      expect(query['body'], contains('Google Pixel 7 · Android 15'));
    });

    testWidgets('zonder e-mailapp staat de tekst op je klembord', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester, opener: _Opener(opens: false));

      await tapText(tester, 'Iets melden');

      expect(copied, contains('iets gemeld'));
      expect(copied, contains('Google Pixel 7 · Android 15'));
      expect(find.textContaining('op je klembord'), findsOneWidget);
      expect(find.textContaining('kobe.vandenberk@gmail.com'), findsOneWidget);
    });
  });

  group('nieuwe versie zoeken', () {
    testWidgets('zegt welke versie je hebt, en opent de downloadpagina', (
      tester,
    ) async {
      final opener = _Opener();
      await pump(tester, opener: opener);

      expect(
        find.textContaining('Je hebt ${AboutScreen.appVersion}'),
        findsOneWidget,
      );
      await tapText(tester, 'Nieuwe versie zoeken');

      // In the browser, not over the app: that is where the download lands.
      expect(opener.instead, [kSiteUrl]);
      expect(opener.over, isEmpty);
    });
  });

  testWidgets('zonder iets om ze te openen, geen van beide', (tester) async {
    await pump(tester);

    expect(find.text('Iets melden'), findsNothing);
    expect(find.text('Nieuwe versie zoeken'), findsNothing);
    expect(find.text('Over FitLog'), findsOneWidget);
  });
}

class _Opener implements LinkOpener {
  _Opener({this.opens = true});

  final bool opens;
  final over = <String>[];
  final instead = <String>[];

  @override
  Future<bool> open(String url) async {
    instead.add(url);
    return opens;
  }

  @override
  Future<bool> openOver(String url) async {
    over.add(url);
    return opens;
  }
}
