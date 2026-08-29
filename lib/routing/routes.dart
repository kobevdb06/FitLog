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
  static const records = '/voortgang/records';

  // Profile and settings
  static const settings = '/profiel/instellingen';
  static const settingsWorkout = '/profiel/instellingen/workout';
  static const settingsSecurity = '/profiel/instellingen/beveiliging';
  static const settingsBackup = '/profiel/instellingen/backup';
  static const settingsAbout = '/profiel/instellingen/over';
}
