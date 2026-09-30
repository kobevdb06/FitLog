import '../../../core/db/database.dart';
import '../../health/data/health_import.dart';
import '../../health/data/health_source.dart';
import 'morning_reporter.dart';

/// The whole morning in one go: what the watch recorded overnight comes in,
/// sessions still to be written go out, and the report is made from it all.
///
/// The same steps whether it runs at the set hour on its own or because the
/// button was pressed. Health Connect failing does not stop the report: it is
/// made from what is already in the database, and says why the night may be
/// missing.
Future<MorningReport> runMorning({
  required AppDatabase db,
  required HealthSource source,
  ReportClientFactory? clientFactory,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final import = HealthImport(db, source);

  String? importError;
  try {
    await import.run(now: at, force: true);
  } on Object catch (error) {
    importError = 'Ophalen uit Health Connect lukte niet: $error';
  }
  try {
    await import.writeWorkouts(now: at);
  } on Object {
    // Tried again at the next import; nothing in the report depends on it.
  }

  return MorningReporter(
    db,
    clientFactory: clientFactory,
  ).write(now: at, importError: importError);
}
