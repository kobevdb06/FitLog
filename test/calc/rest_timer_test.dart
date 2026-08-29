import 'package:fitlog/features/workout/domain/rest_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 8, 26, 18, 0, 0);

  group('idle', () {
    test('is not active and has nothing left', () {
      const state = RestTimerState.idle();
      expect(state.isActive, isFalse);
      expect(state.remainingSeconds(at), 0);
      expect(state.progress(at), 0);
      expect(state.hasElapsed(at), isFalse);
    });
  });

  group('start', () {
    test('sets the end timestamp from the start moment', () {
      final state = RestTimerState.start(
        seconds: 90,
        from: at,
        exerciseName: 'Bench Press',
      );
      expect(state.isActive, isTrue);
      expect(state.endsAt, at.add(const Duration(seconds: 90)));
      expect(state.totalSeconds, 90);
      expect(state.exerciseName, 'Bench Press');
      expect(state.finishedHandled, isFalse);
    });

    test('counts down against the clock, not a ticker', () {
      final state = RestTimerState.start(seconds: 90, from: at);
      expect(state.remainingSeconds(at), 90);
      expect(state.remainingSeconds(at.add(const Duration(seconds: 30))), 60);
      expect(state.remainingSeconds(at.add(const Duration(seconds: 89))), 1);
    });

    test('a long trip to the background just runs it out', () {
      final state = RestTimerState.start(seconds: 90, from: at);
      final later = at.add(const Duration(minutes: 30));
      expect(state.remainingSeconds(later), 0);
      expect(state.hasElapsed(later), isTrue);
      expect(state.progress(later), 1);
    });

    test('progress runs from zero to one', () {
      final state = RestTimerState.start(seconds: 100, from: at);
      expect(state.progress(at), 0);
      expect(
        state.progress(at.add(const Duration(seconds: 50))),
        closeTo(0.5, 0.02),
      );
      expect(state.progress(at.add(const Duration(seconds: 100))), 1);
    });
  });

  group('adjust', () {
    test('adds time', () {
      final state = RestTimerState.start(
        seconds: 60,
        from: at,
      ).adjust(15, now: at);
      expect(state.remainingSeconds(at), 75);
      expect(state.totalSeconds, 75);
    });

    test('removes time', () {
      final state = RestTimerState.start(
        seconds: 60,
        from: at,
      ).adjust(-15, now: at);
      expect(state.remainingSeconds(at), 45);
    });

    test('never goes below the current moment', () {
      final state = RestTimerState.start(
        seconds: 10,
        from: at,
      ).adjust(-60, now: at);
      expect(state.remainingSeconds(at), 0);
    });

    test('adjusting an idle timer does nothing', () {
      const state = RestTimerState.idle();
      expect(state.adjust(15, now: at).isActive, isFalse);
    });
  });

  group('finishedHandled', () {
    test('flips once so the sound only plays a single time', () {
      final state = RestTimerState.start(seconds: 10, from: at);
      expect(state.finishedHandled, isFalse);
      expect(state.copyWith(finishedHandled: true).finishedHandled, isTrue);
    });
  });
}
