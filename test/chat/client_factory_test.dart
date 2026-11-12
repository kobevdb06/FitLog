import 'package:drift/native.dart';
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The coach's client factory reads the database only when a question is
/// asked. Read once and used after something else was awaited - what every
/// planned prompt, the morning report and the week review do - it had been
/// put away by then, and every one of them failed with "Er ging iets mis met
/// de coach" while the chat, which keeps watching it, went on working
/// (DECISIONS 309).
void main() {
  test('de fabriek van de coach werkt nog na een pauze', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final factory = container.read(coachClientFactoryProvider);
    // As a moment does: the facts and the day's count are awaited first.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final client = factory('AQ.Ab8RNiZhX2Mkg', kOfferedProviders.first);
    client.close();
  });

  test('een onverwachte fout zegt welke soort het was, en niet meer '
      '(DECISIONS 310)', () {
    // "Er ging iets mis" alone left nothing to go on from a screenshot. The
    // kind of error holds no key and no request; its words might.
    final message = AiClient.asCoachException(
      StateError('AQ.Ab8RNiZhX2Mkg in het verzoek'),
    ).message;

    expect(message, contains('Er ging iets mis met de coach'));
    expect(message, contains('StateError'));
    expect(message, isNot(contains('AQ.')));
    expect(message, isNot(contains('verzoek')));
  });
}
