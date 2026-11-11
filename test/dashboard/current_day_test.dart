import 'package:fitlog/core/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The day the screens count from, turned over at four in the morning
/// (DECISIONS 282).
///
/// "Now" was read once, when a provider was built. Left open on Sunday
/// evening, the card on Monday morning still said "week klaar" and showed
/// last week's numbers.
void main() {
  test('the training day turns at four, and only then', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final day = container.read(currentDayProvider.notifier);
    final seen = <DateTime>[];
    container.listen(currentDayProvider, (_, next) => seen.add(next));

    day.refresh(DateTime(2026, 10, 18, 22));
    expect(container.read(currentDayProvider), DateTime(2026, 10, 18));
    day.refresh(DateTime(2026, 10, 19, 3, 59));
    expect(container.read(currentDayProvider), DateTime(2026, 10, 18));
    day.refresh(DateTime(2026, 10, 19, 4, 1));
    expect(container.read(currentDayProvider), DateTime(2026, 10, 19));

    expect(seen.last, DateTime(2026, 10, 19));
    expect(seen.where((d) => d == DateTime(2026, 10, 19)), hasLength(1));
  });

  test('the moment it turns next', () {
    expect(nextDayTurn(DateTime(2026, 10, 18, 22)), DateTime(2026, 10, 19, 4));
    expect(nextDayTurn(DateTime(2026, 10, 19, 3)), DateTime(2026, 10, 19, 4));
    expect(nextDayTurn(DateTime(2026, 10, 19, 4)), DateTime(2026, 10, 20, 4));
  });
}
