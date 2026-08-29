import 'package:fitlog/core/calc/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weight conversion', () {
    test('kg to lb uses the documented factor', () {
      expect(kgToLb(100), closeTo(220.462, 0.001));
      expect(kgToLb(0), 0);
    });

    test('lb to kg is the inverse', () {
      expect(lbToKg(kgToLb(87.5)), closeTo(87.5, 0.0001));
    });

    test('display rounding', () {
      expect(displayKg(100.13), 100.25);
      expect(displayKg(100.12), 100.0);
      expect(displayLb(100), closeTo(220.5, 0.001));
    });
  });

  group('roundToStep', () {
    test('rounds to the nearest multiple', () {
      expect(roundToStep(2.4, 0.5), 2.5);
      expect(roundToStep(2.2, 0.5), 2.0);
      expect(roundToStep(101.3, 2.5), 102.5);
    });

    test('a non-positive step leaves the value alone', () {
      expect(roundToStep(2.4, 0), 2.4);
      expect(roundToStep(2.4, -1), 2.4);
    });
  });

  group('length and distance', () {
    test('cm and inch round trip', () {
      expect(cmToInch(2.54), closeTo(1, 0.0001));
      expect(inchToCm(cmToInch(180)), closeTo(180, 0.0001));
    });

    test('metres convert to km and miles', () {
      expect(metersToKm(5000), 5);
      expect(metersToMiles(1609.344), closeTo(1, 0.0001));
      expect(kmToMeters(5), 5000);
      expect(milesToMeters(1), closeTo(1609.344, 0.0001));
    });
  });
}
