/// Deciding where a sideways swipe over the tab shell lands.
///
/// Kept apart from the widget so the rules can be read and tested on their
/// own: the gesture itself is a few lines, the judgement about what counts as
/// a swipe is the part worth pinning down.
library;

/// A flick this fast counts on its own, however short it was.
///
/// Below it the swipe has to have covered real ground instead, so that a slow
/// deliberate drag works too and a twitch while scrolling does not.
const double kSwipeVelocity = 220;

/// How much of the screen a slow drag has to cross to count.
const double kSwipeFraction = 0.25;

/// The tab a swipe lands on, or null to stay where you are.
///
/// [dragged] and [velocity] are both measured left-to-right, so a swipe from
/// right to left - the one that moves you forward, the way the photo apps do
/// it - is negative. The ends do not wrap: there is nothing past the last tab,
/// and sliding off the edge into the first tab again would be a surprise.
int? swipeTarget({
  required int current,
  required int count,
  required double velocity,
  required double dragged,
  required double width,
}) {
  final fast = velocity.abs() >= kSwipeVelocity;
  final far = width > 0 && dragged.abs() >= width * kSwipeFraction;
  if (!fast && !far) return null;

  // A fast flick decides the direction even if the finger ended up back where
  // it started; otherwise the distance does.
  final forward = fast ? velocity < 0 : dragged < 0;
  final target = current + (forward ? 1 : -1);
  if (target < 0 || target >= count) return null;
  return target;
}
