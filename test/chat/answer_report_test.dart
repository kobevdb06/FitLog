import 'package:fitlog/features/chat/domain/answer_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// A reported answer, as the email the maker gets.
void main() {
  setUpAll(initialiseTestLocale);

  AnswerReport report({String note = '', String? question}) => AnswerReport(
    reason: ReportReason.harmful,
    note: note,
    question: question,
    answer: 'Train door de pijn heen & sla de warming-up over.',
    answeredAt: DateTime(2026, 10, 12, 14, 3),
    version: '1.58.0',
  );

  test('zegt eerst waarom, dan de vraag, dan het antwoord', () {
    final body = report(
      note: 'Mijn knie deed pijn.',
      question: 'Mag ik squatten met pijn?',
    ).body;

    expect(
      body,
      startsWith(
        'Reden: Gevaarlijk of schadelijk advies\n'
        'Toelichting: Mijn knie deed pijn.\n'
        '\n'
        'Vraag:\n'
        'Mag ik squatten met pijn?\n'
        '\n'
        'Antwoord van de coach:\n'
        'Train door de pijn heen & sla de warming-up over.\n',
      ),
    );
    expect(body, contains('FitLog 1.58.0'));
    expect(body, contains('14:03'));
  });

  test('zonder toelichting of vraag staan die er niet leeg in', () {
    final body = report().body;

    expect(body, isNot(contains('Toelichting')));
    expect(body, isNot(contains('Vraag:')));
  });

  test('gaat naar de maker, met alles leesbaar in de mail-app', () {
    final mailto = report(question: 'Mag ik squatten met pijn?').mailto;
    final uri = Uri.parse(mailto);

    expect(uri.scheme, 'mailto');
    expect(uri.path, kReportAddress);
    // A space as `+` would show as a `+` in the mail; an `&` in the answer
    // left as it is would cut the body short.
    expect(mailto, isNot(contains('+')));
    expect(
      uri.queryParameters['body'],
      report(question: 'Mag ik squatten met pijn?').body,
    );
    expect(
      uri.queryParameters['subject'],
      'FitLog: antwoord van de coach gemeld',
    );
  });
}
