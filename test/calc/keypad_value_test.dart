import 'package:fitlog/core/widgets/keypad_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsing', () {
    test('an empty field has no number', () {
      expect(const KeypadValue.empty().number, isNull);
      expect(const KeypadValue.empty().isEmpty, isTrue);
    });

    test('reads the Dutch decimal separator', () {
      expect(const KeypadValue('82,5').number, 82.5);
      expect(const KeypadValue('82,5').intValue, 83);
    });

    test('a lone separator is not a number yet', () {
      expect(const KeypadValue(',').number, isNull);
    });
  });

  group('fromNumber', () {
    test('drops the decimals of a whole number', () {
      expect(KeypadValue.fromNumber(100).text, '100');
      expect(KeypadValue.fromNumber(100.0).text, '100');
    });

    test('keeps a real decimal and uses a comma', () {
      expect(KeypadValue.fromNumber(82.5).text, '82,5');
      expect(KeypadValue.fromNumber(1.25).text, '1,25');
    });

    test('respects the decimals argument', () {
      expect(KeypadValue.fromNumber(8.6, decimals: 0).text, '9');
    });

    test('null gives an empty field', () {
      expect(KeypadValue.fromNumber(null).isEmpty, isTrue);
    });
  });

  group('appendDigit', () {
    test('appends', () {
      expect(const KeypadValue('1').appendDigit('2').text, '12');
    });

    test('replaces a lone leading zero', () {
      expect(const KeypadValue('0').appendDigit('5').text, '5');
    });

    test('ignores anything that is not a digit', () {
      expect(const KeypadValue('1').appendDigit('a').text, '1');
      expect(const KeypadValue('1').appendDigit('12').text, '1');
    });

    test('stops at the integer limit', () {
      expect(
        const KeypadValue('12345').appendDigit('6', maxIntegerDigits: 5).text,
        '12345',
      );
    });

    test('stops at the decimal limit', () {
      expect(
        const KeypadValue('1,25').appendDigit('9', maxDecimals: 2).text,
        '1,25',
      );
      expect(
        const KeypadValue('1,2').appendDigit('5', maxDecimals: 2).text,
        '1,25',
      );
    });
  });

  group('appendDecimal', () {
    test('adds a leading zero to an empty field', () {
      expect(const KeypadValue.empty().appendDecimal().text, '0,');
    });

    test('refuses a second separator', () {
      expect(const KeypadValue('1,2').appendDecimal().text, '1,2');
    });

    test('does nothing for integer-only fields', () {
      expect(
        const KeypadValue('5').appendDecimal(allowDecimal: false).text,
        '5',
      );
    });
  });

  group('backspace and clear', () {
    test('removes the last character', () {
      expect(const KeypadValue('125').backspace().text, '12');
      expect(const KeypadValue('1,').backspace().text, '1');
    });

    test('backspacing an empty field is harmless', () {
      expect(const KeypadValue.empty().backspace().isEmpty, isTrue);
    });

    test('clear empties the field', () {
      expect(const KeypadValue('100').clear().isEmpty, isTrue);
    });
  });

  group('step', () {
    test('adds and subtracts', () {
      expect(const KeypadValue('100').step(2.5).text, '102,5');
      expect(const KeypadValue('100').step(-2.5).text, '97,5');
    });

    test('steps up from an empty field', () {
      expect(const KeypadValue.empty().step(2.5).text, '2,5');
    });

    test('refuses to step down from an empty field', () {
      expect(const KeypadValue.empty().step(-2.5).isEmpty, isTrue);
    });

    test('clamps at the minimum', () {
      expect(const KeypadValue('1').step(-5).text, '0');
    });

    test('keeps 1.25 increments clean', () {
      var value = const KeypadValue('0');
      for (var i = 0; i < 8; i++) {
        value = value.step(1.25);
      }
      expect(value.text, '10');
    });

    test('reps step as whole numbers', () {
      expect(const KeypadValue('8').step(1, decimals: 0).text, '9');
      expect(const KeypadValue('8').step(5, decimals: 0).text, '13');
    });
  });
}
