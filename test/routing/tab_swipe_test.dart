import 'package:fitlog/routing/tab_swipe.dart';
import 'package:flutter_test/flutter_test.dart';

/// Swiping sideways between the four tabs.
///
/// Left-to-right is positive, so a swipe that moves you forward - right to
/// left, the way the photo apps do it - is negative.
void main() {
  const width = 400.0;

  int? swipe({
    int current = 1,
    double velocity = 0,
    double dragged = 0,
    int count = 4,
  }) => swipeTarget(
    current: current,
    count: count,
    velocity: velocity,
    dragged: dragged,
    width: width,
  );

  group('a flick', () {
    test('right to left moves forward', () {
      expect(swipe(velocity: -kSwipeVelocity, dragged: -20), 2);
    });

    test('left to right moves back', () {
      expect(swipe(velocity: kSwipeVelocity, dragged: 20), 0);
    });

    test('decides the direction even when the finger came back', () {
      // Thrown left and released near where it started: the throw is what you
      // meant, not where your finger happened to stop.
      expect(swipe(velocity: -600, dragged: 3), 2);
    });

    test('too gentle and too short does nothing', () {
      expect(swipe(velocity: -100, dragged: -30), isNull);
    });
  });

  group('a slow drag', () {
    test('across a quarter of the screen counts', () {
      expect(swipe(velocity: 0, dragged: -width * kSwipeFraction), 2);
    });

    test('just short of it does not', () {
      expect(swipe(velocity: 0, dragged: -width * kSwipeFraction + 1), isNull);
    });
  });

  group('the ends', () {
    test('there is nothing before the first tab', () {
      expect(swipe(current: 0, velocity: 600, dragged: 100), isNull);
    });

    test('and nothing after the last', () {
      expect(swipe(current: 3, velocity: -600, dragged: -100), isNull);
    });

    test('so it does not wrap around', () {
      expect(swipe(current: 3, velocity: -600, dragged: -100), isNot(0));
      expect(swipe(current: 0, velocity: 600, dragged: 100), isNot(3));
    });
  });

  test('a zero width falls back to the flick alone', () {
    // Nothing to measure a fraction of, so only the throw can decide.
    expect(
      swipeTarget(
        current: 1,
        count: 4,
        velocity: -600,
        dragged: -500,
        width: 0,
      ),
      2,
    );
    expect(
      swipeTarget(current: 1, count: 4, velocity: 0, dragged: -500, width: 0),
      isNull,
    );
  });
}
