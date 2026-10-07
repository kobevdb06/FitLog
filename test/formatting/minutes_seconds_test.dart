import 'package:fitlog/core/formatting/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// A rest in words, to the second.
void main() {
  test('minuten en seconden', () {
    expect(Formatters.minutesSeconds(150), '2 min 30 s');
    expect(Formatters.minutesSeconds(90), '1 min 30 s');
  });

  test('een ronde minuut zonder seconden', () {
    expect(Formatters.minutesSeconds(120), '2 min');
  });

  test('onder een minuut alleen seconden', () {
    expect(Formatters.minutesSeconds(45), '45 s');
    expect(Formatters.minutesSeconds(0), '0 s');
  });
}
