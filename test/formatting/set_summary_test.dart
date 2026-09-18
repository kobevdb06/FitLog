import 'package:fitlog/core/formatting/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// One line per set, as you read it back weeks later.
///
/// The numbers say what you lifted. They do not say what it cost you: the same
/// 100 kg for 5 is a warm-up on one day and everything you had on another, and
/// a column of identical sets is exactly where that difference matters.
void main() {
  setUpAll(initialiseTestLocale);

  const formatters = Formatters();

  test('zonder RPE staat er wat er altijd stond', () {
    expect(formatters.setSummary(weightKg: 100, reps: 5), '100 kg × 5');
    expect(formatters.setSummary(reps: 8), '8 reps');
    expect(formatters.setSummary(), '-');
  });

  test('en met RPE staat het erachter, zoals het gezegd wordt', () {
    expect(
      formatters.setSummary(weightKg: 100, reps: 5, rpe: 8),
      '100 kg × 5 @8',
    );
    // Halve punten bestaan; hele getallen krijgen geen komma-nul.
    expect(
      formatters.setSummary(weightKg: 100, reps: 5, rpe: 8.5),
      '100 kg × 5 @8,5',
    );
  });

  test('ook bij een set die in tijd of afstand telt', () {
    expect(formatters.setSummary(durationSeconds: 60, rpe: 9), '01:00 @9');
    expect(formatters.setSummary(distanceM: 5000, rpe: 7), '5 km @7');
  });

  test('en een set zonder getallen valt niet terug op een streepje', () {
    // Er staat dan iets: dat je hem zwaar vond is ook iets.
    expect(formatters.setSummary(rpe: 9), '@9');
  });
}
