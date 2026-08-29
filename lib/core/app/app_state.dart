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

/// Something went wrong that the user cannot fix by tapping around, most
/// likely a build without SQLCipher.
class AppFailed extends AppState {
  const AppFailed(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;
}
