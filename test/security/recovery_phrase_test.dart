import 'dart:math';

import 'package:fitlog/core/security/recovery_phrase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateRecoveryPhrase', () {
    test('gives twelve valid words', () {
      final phrase = generateRecoveryPhrase();
      expect(recoveryWords(phrase), hasLength(kRecoveryWordCount));
      expect(isValidRecoveryPhrase(phrase), isTrue);
    });

    test('two phrases differ', () {
      expect(generateRecoveryPhrase(), isNot(generateRecoveryPhrase()));
    });
  });

  group('isValidRecoveryPhrase', () {
    test('rejects a phrase with a wrong word', () {
      final words = recoveryWords(generateRecoveryPhrase());
      words[0] = 'notaword';
      expect(isValidRecoveryPhrase(words.join(' ')), isFalse);
    });

    test('rejects the wrong number of words', () {
      final words = recoveryWords(generateRecoveryPhrase())..removeLast();
      expect(isValidRecoveryPhrase(words.join(' ')), isFalse);
      expect(isValidRecoveryPhrase(''), isFalse);
    });

    test('rejects a broken checksum', () {
      // Twelve real words in an order the checksum does not allow.
      expect(
        isValidRecoveryPhrase(
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon',
        ),
        isFalse,
      );
    });

    test('accepts the canonical BIP-39 test vector', () {
      expect(
        isValidRecoveryPhrase(
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about',
        ),
        isTrue,
      );
    });
  });

  group('normalizeRecoveryPhrase', () {
    test('trims, lower-cases and collapses whitespace', () {
      expect(
        normalizeRecoveryPhrase('  Abandon   ABOUT\tlegal\n '),
        'abandon about legal',
      );
    });

    test('a messily typed phrase still validates', () {
      final phrase = generateRecoveryPhrase();
      final messy = '  ${recoveryWords(phrase).join('   ').toUpperCase()} ';
      expect(isValidRecoveryPhrase(messy), isTrue);
      expect(normalizeRecoveryPhrase(messy), phrase);
    });
  });

  group('verification', () {
    test('picks the requested number of distinct indices', () {
      final indices = verificationIndices(12, random: Random(7));
      expect(indices, hasLength(kRecoveryVerificationWords));
      expect(indices.toSet(), hasLength(kRecoveryVerificationWords));
      expect(indices, orderedEquals(indices.toList()..sort()));
      for (final i in indices) {
        expect(i, inInclusiveRange(0, 11));
      }
    });

    test('never asks for more words than there are', () {
      expect(verificationIndices(2, random: Random(1)), hasLength(2));
    });

    test('accepts the right words', () {
      final phrase = generateRecoveryPhrase();
      final words = recoveryWords(phrase);
      expect(
        verifyRecoveryWords(
          phrase: phrase,
          answers: {0: words[0], 5: words[5].toUpperCase(), 11: ' ${words[11]} '},
        ),
        isTrue,
      );
    });

    test('rejects a wrong word', () {
      final phrase = generateRecoveryPhrase();
      final words = recoveryWords(phrase);
      expect(
        verifyRecoveryWords(
          phrase: phrase,
          answers: {0: words[0], 5: 'zebra'},
        ),
        isFalse,
      );
    });

    test('rejects an empty answer set and out of range indices', () {
      final phrase = generateRecoveryPhrase();
      expect(verifyRecoveryWords(phrase: phrase, answers: const {}), isFalse);
      expect(
        verifyRecoveryWords(phrase: phrase, answers: const {99: 'abandon'}),
        isFalse,
      );
    });
  });
}
