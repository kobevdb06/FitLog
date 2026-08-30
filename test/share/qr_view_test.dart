import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fitlog/core/db/enums.dart';
import 'package:fitlog/features/share/domain/routine_code.dart';
import 'package:fitlog/features/share/presentation/qr_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';

import '../widget/helpers.dart';

/// The share screen showed an empty grey square where the code should be. The
/// encoder was fine all along, so the thing worth testing is that something is
/// actually painted - which is what nothing checked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  final key = GlobalKey();

  /// The share of pixels that came out dark, which is how you tell a QR code
  /// from an empty box without knowing what the code should look like.
  Future<double> darkFraction(WidgetTester tester) async {
    final boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;

    // Rasterising is real asynchronous work, which a widget test's fake clock
    // would otherwise never let finish.
    final fraction = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();

      var dark = 0;
      for (var i = 0; i < bytes.length; i += 4) {
        if (bytes[i] < 128 && bytes[i + 3] > 128) dark++;
      }
      return dark / (bytes.length / 4);
    });
    return fraction!;
  }

  Future<void> pumpCode(WidgetTester tester, String data) async {
    await tester.pumpWidget(
      wrapForTest(
        Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: Colors.white,
              child: QrView(data: data, size: 200),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a code is drawn, not an empty square', (tester) async {
    await pumpCode(tester, 'FITLOG-TEST-PAYLOAD-0123456789');

    final dark = await darkFraction(tester);
    expect(dark, greaterThan(0.15), reason: 'nothing was painted');
    expect(dark, lessThan(0.75), reason: 'it painted a solid block');
  });

  testWidgets('a real routine payload draws too', (tester) async {
    final routine = SharedRoutine(
      name: 'Chest day',
      exercises: [
        for (var i = 0; i < 8; i++)
          SharedExercise(
            id: i < 3 ? null : 'cat-$i',
            name: 'Incline Dumbbell Bench Press $i',
            primaryMuscle: 'borst',
            secondaryMuscles: const ['triceps'],
            category: ExerciseCategory.dumbbell,
            restSeconds: 120,
            sets: const [SharedSet(reps: 10), SharedSet(reps: 8)],
          ),
      ],
    );

    await pumpCode(tester, base64Url.encode(encodeRoutine(routine)));

    expect(await darkFraction(tester), greaterThan(0.15));
  });

  testWidgets('two different payloads draw two different codes', (
    tester,
  ) async {
    await pumpCode(tester, 'AAAAAAAAAAAAAAAAAAAAAAAA');
    final first = await darkFraction(tester);

    await pumpCode(tester, 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB');
    expect(await darkFraction(tester), isNot(first));
  });

  testWidgets('too much to encode says so instead of drawing nothing', (
    tester,
  ) async {
    // Past what any QR code holds at any version.
    await pumpCode(tester, 'x' * 5000);

    expect(find.textContaining('te groot'), findsOneWidget);
  });

  group('the payload a routine becomes', () {
    test('fits in a code that is not absurdly dense', () {
      final routine = SharedRoutine(
        name: 'Chest day',
        exercises: [
          for (var i = 0; i < 8; i++)
            SharedExercise(
              id: i < 3 ? null : 'cat-$i',
              name: 'Incline Dumbbell Bench Press $i',
              primaryMuscle: 'borst',
              category: ExerciseCategory.dumbbell,
              sets: const [SharedSet(reps: 10), SharedSet(reps: 8)],
            ),
        ],
      );

      final qr = QrCode(
        payload: QrPayload.fromString(
          base64Url.encode(encodeRoutine(routine)),
        ),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      );

      // Version 25 is about as dense as a phone camera reads off a screen
      // without a fight.
      expect(qr.typeNumber, lessThanOrEqualTo(25));
    });
  });
}
