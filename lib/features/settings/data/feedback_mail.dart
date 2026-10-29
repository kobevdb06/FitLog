import '../../chat/domain/answer_report.dart' show kReportAddress;

/// A note to the maker about anything in the app: something that went wrong,
/// or an idea.
///
/// The same road as reporting a coach answer: an e-mail the user sends from
/// their own mail app, after seeing every word of it. FitLog has no server
/// to send it to, and wants none.
class FeedbackMail {
  const FeedbackMail({required this.version, this.phone});

  /// The app version it is about.
  final String version;

  /// "Google Pixel 7 · Android 15", or null where the phone could not say.
  final String? phone;

  String get subject => 'FitLog $version: iets gemeld';

  /// Two questions to answer, and below them what the maker needs to find
  /// it: which version, on which phone.
  String get body => [
    'Wat gebeurde er?',
    '',
    '',
    'Wat had je verwacht?',
    '',
    '',
    '--',
    'FitLog $version',
    ?phone,
  ].join('\n');

  /// A `mailto:` address that opens the mail app with everything filled in.
  ///
  /// Encoded by hand: `Uri(queryParameters:)` writes a space as `+`, and mail
  /// apps show that `+` as it is.
  String get mailto =>
      'mailto:$kReportAddress'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}';
}
