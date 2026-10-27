// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// You this morning. Null while the nights and the watch are read.
///
/// Worked out again when what it reads changes, and when you come back to
/// the app - the hours a muscle still needs went down meanwhile, and so may
/// the day have changed: every check rests on this one.

@ProviderFor(checkBodyToday)
final checkBodyTodayProvider = CheckBodyTodayProvider._();

/// You this morning. Null while the nights and the watch are read.
///
/// Worked out again when what it reads changes, and when you come back to
/// the app - the hours a muscle still needs went down meanwhile, and so may
/// the day have changed: every check rests on this one.

final class CheckBodyTodayProvider
    extends $FunctionalProvider<CheckBody?, CheckBody?, CheckBody?>
    with $Provider<CheckBody?> {
  /// You this morning. Null while the nights and the watch are read.
  ///
  /// Worked out again when what it reads changes, and when you come back to
  /// the app - the hours a muscle still needs went down meanwhile, and so may
  /// the day have changed: every check rests on this one.
  CheckBodyTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkBodyTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkBodyTodayHash();

  @$internal
  @override
  $ProviderElement<CheckBody?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CheckBody? create(Ref ref) {
    return checkBodyToday(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CheckBody? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CheckBody?>(value),
    );
  }
}

String _$checkBodyTodayHash() => r'ab1e92dd1706bfb80a61641bdbcbf851b213acb3';

/// The check of the session [routineId]. Null while what it reads is
/// loading.

@ProviderFor(trainingCheck)
final trainingCheckProvider = TrainingCheckFamily._();

/// The check of the session [routineId]. Null while what it reads is
/// loading.

final class TrainingCheckProvider
    extends $FunctionalProvider<TrainingCheck?, TrainingCheck?, TrainingCheck?>
    with $Provider<TrainingCheck?> {
  /// The check of the session [routineId]. Null while what it reads is
  /// loading.
  TrainingCheckProvider._({
    required TrainingCheckFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'trainingCheckProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trainingCheckHash();

  @override
  String toString() {
    return r'trainingCheckProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TrainingCheck?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TrainingCheck? create(Ref ref) {
    final argument = this.argument as String;
    return trainingCheck(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainingCheck? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainingCheck?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TrainingCheckProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trainingCheckHash() => r'ca6c91fc5534e5a476eece0c26ba69c07b0782f6';

/// The check of the session [routineId]. Null while what it reads is
/// loading.

final class TrainingCheckFamily extends $Family
    with $FunctionalFamilyOverride<TrainingCheck?, String> {
  TrainingCheckFamily._()
    : super(
        retry: null,
        name: r'trainingCheckProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The check of the session [routineId]. Null while what it reads is
  /// loading.

  TrainingCheckProvider call(String routineId) =>
      TrainingCheckProvider._(argument: routineId, from: this);

  @override
  String toString() => r'trainingCheckProvider';
}

/// What the check says about today: the session Vandaag leads with, and with
/// a schema the other sessions of the week it is weighed against.
///
/// Null when there is nothing to check - no session, or one already done
/// today - while it loads, and when the check knows nothing worth a line:
/// no recent session of its muscles and nothing about your night.

@ProviderFor(todayCheck)
final todayCheckProvider = TodayCheckProvider._();

/// What the check says about today: the session Vandaag leads with, and with
/// a schema the other sessions of the week it is weighed against.
///
/// Null when there is nothing to check - no session, or one already done
/// today - while it loads, and when the check knows nothing worth a line:
/// no recent session of its muscles and nothing about your night.

final class TodayCheckProvider
    extends $FunctionalProvider<TodayCheck?, TodayCheck?, TodayCheck?>
    with $Provider<TodayCheck?> {
  /// What the check says about today: the session Vandaag leads with, and with
  /// a schema the other sessions of the week it is weighed against.
  ///
  /// Null when there is nothing to check - no session, or one already done
  /// today - while it loads, and when the check knows nothing worth a line:
  /// no recent session of its muscles and nothing about your night.
  TodayCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayCheckProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayCheckHash();

  @$internal
  @override
  $ProviderElement<TodayCheck?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TodayCheck? create(Ref ref) {
    return todayCheck(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TodayCheck? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TodayCheck?>(value),
    );
  }
}

String _$todayCheckHash() => r'17da890df210bfb69772eb31d47072e133a1e346';
