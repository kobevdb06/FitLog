/// Unit conversion. Storage is always metric; these functions exist purely to
/// feed the display layer and to read user input back into metric.
library;

const double kKgPerLb = 0.45359237;
const double kLbPerKg = 2.20462;
const double kCmPerInch = 2.54;
const double kMetersPerMile = 1609.344;

/// Rounds [value] to the nearest multiple of [step].
double roundToStep(double value, double step) {
  if (step <= 0) return value;
  return (value / step).roundToDouble() * step;
}

// --- Weight -----------------------------------------------------------------

double kgToLb(double kg) => kg * kLbPerKg;

double lbToKg(double lb) => lb / kLbPerKg;

/// Kilograms rounded to the 0.25 kg the app displays.
double displayKg(double kg) => roundToStep(kg, 0.25);

/// Pounds rounded to the 0.5 lb the app displays.
double displayLb(double kg) => roundToStep(kgToLb(kg), 0.5);

// --- Length -----------------------------------------------------------------

double cmToInch(double cm) => cm / kCmPerInch;

double inchToCm(double inch) => inch * kCmPerInch;

// --- Distance ---------------------------------------------------------------

double metersToKm(double meters) => meters / 1000;

double metersToMiles(double meters) => meters / kMetersPerMile;

double kmToMeters(double km) => km * 1000;

double milesToMeters(double miles) => miles * kMetersPerMile;
