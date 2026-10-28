import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/formatting/formatters.dart';
import 'package:fitlog/features/progress/presentation/recovery_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A muscle's name, where it stands on its own: with a capital, as the check
/// and Lichaamsmetingen write it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  test('een naam op zich krijgt een hoofdletter', () {
    expect(Formatters.muscle('buik'), 'Buik');
    expect(Formatters.muscle('quadriceps'), 'Quadriceps');
    expect(Formatters.muscle(''), '');
  });

  testWidgets('ook in de herstelregel op Start en Herstel', (tester) async {
    final now = DateTime(2026, 10, 28, 12);
    await tester.pumpWidget(
      appFrame(
        Scaffold(
          body: RecoveryRow(
            now: now,
            estimate: RecoveryEstimate(
              muscle: 'buik',
              workoutId: 'w',
              trainedAt: now.subtract(const Duration(hours: 10)),
              recovery: const Duration(hours: 48),
              loadRatio: 1,
              provisional: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Buik'), findsOneWidget);
    expect(find.text('buik'), findsNothing);
  });
}
