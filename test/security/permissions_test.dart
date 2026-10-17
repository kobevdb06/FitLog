import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Permissions that Google Play only grants to a certain kind of app.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const manifest = 'android/app/src/main/AndroidManifest.xml';

  test('no exact alarms by right: that is for alarm clocks and calendars', () {
    // USE_EXACT_ALARM is granted at install and Play keeps it for apps whose
    // core is an alarm or a calendar. A rest timer is neither, so the user
    // allows exact timing (SCHEDULE_EXACT_ALARM) in Meldingen instead.
    expect(read(manifest), isNot(contains('USE_EXACT_ALARM')));
    expect(read(manifest), contains('android.permission.SCHEDULE_EXACT_ALARM'));
  });

  test('the running workout may be a Live Update, and only FitLog taps it', () {
    final xml = read(manifest);
    expect(xml, contains('android.permission.POST_PROMOTED_NOTIFICATIONS'));
    // Afvinken writes to the logbook: no other app may send it.
    final receiver = RegExp(
      r'<receiver\s+android:name="\.WorkoutActionReceiver"[^>]*>',
    ).firstMatch(xml)!.group(0)!;
    expect(receiver, contains('android:exported="false"'));
  });

  test('the morning report and the week review do not ask for the second', () {
    // Without the permission an exact alarm is refused; a report a few
    // minutes late is the same report.
    for (final path in [
      'lib/features/morning/data/morning_alarm.dart',
      'lib/features/review/data/week_alarm.dart',
    ]) {
      final source = read(path);
      expect(source, contains('exact: false'), reason: path);
      expect(source, isNot(contains('exact: true')), reason: path);
    }
  });

  test('starting a workout does not open a system page for it', () {
    // requestPermissions runs at the start of every workout; asking for
    // exact alarms there opened Android's settings each time.
    final source = read('lib/core/util/notification_service.dart');
    final ask = RegExp(r'requestExactAlarmsPermission\(\)').allMatches(source);
    expect(ask, hasLength(1));
    final askHere = source.indexOf('Future<void> askToTimeExactly()');
    expect(askHere, isNonNegative);
    expect(ask.single.start, greaterThan(askHere));
    expect(
      ask.single.start,
      lessThan(source.indexOf('Future<bool> requestPermissions()')),
    );
  });
}
