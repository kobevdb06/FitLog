import 'package:fitlog/features/chat/domain/coach_commands.dart';
import 'package:flutter_test/flutter_test.dart';

/// What is typed after a / in the coach.
void main() {
  group('readCommand', () {
    test('a question is no command', () {
      expect(readCommand('Hoeveel sets voor borst?'), isNull);
      expect(readCommand('Is 3/4 van mijn max genoeg?'), isNull);
    });

    test('one of the app\'s, with what comes after it', () {
      final typed = readCommand('  /onthoud  traint thuis met dumbbells ');
      expect(typed, isA<AppCommand>());
      typed as AppCommand;
      expect(typed.command, CoachCommand.onthoud);
      expect(typed.argument, 'traint thuis met dumbbells');

      final map = readCommand('/MAP Techniek') as AppCommand;
      expect(map.command, CoachCommand.map);
      expect(map.argument, 'Techniek');

      final alone = readCommand('/kosten') as AppCommand;
      expect(alone.command, CoachCommand.kosten);
      expect(alone.argument, isEmpty);
    });

    test('an argument may run over lines', () {
      final typed = readCommand('/onthoud eerste regel\ntweede') as AppCommand;
      expect(typed.argument, 'eerste regel\ntweede');
    });

    test('your own, by its name', () {
      final typed = readCommand('/Rug', own: {'rug': 'Hoeveel sets nog?'});
      expect(typed, isA<OwnCommand>());
      expect((typed as OwnCommand).question, 'Hoeveel sets nog?');
    });

    test('the app\'s goes before your own of the same name', () {
      final typed = readCommand('/week', own: {'week': 'Mijn week?'});
      expect(typed, isA<AppCommand>());
    });

    test('anything else after a / is no command, and says so', () {
      expect((readCommand('/compact') as NoCommand).typed, '/compact');
      expect((readCommand('/') as NoCommand).typed, '/');
      expect((readCommand('/ waarom') as NoCommand).typed, '/');
    });
  });

  group('commandBeingTyped', () {
    test('the name while it is typed, and nothing once there is a space', () {
      expect(commandBeingTyped('/'), '');
      expect(commandBeingTyped('/Wo'), 'wo');
      expect(commandBeingTyped('/onthoud '), isNull);
      expect(commandBeingTyped('hoi'), isNull);
      expect(commandBeingTyped(''), isNull);
    });
  });

  group('a name of your own', () {
    test('is taken without its / and in small letters', () {
      expect(commandName(' /Rug '), 'rug');
      expect(commandName('//benen2'), 'benen2');
    });

    test('is letters and digits, short, and nobody else\'s', () {
      expect(commandProblem('rug'), isNull);
      expect(commandProblem('rug 2'), isNotNull);
      expect(commandProblem('één'), isNotNull);
      expect(commandProblem('x' * (kCommandNameLength + 1)), isNotNull);
      expect(commandProblem('kosten'), contains('van de app'));
      expect(commandProblem('rug', taken: ['rug']), contains('andere vraag'));
    });
  });

  test('the conversation as the coach reads it to sum it up', () {
    expect(
      conversationText('Mijn knie', [
        (role: 'user', text: 'Doet pijn bij squats.'),
        (role: 'assistant', text: 'Tot parallel dan.'),
      ]),
      'Het gesprek "Mijn knie":\n\n'
      'Gebruiker: Doet pijn bij squats.\n\n'
      'Coach: Tot parallel dan.',
    );
  });

  test('a long conversation goes without its oldest part (DECISIONS 251)', () {
    final text = conversationText('Lang', [
      for (var i = 0; i < 10; i++)
        (role: 'user', text: 'Bericht $i ${'x' * 90}'),
    ], maxChars: 350);

    expect(text, contains('Bericht 9'));
    expect(text, isNot(contains('Bericht 0 ')));
    expect(text, contains('berichten zijn weggelaten'));
    expect(text.length, lessThan(600));
  });
}
