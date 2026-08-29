// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurements_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(latestMeasurements)
final latestMeasurementsProvider = LatestMeasurementsProvider._();

final class LatestMeasurementsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<MeasurementType, BodyMeasurementRow>>,
          Map<MeasurementType, BodyMeasurementRow>,
          Stream<Map<MeasurementType, BodyMeasurementRow>>
        >
    with
        $FutureModifier<Map<MeasurementType, BodyMeasurementRow>>,
        $StreamProvider<Map<MeasurementType, BodyMeasurementRow>> {
  LatestMeasurementsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestMeasurementsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestMeasurementsHash();

  @$internal
  @override
  $StreamProviderElement<Map<MeasurementType, BodyMeasurementRow>>
  $createElement($ProviderPointer pointer) => $StreamProviderElement(pointer);

  @override
  Stream<Map<MeasurementType, BodyMeasurementRow>> create(Ref ref) {
    return latestMeasurements(ref);
  }
}

String _$latestMeasurementsHash() =>
    r'396f52993a7eaea68856d2d4b0094b48da0f053b';

@ProviderFor(measurementHistory)
final measurementHistoryProvider = MeasurementHistoryFamily._();

final class MeasurementHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BodyMeasurementRow>>,
          List<BodyMeasurementRow>,
          Stream<List<BodyMeasurementRow>>
        >
    with
        $FutureModifier<List<BodyMeasurementRow>>,
        $StreamProvider<List<BodyMeasurementRow>> {
  MeasurementHistoryProvider._({
    required MeasurementHistoryFamily super.from,
    required MeasurementType super.argument,
  }) : super(
         retry: null,
         name: r'measurementHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$measurementHistoryHash();

  @override
  String toString() {
    return r'measurementHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<BodyMeasurementRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<BodyMeasurementRow>> create(Ref ref) {
    final argument = this.argument as MeasurementType;
    return measurementHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MeasurementHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$measurementHistoryHash() =>
    r'e76a4037d2960429b0d753d9e1eee186ffe34c6f';

final class MeasurementHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<BodyMeasurementRow>>,
          MeasurementType
        > {
  MeasurementHistoryFamily._()
    : super(
        retry: null,
        name: r'measurementHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MeasurementHistoryProvider call(MeasurementType type) =>
      MeasurementHistoryProvider._(argument: type, from: this);

  @override
  String toString() => r'measurementHistoryProvider';
}
