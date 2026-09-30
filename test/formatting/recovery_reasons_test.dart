import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:fitlog/features/progress/presentation/recovery_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The line under a muscle on the recovery screen, for what came from a
/// watch.
void main() {
  setUpAll(initialiseTestLocale);

  final monday = DateTime(2026, 3, 2, 18);
  final thursday = DateTime(2026, 3, 5, 9);

  RecoveryEstimate estimate({
    double sleepFactor = 1,
    Duration? averageSleep,
    double vitalsFactor = 1,
    double? hrvDrop,
    double? restingHrRise,
    CardioSession? cardio,
  }) => RecoveryEstimate(
    muscle: 'quadriceps',
    workoutId: 'w1',
    trainedAt: monday,
    recovery: const Duration(hours: 80),
    loadRatio: 1,
    provisional: false,
    sleepFactor: sleepFactor,
    averageSleep: averageSleep,
    vitalsFactor: vitalsFactor,
    hrvDrop: hrvDrop,
    restingHrRise: restingHrRise,
    cardio: cardio,
  );

  test('een lage HRV en een hoge rusthartslag, zoals ze waren', () {
    final reasons = recoveryReasons(
      estimate(vitalsFactor: 1.15, hrvDrop: 0.2, restingHrRise: 6.4),
      now: thursday,
    );

    expect(reasons, contains('HRV 20% onder je gewone'));
    expect(reasons, contains('rusthartslag 6 slagen hoger'));
  });

  test('wat binnen de gewone schommeling bleef, wordt niet genoemd', () {
    final reasons = recoveryReasons(
      estimate(vitalsFactor: 1.15, hrvDrop: 0.2, restingHrRise: 1),
      now: thursday,
    );

    expect(reasons.where((r) => r.contains('rusthartslag')), isEmpty);
  });

  test('korte nachten en een slechte ochtend: alleen wat telde', () {
    // Ze tellen niet samen; het scherm noemt het grootste.
    final byWatch = recoveryReasons(
      estimate(
        sleepFactor: 1.12,
        averageSleep: const Duration(hours: 5),
        vitalsFactor: 1.2,
        hrvDrop: 0.3,
      ),
      now: thursday,
    );
    final bySleep = recoveryReasons(
      estimate(
        sleepFactor: 1.18,
        averageSleep: const Duration(hours: 4),
        vitalsFactor: 1.05,
        hrvDrop: 0.14,
      ),
      now: thursday,
    );

    expect(byWatch.where((r) => r.startsWith('korte nachten')), isEmpty);
    expect(byWatch, contains('HRV 30% onder je gewone'));
    expect(bySleep.where((r) => r.startsWith('korte nachten')), hasLength(1));
    expect(bySleep.where((r) => r.startsWith('HRV')), isEmpty);
  });

  test('een loop, met de dag en hoe lang', () {
    final wednesday = DateTime(2026, 3, 4, 20);
    final reasons = recoveryReasons(
      estimate(
        cardio: CardioSession(
          start: wednesday,
          end: wednesday.add(const Duration(minutes: 45)),
          kind: CardioKind.running,
        ),
      ),
      now: thursday,
    );

    expect(reasons, contains('je loop van woensdag (45 min)'));
  });

  test('en een rit van vandaag', () {
    final morning = DateTime(2026, 3, 5, 7);
    final reasons = recoveryReasons(
      estimate(
        cardio: CardioSession(
          start: morning,
          end: morning.add(const Duration(minutes: 70)),
          kind: CardioKind.cycling,
        ),
      ),
      now: thursday,
    );

    expect(reasons, contains('je fietstocht van vandaag (70 min)'));
  });
}
