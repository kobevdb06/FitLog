import 'package:fitlog/features/chat/domain/coach_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

/// The weekdays the coach names are read off, not worked out.
///
/// It got every date right and every weekday one day early: the model
/// counted the days of the week as if it were last year, when 28 October
/// was a Tuesday.
void main() {
  test('vorige, deze en volgende week staan erin, met hun weekdag', () {
    final prompt = buildCoachPrompt(
      now: DateTime(2026, 10, 28, 22, 28),
      weightUnit: 'kg',
    );

    expect(prompt, contains('Vandaag is het woensdag 2026-10-28.'));
    expect(prompt, contains('deze week: ma 26/10, di 27/10, wo 28/10,'));
    // Last week, for "vorige week dinsdag"; next week, for a deload.
    expect(prompt, contains('vorige week: ma 19/10,'));
    expect(prompt, contains('volgende week: ma 2/11,'));
    expect(prompt, contains('zo 8/11'));
    expect(prompt, isNot(contains('zo 18/10')));
    expect(prompt, isNot(contains('ma 9/11')));
    expect(prompt, contains('reken je nooit zelf uit'));
  });

  test('over de jaarwissel heen', () {
    final prompt = buildCoachPrompt(
      now: DateTime(2026, 12, 30),
      weightUnit: 'kg',
    );

    expect(
      prompt,
      contains('deze week: ma 28/12, di 29/12, wo 30/12, do 31/12, vr 1/1,'),
    );
  });
}
