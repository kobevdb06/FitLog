import 'dart:async';

import 'package:fitlog/features/workout/panel/panel_bridge.dart';
import 'package:fitlog/features/workout/panel/workout_panel_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The panel over another app: it shows what the running app sends and
/// writes nothing itself - every change is a question to the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  Map<String, Object?> bench({
    String id = 's3',
    String label = 'Set 3 van 4',
    double? weightKg = 80,
    int? reps = 8,
    List<String> marks = const ['done', 'done', 'open', 'open'],
    int position = 2,
  }) => {
    'id': id,
    'exercise': 'Bench Press',
    'label': label,
    'marks': marks,
    'position': position,
    'weightKg': weightKg,
    'reps': reps,
    'durationSeconds': null,
    'hasWeight': true,
    'hasReps': true,
    'hasDuration': false,
    'stepKg': 2.5,
    'outside': true,
  };

  Future<_Bridge> pump(
    WidgetTester tester,
    _Bridge bridge, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: WorkoutPanelApp(bridge: bridge),
      ),
    );
    await tester.pumpAndSettle();
    return bridge;
  }

  testWidgets('toont de set, en past ze aan met min en plus', (tester) async {
    final bridge = await pump(
      tester,
      _Bridge(state: {'title': 'Push A', 'unit': 'kg', 'set': bench()}),
      textScale: 1.4,
    );

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Set 3 van 4'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Meer gewicht'));
    await tester.tap(find.byTooltip('Minder herhalingen'));
    await tester.tap(find.byTooltip('Minder herhalingen'));
    await tester.pump();

    expect(find.text('82,5 kg'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(bridge.calls, ['state'], reason: 'nothing is written yet');
  });

  testWidgets('afvinken stuurt wat er staat, toont het vinkje en dan de '
      'volgende set', (tester) async {
    final bridge = _Bridge(
      state: {'title': 'Push A', 'unit': 'kg', 'set': bench()},
      answer: {
        'ok': true,
        'title': 'Push A',
        'unit': 'kg',
        'set': bench(
          id: 's4',
          label: 'Set 4 van 4',
          marks: const ['done', 'done', 'done', 'open'],
          position: 3,
        ),
      },
    );
    await pump(tester, bridge);

    await tester.tap(find.byTooltip('Meer gewicht'));
    await tester.pump();
    await tester.tap(find.text('Afvinken'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Set 3 van 4 afgevinkt'), findsOneWidget);
    expect(bridge.calls.last, 'complete');
    expect(bridge.arguments.last, {'setId': 's3', 'weightKg': 82.5, 'reps': 8});

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Set 4 van 4'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
  });

  testWidgets('in pond, en terug in kilo naar de app', (tester) async {
    final bridge = await pump(
      tester,
      _Bridge(state: {'title': 'Push A', 'unit': 'lb', 'set': bench()}),
    );

    expect(find.text('176,5 lb'), findsOneWidget);
    await tester.tap(find.byTooltip('Meer gewicht'));
    await tester.pump();
    expect(find.text('181,5 lb'), findsOneWidget);

    await tester.tap(find.text('Sluiten'));
    await tester.pump();

    expect(bridge.calls, ['state', 'update', 'close']);
    expect(
      bridge.arguments[1]['weightKg'] as double,
      closeTo(181.5 / 2.20462, 0.01),
    );
  });

  testWidgets('sluiten zonder iets te veranderen schrijft niets', (
    tester,
  ) async {
    final bridge = await pump(
      tester,
      _Bridge(state: {'title': 'Push A', 'unit': 'kg', 'set': bench()}),
    );

    await tester.tap(find.text('Sluiten'));
    await tester.pump();

    expect(bridge.calls, ['state', 'close']);
  });

  testWidgets('met de app weg zegt het dat, en opent ze', (tester) async {
    final bridge = await pump(tester, _Bridge(state: {'closed': true}));

    expect(find.text('FitLog is gesloten'), findsOneWidget);
    await tester.tap(find.text('Open FitLog'));
    await tester.pump();

    expect(bridge.opened, ['/workout']);
  });
}

class _Bridge implements PanelBridge {
  _Bridge({required this.state, this.answer});

  final Map<String, Object?> state;
  final Map<String, Object?>? answer;
  final calls = <String>[];
  final arguments = <Map<String, Object?>>[];
  final opened = <String>[];

  @override
  Future<String> mode() async => 'edit';

  @override
  Future<Map<Object?, Object?>> relay(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    calls.add(method);
    arguments.add(args ?? const {});
    return method == 'state' ? state : answer ?? state;
  }

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> openApp(String route) async => opened.add(route);

  @override
  Stream<String> get modes => const Stream.empty();

  @override
  Stream<Map<Object?, Object?>> get events => const Stream.empty();
}
