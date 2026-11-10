import '../db/database.dart';
import '../security/key_manager.dart';

/// What the app is currently able to show.
///
/// The router derives every redirect from this, so there is exactly one place
/// that decides between onboarding, the lock screen and the app itself.
sealed class AppState {
  const AppState();
}

/// Reading the key store and opening the database.
class AppLoading extends AppState {
  const AppLoading();
}

/// No key exists yet: this device has never completed onboarding.
class AppNeedsOnboarding extends AppState {
  const AppNeedsOnboarding();
}

/// The keys are gone, or the key store cannot be read, while the database is
/// still on this device. Not a first start: the twelve words open it, from
/// the copy of its key kept next to it (DECISIONS 241).
class AppNeedsRecovery extends AppState {
  const AppNeedsRecovery({
    required this.unreadable,
    required this.canUsePhrase,
  });

  /// The key store answered with an error rather than with nothing: trying
  /// again may be enough.
  final bool unreadable;

  /// The copy of the key the twelve words open is on this device.
  final bool canUsePhrase;
}

/// The keys are here and the database is not. Opening would quietly make an
/// empty one; it is said first, so an empty app is a choice (DECISIONS 241).
class AppDatabaseMissing extends AppState {
  const AppDatabaseMissing();
}

/// A PIN protects the database and has not been entered yet.
class AppLocked extends AppState {
  const AppLocked(this.security);

  final SecurityStatus security;
}

/// The database is open and every screen can be used.
class AppReady extends AppState {
  const AppReady({required this.db, required this.security});

  final AppDatabase db;
  final SecurityStatus security;
}

/// Where a cold start goes, once the key store answered.
enum StartStep { onboarding, recovery, locked, open }

/// [hasDirectKey]: the key stored without a PIN in front of it was there.
/// A device without keys is new only when there is no database on it
/// either; with one, its keys were lost, and starting over would make a new
/// key that never opens it (DECISIONS 241).
StartStep startStepFor({
  required SecurityStatus security,
  required bool hasDirectKey,
  required bool databaseExists,
}) {
  final keyed =
      security.initialised && (security.mode == LockMode.pin || hasDirectKey);
  if (!keyed) {
    return databaseExists ? StartStep.recovery : StartStep.onboarding;
  }
  return security.mode == LockMode.pin ? StartStep.locked : StartStep.open;
}

/// Something went wrong that the user cannot fix by tapping around, most
/// likely a build without SQLCipher.
class AppFailed extends AppState {
  const AppFailed(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;
}
