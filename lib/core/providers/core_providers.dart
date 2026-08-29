import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app/app_controller.dart';
import '../calc/plates.dart';
import '../db/database.dart';
import '../formatting/formatters.dart';

part 'core_providers.g.dart';

/// The one settings row, as a stream so every screen reacts to a unit change.
@Riverpod(keepAlive: true)
Stream<AppSettingsRow> settings(Ref ref) =>
    ref.watch(databaseProvider).settingsDao.watchSettings();

@Riverpod(keepAlive: true)
Stream<UserProfileRow?> userProfile(Ref ref) =>
    ref.watch(databaseProvider).settingsDao.watchProfile();

/// Display helpers bound to the user's chosen units.
@Riverpod(keepAlive: true)
Formatters formatters(Ref ref) {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null) return const Formatters();
  return Formatters(
    weightUnit: WeightUnit.fromWire(settings.unitWeight),
    lengthUnit: LengthUnit.fromWire(settings.unitLength),
    distanceUnit: DistanceUnit.fromWire(settings.unitDistance),
  );
}

/// The bar and plates the calculators work with.
@Riverpod(keepAlive: true)
BarbellSetup barbellSetup(Ref ref) {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null) return const BarbellSetup();
  return BarbellSetup(
    barKg: settings.barWeightKg,
    platesKg: decodePlates(settings.availablePlatesKg),
  );
}

class BarbellSetup {
  const BarbellSetup({
    this.barKg = kDefaultBarWeightKg,
    this.platesKg = kDefaultPlatesKg,
  });

  final double barKg;
  final List<double> platesKg;
}

/// Reads the JSON array of plate weights stored in the settings row.
List<double> decodePlates(String raw) {
  try {
    final list = jsonDecode(raw) as List;
    final plates = list.map((e) => (e as num).toDouble()).toList()
      ..sort((a, b) => b.compareTo(a));
    return plates.isEmpty ? kDefaultPlatesKg : plates;
  } on FormatException {
    return kDefaultPlatesKg;
  }
}

String encodePlates(List<double> plates) =>
    jsonEncode((plates.toList()..sort((a, b) => b.compareTo(a))));
