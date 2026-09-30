import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/calc/sleep_score.dart';
import 'package:flutter_test/flutter_test.dart';

/// FitLog's own score for a night, from the parts it knows.
void main() {
  group('alleen de duur', () {
    test('acht uur of meer is alles', () {
      expect(sleepScore(asleep: const Duration(hours: 8)).value, 100);
      expect(sleepScore(asleep: const Duration(hours: 10)).value, 100);
    });

    test('vier uur of minder is niets', () {
      expect(sleepScore(asleep: const Duration(hours: 4)).value, 0);
      expect(sleepScore(asleep: const Duration(hours: 2)).value, 0);
    });

    test('en daartussen naar verhouding', () {
      expect(sleepScore(asleep: const Duration(hours: 7)).value, 75);
      expect(sleepScore(asleep: const Duration(hours: 6)).value, 50);
    });

    test('een deel dat de app niet kent, telt niet mee', () {
      final score = sleepScore(asleep: const Duration(hours: 7));

      expect(score.stages, isNull);
      expect(score.restoration, isNull);
    });
  });

  group('met de fasen', () {
    test('veel diepe en REM-slaap tilt een korte nacht op', () {
      // 6 uur: de helft voor de duur. 40% diep en REM: alles voor de fasen.
      final score = sleepScore(
        asleep: const Duration(hours: 6),
        deepMinutes: 72,
        remMinutes: 72,
      );

      expect(score.stages, 1);
      expect(score.value, ((0.5 * 50 + 1 * 25) / 75 * 100).round());
    });

    test('weinig ervan trekt een lange nacht omlaag', () {
      final score = sleepScore(
        asleep: const Duration(hours: 8),
        deepMinutes: 20,
        remMinutes: 30,
      );

      expect(score.stages, 0);
      expect(score.value, ((1 * 50 + 0 * 25) / 75 * 100).round());
    });

    test('alleen de ene fase is niet genoeg', () {
      expect(
        sleepScore(asleep: const Duration(hours: 7), deepMinutes: 90).stages,
        isNull,
      );
    });
  });

  group('met het herstel van die ochtend', () {
    test('een gewone ochtend is alles', () {
      final score = sleepScore(
        asleep: const Duration(hours: 8),
        hrvDrop: -0.05,
        restingHrRise: -1,
      );

      expect(score.restoration, 1);
      expect(score.value, 100);
    });

    test('de slechtste van de twee telt', () {
      final score = sleepScore(
        asleep: const Duration(hours: 8),
        hrvDrop: 0,
        restingHrRise: kRestingHrRiseFullEffect / 2,
      );

      expect(score.restoration, closeTo(0.5, 1e-9));
    });

    test('een HRV een kwart onder je gewone is niets', () {
      final score = sleepScore(
        asleep: const Duration(hours: 8),
        hrvDrop: kHrvDropFullEffect,
      );

      expect(score.restoration, 0);
      expect(score.value, ((50 + 0) / 75 * 100).round());
    });
  });

  group('de ochtend tegenover je gewone', () {
    final morning = DateTime(2026, 3, 10);

    List<VitalsDay> usual({int days = 14}) => [
      for (var d = 1; d <= days; d++)
        VitalsDay(day: DateTime(2026, 3, 10 - d), hrvMs: 50, restingHr: 55),
    ];

    test('vergelijkt die ochtend met de weken ervoor', () {
      final result = morningAgainstUsual(morning, [
        ...usual(),
        VitalsDay(day: morning, hrvMs: 40, restingHr: 60),
      ]);

      expect(result.hrvDrop, closeTo(0.2, 1e-9));
      expect(result.restingHrRise, closeTo(5, 1e-9));
    });

    test('zonder meting die ochtend: niets', () {
      final result = morningAgainstUsual(morning, usual());

      expect(result.hrvDrop, isNull);
      expect(result.restingHrRise, isNull);
    });

    test('en pas met een week aan metingen ervoor', () {
      final result = morningAgainstUsual(morning, [
        ...usual(days: kVitalsForBaseline - 1),
        VitalsDay(day: morning, hrvMs: 40),
      ]);

      expect(result.hrvDrop, isNull);
    });
  });
}
