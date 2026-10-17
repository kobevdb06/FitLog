import 'dart:async';

import 'package:fitlog/features/workout/panel/panel_bridge.dart';
import 'package:fitlog/features/workout/panel/workout_panel_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Coach in the workout notification: a question about the set, over the app
/// you are in, behind the PIN when there is one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  Future<_Bridge> pump(WidgetTester tester, _Bridge bridge) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(1.4),
        ),
        child: WorkoutPanelApp(bridge: bridge),
      ),
    );
    await tester.pumpAndSettle();
    return bridge;
  }

  Map<String, Object?> coach({bool available = true, bool locked = false}) => {
    'available': available,
    'locked': locked,
    'biometric': false,
    'lockoutSeconds': 0,
    'about': 'Bench Press · Set 3 van 4 · 80 kg × 8',
    'thread': const <Object?>[],
  };

  testWidgets('zonder sleutel wijst het naar het aanzetten', (tester) async {
    final bridge = await pump(tester, _Bridge(coach(available: false)));

    expect(find.textContaining('De coach staat uit'), findsOneWidget);
    await tester.tap(find.text('Coach aanzetten'));
    await tester.pump();

    expect(bridge.opened, ['/coach/sleutel']);
  });

  testWidgets('met een pincode eerst die, dan de vragen', (tester) async {
    final bridge = await pump(tester, _Bridge(coach(locked: true)));

    expect(find.text('Je pincode, om de coach te openen.'), findsOneWidget);
    expect(find.text('Mag ik zwaarder?'), findsNothing);
    expect(tester.takeException(), isNull);

    for (final digit in '246810'.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(bridge.calls, contains('coachUnlock'));
    expect(bridge.arguments['coachUnlock'], {'pin': '246810'});
    expect(find.text('Mag ik zwaarder?'), findsOneWidget);
  });

  testWidgets('een vraag, en het antwoord terwijl het geschreven wordt', (
    tester,
  ) async {
    final bridge = await pump(tester, _Bridge(coach()));

    expect(find.text('Bench Press · Set 3 van 4 · 80 kg × 8'), findsOneWidget);
    await tester.tap(find.text('Mag ik zwaarder?'));
    await tester.pump();

    expect(bridge.arguments['coachAsk'], {'question': 'Mag ik zwaarder?'});
    expect(find.text('De coach denkt na…'), findsOneWidget);

    bridge.event({'type': 'writing', 'text': 'Ja, probeer', 'looking': null});
    await tester.pump();
    expect(find.text('Ja, probeer'), findsOneWidget);

    bridge.event({
      'type': 'done',
      'text': 'Ja, probeer 82,5 kg.',
      'lookups': ['je laatste 3 sessies'],
    });
    await tester.pump();

    expect(find.text('Ja, probeer 82,5 kg.'), findsOneWidget);
    expect(find.text('Bekeken: je laatste 3 sessies'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('een lege vraag gaat niet weg', (tester) async {
    final bridge = await pump(tester, _Bridge(coach()));

    await tester.tap(find.byTooltip('Versturen'));
    await tester.pump();

    expect(find.text('Typ eerst een vraag'), findsOneWidget);
    expect(bridge.calls, isNot(contains('coachAsk')));
  });

  testWidgets('verder in FitLog opent de chat', (tester) async {
    final bridge = await pump(tester, _Bridge(coach()));

    await tester.tap(find.text('Verder in FitLog'));
    await tester.pump();

    expect(bridge.opened, ['/chat']);
  });
}

class _Bridge implements PanelBridge {
  _Bridge(this.coach);

  final Map<String, Object?> coach;
  final calls = <String>[];
  final arguments = <String, Map<String, Object?>?>{};
  final opened = <String>[];
  final _events = StreamController<Map<Object?, Object?>>.broadcast();

  void event(Map<Object?, Object?> event) => _events.add(event);

  @override
  Future<String> mode() async => 'coach';

  @override
  Future<Map<Object?, Object?>> relay(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    calls.add(method);
    arguments[method] = args;
    return switch (method) {
      'coachState' => coach,
      'coachUnlock' => {'ok': true},
      'coachAsk' => Completer<Map<Object?, Object?>>().future,
      _ => {'title': 'Push A', 'unit': 'kg', 'set': null},
    };
  }

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> openApp(String route) async => opened.add(route);

  @override
  Stream<String> get modes => const Stream.empty();

  @override
  Stream<Map<Object?, Object?>> get events => _events.stream;
}
