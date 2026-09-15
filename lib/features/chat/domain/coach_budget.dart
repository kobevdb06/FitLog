/// How much of a day's asking has been used, and when the day starts.
///
/// The honest part first: no API hands a client the remaining credits of a
/// free tier. Not Google's, not Anthropic's. So this is not a reading of what
/// is left over there - it is a count of what this app sent, measured against
/// a number the user sets themselves. That difference is said out loud on the
/// screen, because a bar that looks like a fuel gauge and is really a diary
/// would be worse than no bar at all.
///
/// What the app can count exactly: how many calls it made and how many tokens
/// those cost, both of which the service reports back with every answer.
library;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/ai_client.dart';

/// Where the app starts counting, per service, and why.
///
/// Google's free tier resets at midnight in California, not at midnight here.
/// Counting per local day would show "3 vandaag" at eight in the morning while
/// Google still had yesterday's two hundred on the clock - exactly the moment
/// someone would look at this bar.
const String kGeminiQuotaZone = 'America/Los_Angeles';

/// The figure the bar starts at until the user says otherwise.
///
/// A starting point, not a promise: free tiers change, and the app has no way
/// to ask what yours is.
const int kDefaultDailyLimit = 250;

/// The moment the current day of counting began.
DateTime coachDayStart(DateTime now, CoachProvider provider) {
  if (provider != CoachProvider.gemini) {
    // A budget of your own, so your own midnight.
    return DateTime(now.year, now.month, now.day);
  }

  tzdata.initializeTimeZones();
  final pacific = tz.getLocation(kGeminiQuotaZone);
  final there = tz.TZDateTime.from(now, pacific);
  final midnight = tz.TZDateTime(pacific, there.year, there.month, there.day);
  return midnight.toLocal();
}

/// What has been spent since then.
class CoachDayUsage {
  const CoachDayUsage({
    required this.requests,
    required this.answers,
    required this.inputTokens,
    required this.outputTokens,
    required this.since,
  });

  static const CoachDayUsage none = CoachDayUsage(
    requests: 0,
    answers: 0,
    inputTokens: 0,
    outputTokens: 0,
    since: null,
  );

  /// Calls to the service. This is what a daily free tier counts.
  final int requests;

  /// Answers you got. Fewer than [requests] whenever the coach looked
  /// something up first.
  final int answers;

  final int inputTokens;
  final int outputTokens;

  /// When this day of counting began, or null when nothing was asked.
  final DateTime? since;

  int get tokens => inputTokens + outputTokens;

  /// How full the bar is, between 0 and 1.
  double fractionOf(int limit) {
    if (limit <= 0) return 0;
    final part = requests / limit;
    return part > 1 ? 1 : part;
  }

  bool isOver(int limit) => limit > 0 && requests >= limit;
}
