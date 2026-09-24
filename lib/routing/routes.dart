/// Every path in the app, in one place, so no screen has to spell one out.
library;

abstract final class Routes {
  static const gate = '/';
  static const onboarding = '/onboarding';
  static const lock = '/lock';
  static const recovery = '/lock/herstel';
  static const failure = '/probleem';

  // Tabs
  static const dashboard = '/start';
  static const train = '/trainen';
  static const progress = '/voortgang';
  static const profile = '/profiel';

  // Train
  static const routineNew = '/trainen/routine/nieuw';
  static String routineDetail(String id) => '/trainen/routine/$id';
  static String routineEdit(String id) => '/trainen/routine/$id/bewerken';

  // Exercises
  static const exercises = '/oefeningen';
  static const exerciseNew = '/oefeningen/nieuw';
  static String exerciseDetail(String id) => '/oefeningen/$id';

  // Workout
  static const workout = '/workout';
  static const restTimer = '/workout/rust';
  static String workoutSummary(String id) => '/workout/$id/samenvatting';

  // History
  static const history = '/voortgang/geschiedenis';
  static String workoutDetail(String id) => '/voortgang/geschiedenis/$id';

  // Progress
  static const exerciseChart = '/voortgang/grafiek';
  static const measurements = '/voortgang/metingen';
  static const photos = '/voortgang/fotos';
  static const photoCompare = '/voortgang/fotos/vergelijken';

  /// Which pictures to put next to each other, as ids in the address.
  ///
  /// In the query rather than handed over as an object, so the screen survives
  /// Android rebuilding the app underneath it with the same comparison open.
  static String photoCompareOf(Iterable<String> photoIds) =>
      '$photoCompare?fotos=${photoIds.join(',')}';
  static const records = '/voortgang/records';

  /// How far each muscle is, and where to say how it feels.
  ///
  /// At the root, not under Voortgang: the Start tab opens it too, and one
  /// branch cannot push a route that lives in another. Not to be confused with
  /// [recovery], which is getting back into a locked app.
  static const muscleRecovery = '/herstel';

  // Profile and settings
  static const settings = '/profiel/instellingen';
  static const settingsCatalogue = '/profiel/instellingen/catalogus';

  /// Reachable from anywhere, because the coach screen has a button to it
  /// and that screen is a tab of its own. A route that lives inside the
  /// Profiel branch cannot be pushed from another branch: you get an empty
  /// page, which is exactly what happened.
  static const settingsCoach = '/coach/instellingen';

  /// The chat, as the fourth tab. Only there once there is a key.
  static const chat = '/chat';
  static const settingsWorkout = '/profiel/instellingen/workout';
  static const settingsSecurity = '/profiel/instellingen/beveiliging';
  static const settingsBackup = '/profiel/instellingen/backup';
  static const settingsAbout = '/profiel/instellingen/over';
}
