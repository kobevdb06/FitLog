import 'package:fitlog/core/db/enums.dart';
import 'package:fitlog/core/formatting/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// An estimated one-rep max, to the whole kilo or pound.
void main() {
  const kg = Formatters();
  const lb = Formatters(weightUnit: WeightUnit.lb);

  test('in hele kilo', () {
    expect(kg.estimate(118.25), '118 kg');
    expect(kg.estimate(118.5), '119 kg');
    expect(kg.estimate(1012.4), '1.012 kg');
  });

  test(
    'van het getal zelf, niet van de kwartkilo die er al van gemaakt is',
    () {
      // 118.375 shows as 118,5 kg; to the whole kilo it is still 118.
      expect(kg.estimate(118.375), '118 kg');
    },
  );

  test('in hele pond', () {
    expect(lb.estimate(100), '220 lb');
    expect(lb.estimateValue(100), 220);
  });
}
