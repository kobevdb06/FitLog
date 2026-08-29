/// The text-editing rules behind the custom numeric keypad.
///
/// Kept as pure Dart with no Flutter import so the awkward cases - a stray
/// second comma, backspacing past the last digit, stepping a blank field -
/// can be tested directly.
library;

/// The Dutch decimal separator. The app never shows a point.
const String kDecimalSeparator = ',';

class KeypadValue {
  const KeypadValue(this.text);

  const KeypadValue.empty() : text = '';

  /// Builds the editing text for an existing value.
  factory KeypadValue.fromNumber(num? value, {int decimals = 2}) {
    if (value == null) return const KeypadValue.empty();
    if (decimals == 0 || value == value.roundToDouble()) {
      return KeypadValue('${value.round()}');
    }
    var text = value.toStringAsFixed(decimals);
    // Trim trailing zeroes, but keep at least one decimal.
    while (text.contains('.') && text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return KeypadValue(text.replaceAll('.', kDecimalSeparator));
  }

  /// What the field shows. Empty means "no value".
  final String text;

  bool get isEmpty => text.isEmpty;

  /// The parsed number, or null when the field is blank or half-typed.
  double? get number {
    if (text.isEmpty || text == kDecimalSeparator) return null;
    return double.tryParse(text.replaceAll(kDecimalSeparator, '.'));
  }

  int? get intValue => number?.round();

  KeypadValue appendDigit(
    String digit, {
    int maxIntegerDigits = 5,
    int maxDecimals = 2,
  }) {
    if (digit.length != 1 || digit.codeUnitAt(0) < 0x30 ||
        digit.codeUnitAt(0) > 0x39) {
      return this;
    }

    final parts = text.split(kDecimalSeparator);
    if (parts.length > 1) {
      if (parts[1].length >= maxDecimals) return this;
    } else {
      if (parts[0].length >= maxIntegerDigits) return this;
      // A leading zero is replaced rather than extended.
      if (parts[0] == '0') return KeypadValue(digit);
    }
    return KeypadValue('$text$digit');
  }

  /// Adds the decimal separator, inserting a leading zero when needed.
  KeypadValue appendDecimal({bool allowDecimal = true}) {
    if (!allowDecimal) return this;
    if (text.contains(kDecimalSeparator)) return this;
    if (text.isEmpty) return const KeypadValue('0$kDecimalSeparator');
    return KeypadValue('$text$kDecimalSeparator');
  }

  KeypadValue backspace() {
    if (text.isEmpty) return this;
    return KeypadValue(text.substring(0, text.length - 1));
  }

  KeypadValue clear() => const KeypadValue.empty();

  /// Adds [delta], clamping at [min]. A blank field steps up from zero and
  /// refuses to step down.
  KeypadValue step(
    double delta, {
    double min = 0,
    double max = 99999,
    int decimals = 2,
  }) {
    final current = number;
    if (current == null && delta < 0) return this;

    var next = (current ?? 0) + delta;
    if (next < min) next = min;
    if (next > max) next = max;

    // Kill the floating point dust that 2.5 + 1.25 style arithmetic leaves.
    final factor = _pow10(decimals);
    next = (next * factor).round() / factor;

    return KeypadValue.fromNumber(next, decimals: decimals);
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is KeypadValue && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'KeypadValue("$text")';
}
