import 'package:fitlog/routing/tab_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Swiping between the tabs.
///
/// Driven through a real [StatefulShellRoute] with four throwaway tabs, so the
/// pager is tested where it actually lives: between go_router's branch
/// navigators.
void main() {
  /// A tab that counts how often it is built, so losing its state shows up.
  Widget tab(String name, GlobalKey<_CounterState> key) =>
      Scaffold(body: _Counter(key: key, name: name));

  late GlobalKey<_CounterState> firstKey;
  late GlobalKey<_CounterState> secondKey;
  late GoRouter router;

  setUp(() {
    _CounterState.starts.clear();
    firstKey = GlobalKey<_CounterState>();
    secondKey = GlobalKey<_CounterState>();
    router = GoRouter(
      initialLocation: '/een',
      routes: [
        StatefulShellRoute(
          builder: (context, state, shell) => Scaffold(body: shell),
          navigatorContainerBuilder: (context, shell, children) =>
              TabPager(shell: shell, branches: children),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/een',
                  builder: (context, state) => tab('Een', firstKey),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/twee',
                  builder: (context, state) => tab('Twee', secondKey),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/drie',
                  builder: (context, state) =>
                      Scaffold(body: _Counter(name: 'Drie')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/vier',
                  builder: (context, state) =>
                      Scaffold(body: _Counter(name: 'Vier')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  /// A flick from right to left, the way you move forward.
  Future<void> swipeForward(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
  }

  Future<void> swipeBack(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
  }

  testWidgets('the tabs lie side by side in a pager', (tester) async {
    await pump(tester);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Een'), findsOneWidget);
  });

  testWidgets('swiping moves to the next tab and tells the router', (
    tester,
  ) async {
    await pump(tester);

    await swipeForward(tester);

    expect(find.text('Twee'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/twee',
      reason: 'de route volgt de pagina, niet alleen het beeld',
    );
  });

  testWidgets('swiping the other way goes back', (tester) async {
    await pump(tester);
    await swipeForward(tester);
    await swipeBack(tester);

    expect(find.text('Een'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/een');
  });

  testWidgets('there is nothing before the first tab', (tester) async {
    await pump(tester);

    await swipeBack(tester);

    expect(find.text('Een'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/een');
  });

  testWidgets('and nothing after the last, so it does not wrap', (
    tester,
  ) async {
    await pump(tester);
    for (var i = 0; i < 5; i++) {
      await swipeForward(tester);
    }

    expect(find.text('Vier'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/vier');
  });

  testWidgets('a tab keeps its state while you are away', (tester) async {
    await pump(tester);

    firstKey.currentState!.bump();
    await tester.pump();
    expect(find.text('Een 1'), findsOneWidget);

    // All the way to the far end, well outside what a pager keeps in hand
    // by itself, and back again.
    router.go('/vier');
    await tester.pumpAndSettle();
    router.go('/een');
    await tester.pumpAndSettle();

    // The counter is still where it was: the tab was kept alive rather than
    // thrown away and rebuilt.
    expect(find.text('Een 1'), findsOneWidget);
    expect(
      _CounterState.starts['Een'],
      1,
      reason: 'het tabblad is nooit opnieuw opgebouwd',
    );
  });

  testWidgets('a tab you are not looking at is let go of', (tester) async {
    await pump(tester);
    expect(find.text('Een'), findsOneWidget);

    await swipeForward(tester);

    // Not merely hidden: gone. That is what keeps four tabs from animating at
    // once behind your back, and it is why the state test above matters.
    expect(find.text('Een'), findsNothing);
    expect(find.text('Vier'), findsNothing, reason: 'nooit bezocht');
  });

  testWidgets('going to a tab from elsewhere brings the page along', (
    tester,
  ) async {
    await pump(tester);

    router.go('/drie');
    await tester.pumpAndSettle();

    expect(find.text('Drie'), findsOneWidget);

    // And swiping carries on from there rather than from where it was.
    await swipeBack(tester);
    expect(find.text('Twee'), findsOneWidget);
  });

  testWidgets('what scrolls sideways itself keeps the gesture', (tester) async {
    await pump(tester);

    final controller = secondKey;
    router.go('/twee');
    await tester.pumpAndSettle();
    expect(controller.currentState, isNotNull);

    // The row inside the tab scrolls; the pager stays where it is.
    await tester.fling(find.byType(ListView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Twee'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/twee');
  });
}

/// A tab with something to lose: a number, and a row that scrolls sideways.
class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.name});

  final String name;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  /// How often a tab has been started from scratch, per name.
  static final Map<String, int> starts = {};

  int _count = 0;

  @override
  void initState() {
    super.initState();
    starts[widget.name] = (starts[widget.name] ?? 0) + 1;
  }

  void bump() => setState(() => _count++);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(_count == 0 ? widget.name : '${widget.name} $_count'),
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(width: 80, child: Center(child: Text('chip $i'))),
            ],
          ),
        ),
      ],
    );
  }
}
