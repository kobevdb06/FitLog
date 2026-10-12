import '../../../core/formatting/formatters.dart';

/// Where a coach answer that should not have been given is reported: the
/// maker's own inbox.
///
/// FitLog has no server, and a second address the app talks to would break
/// the promise that only the coach goes online (test/security). So a report
/// is an email the user sends themselves, from their own mail app, after
/// seeing every word of it.
const String kReportAddress = 'kobe.vandenberk@gmail.com';

/// Why an answer is reported. The first thing the maker reads.
enum ReportReason {
  harmful('Gevaarlijk of schadelijk advies'),
  offensive('Kwetsend of ongepast'),
  wrong('Klopt niet'),
  other('Iets anders');

  const ReportReason(this.label);

  final String label;
}

/// A coach answer someone wants the maker to see.
class AnswerReport {
  const AnswerReport({
    required this.reason,
    required this.answer,
    required this.answeredAt,
    required this.version,
    this.question,
    this.note = '',
  });

  final ReportReason reason;

  /// What the user added in their own words; may be empty.
  final String note;

  /// The question the answer was to, when there is one before it.
  final String? question;
  final String answer;
  final DateTime answeredAt;

  /// The app version that showed it.
  final String version;

  String get subject => 'FitLog: antwoord van de coach gemeld';

  /// The whole report as plain text: the email's body, or what goes on the
  /// clipboard when there is no mail app.
  String get body {
    final lines = [
      'Reden: ${reason.label}',
      if (note.trim().isNotEmpty) 'Toelichting: ${note.trim()}',
      if (question case final question? when question.trim().isNotEmpty) ...[
        '',
        'Vraag:',
        question.trim(),
      ],
      '',
      'Antwoord van de coach:',
      answer.trim(),
      '',
      'FitLog $version, antwoord van '
          '${Formatters.date(answeredAt)} ${Formatters.time(answeredAt)}',
    ];
    return lines.join('\n');
  }

  /// A `mailto:` address that opens the mail app with everything filled in.
  ///
  /// Encoded by hand: `Uri(queryParameters:)` writes a space as `+`, and mail
  /// apps show that `+` as it is.
  String get mailto =>
      'mailto:$kReportAddress'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}';
}
