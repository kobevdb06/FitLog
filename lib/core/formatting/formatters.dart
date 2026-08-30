import 'package:intl/intl.dart';

import '../calc/units.dart';
import '../db/enums.dart';

/// Turns stored metric values into Dutch text.
///
/// Every conversion in the app happens here; the database only ever holds
/// kilograms, centimetres, metres and seconds.
class Formatters {
  const Formatters({
    this.weightUnit = WeightUnit.kg,
    this.lengthUnit = LengthUnit.cm,
    this.distanceUnit = DistanceUnit.km,
  });

  final WeightUnit weightUnit;
  final LengthUnit lengthUnit;
  final DistanceUnit distanceUnit;

  static const _locale = 'nl';

  static final NumberFormat _decimal = NumberFormat('#,##0.##', _locale);
  static final NumberFormat _oneDecimal = NumberFormat('#,##0.0', _locale);
  static final NumberFormat _integer = NumberFormat('#,##0', _locale);

  // --- Weight ---------------------------------------------------------------

  /// The step the plus/minus buttons use, in the display unit.
  double get weightStep => weightUnit == WeightUnit.kg ? 2.5 : 5;

  String get weightUnitLabel => weightUnit.label;

  /// Kilograms converted into the display unit and rounded to what the app
  /// shows: 0.25 kg or 0.5 lb.
  double toDisplayWeight(double kg) =>
      weightUnit == WeightUnit.kg ? displayKg(kg) : displayLb(kg);

  /// The inverse of [toDisplayWeight], for reading input back.
  double fromDisplayWeight(double value) =>
      weightUnit == WeightUnit.kg ? value : lbToKg(value);

  /// `100` or `82,5`, without a unit.
  String weightValue(double? kg) {
    if (kg == null) return '-';
    return _decimal.format(toDisplayWeight(kg));
  }

  /// `100 kg`.
  String weight(double? kg) {
    if (kg == null) return '-';
    return '${weightValue(kg)} $weightUnitLabel';
  }

  /// `80 kg x 8`, the shape used in the "previous" column and in exports.
  String setSummary({double? weightKg, int? reps, int? durationSeconds}) {
    if (durationSeconds != null && weightKg == null && reps == null) {
      return duration(durationSeconds);
    }
    if (weightKg == null && reps == null) return '-';
    if (weightKg == null) return '$reps reps';
    if (reps == null) return weight(weightKg);
    return '${weight(weightKg)} × $reps';
  }

  /// Large totals read better in tonnes.
  String volume(double kg) {
    final value = weightUnit == WeightUnit.kg ? kg : kgToLb(kg);
    if (value >= 1000) {
      return '${_oneDecimal.format(value / 1000)} '
          '${weightUnit == WeightUnit.kg ? 't' : 'k$weightUnitLabel'}';
    }
    return '${_integer.format(value)} $weightUnitLabel';
  }

  // --- Length and distance --------------------------------------------------

  String get lengthUnitLabel => lengthUnit.label;

  double toDisplayLength(double cm) =>
      lengthUnit == LengthUnit.cm ? cm : cmToInch(cm);

  double fromDisplayLength(double value) =>
      lengthUnit == LengthUnit.cm ? value : inchToCm(value);

  String length(double? cm) {
    if (cm == null) return '-';
    return '${_decimal.format(toDisplayLength(cm))} $lengthUnitLabel';
  }

  String distance(double? meters) {
    if (meters == null) return '-';
    final value = distanceUnit == DistanceUnit.km
        ? metersToKm(meters)
        : metersToMiles(meters);
    return '${_decimal.format(value)} ${distanceUnit.label}';
  }

  /// Body measurements carry their own unit.
  String measurement(MeasurementType type, double value) {
    switch (type.unit) {
      case MeasurementUnit.kg:
        return weight(value);
      case MeasurementUnit.cm:
        return length(value);
      case MeasurementUnit.percent:
        return '${_decimal.format(value)} %';
    }
  }

  double toDisplayMeasurement(MeasurementType type, double value) {
    switch (type.unit) {
      case MeasurementUnit.kg:
        return toDisplayWeight(value);
      case MeasurementUnit.cm:
        return toDisplayLength(value);
      case MeasurementUnit.percent:
        return value;
    }
  }

  double fromDisplayMeasurement(MeasurementType type, double value) {
    switch (type.unit) {
      case MeasurementUnit.kg:
        return fromDisplayWeight(value);
      case MeasurementUnit.cm:
        return fromDisplayLength(value);
      case MeasurementUnit.percent:
        return value;
    }
  }

  String measurementUnitLabel(MeasurementType type) {
    switch (type.unit) {
      case MeasurementUnit.kg:
        return weightUnitLabel;
      case MeasurementUnit.cm:
        return lengthUnitLabel;
      case MeasurementUnit.percent:
        return '%';
    }
  }

  // --- Numbers --------------------------------------------------------------

  String count(int value) => _integer.format(value);

  String decimal(double value) => _decimal.format(value);

  // --- Time -----------------------------------------------------------------

  /// `12:34` below an hour, `1:02:03` above it.
  static String duration(int seconds) {
    final d = Duration(seconds: seconds.abs());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  /// `1 u 12 min` or `45 min`, for summaries.
  static String durationWords(int seconds) {
    final d = Duration(seconds: seconds.abs());
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60);
      return minutes == 0
          ? '${d.inHours} u'
          : '${d.inHours} u $minutes min';
    }
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  static final DateFormat _dayMonth = DateFormat('d MMM', _locale);
  static final DateFormat _fullDate = DateFormat('d MMMM yyyy', _locale);
  static final DateFormat _shortDate = DateFormat('d MMM yyyy', _locale);
  static final DateFormat _weekday = DateFormat('EEEE', _locale);
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', _locale);
  static final DateFormat _time = DateFormat('HH:mm', _locale);

  static String date(DateTime at) => _shortDate.format(at);

  static String fullDate(DateTime at) => _fullDate.format(at);

  static String dayMonth(DateTime at) => _dayMonth.format(at);

  static String monthYear(DateTime at) => _monthYear.format(at);

  static String weekday(DateTime at) => _weekday.format(at);

  static String time(DateTime at) => _time.format(at);

  static String weekdayName(int weekday) {
    // 1 = Monday .. 7 = Sunday. 5 January 2026 is a Monday.
    return _weekday.format(DateTime(2026, 1, 4 + weekday));
  }

  /// `Vandaag`, `Gisteren`, `3 dagen geleden`, then a plain date.
  static String relativeDay(DateTime at, {DateTime? now}) {
    final today = _midnight(now ?? DateTime.now());
    final days = today.difference(_midnight(at)).inDays;
    if (days == 0) return 'Vandaag';
    if (days == 1) return 'Gisteren';
    if (days > 1 && days < 7) return '$days dagen geleden';
    if (days == -1) return 'Morgen';
    return date(at);
  }

  /// `Vandaag om 18:30` for history headers.
  static String relativeDayTime(DateTime at, {DateTime? now}) =>
      '${relativeDay(at, now: now)} om ${time(at)}';

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// `nog 2 d 6 u`, counting down to the end of a recovery window.
  static String remainingWords(Duration left) {
    if (left <= Duration.zero) return 'klaar';
    if (left.inHours < 1) return 'nog ${left.inMinutes} min';
    if (left.inHours < 24) return 'nog ${left.inHours} u';
    final days = left.inDays;
    final hours = left.inHours.remainder(24);
    return hours == 0 ? 'nog $days d' : 'nog $days d $hours u';
  }

  /// `sinds 3 dagen`, used by the streak line.
  static String daysAgoWords(int days) {
    if (days <= 0) return 'vandaag';
    if (days == 1) return 'gisteren';
    return '$days dagen geleden';
  }
}
