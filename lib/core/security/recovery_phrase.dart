/// The twelve word recovery phrase.
///
/// BIP-39 is used purely as a well-tested word list and checksum: it gives a
/// phrase that is easy to write down, hard to mistype unnoticed, and carries
/// 128 bits of entropy. The phrase is never turned into a wallet seed - it is
/// fed to Argon2id like any other secret. See [key_material.dart].
library;

import 'dart:math';

import 'package:bip39/bip39.dart' as bip39;

/// Number of words in a FitLog recovery phrase.
const int kRecoveryWordCount = 12;

/// How many words the user has to type back to confirm they wrote them down.
const int kRecoveryVerificationWords = 3;

/// A freshly generated phrase, twelve space-separated lower-case words.
String generateRecoveryPhrase() => bip39.generateMnemonic();

/// Whether [phrase] is a well-formed BIP-39 phrase.
bool isValidRecoveryPhrase(String phrase) {
  final normalized = normalizeRecoveryPhrase(phrase);
  if (normalized.split(' ').length != kRecoveryWordCount) return false;
  return bip39.validateMnemonic(normalized);
}

/// Trims, lower-cases and collapses whitespace so that the phrase the user
/// types derives the same key as the one that was shown to them.
String normalizeRecoveryPhrase(String phrase) =>
    phrase.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

List<String> recoveryWords(String phrase) =>
    normalizeRecoveryPhrase(phrase).split(' ');

/// Picks the word positions the user has to confirm, as zero-based indices in
/// ascending order.
List<int> verificationIndices(
  int wordCount, {
  int count = kRecoveryVerificationWords,
  Random? random,
}) {
  final rng = random ?? Random.secure();
  final picked = <int>{};
  while (picked.length < count && picked.length < wordCount) {
    picked.add(rng.nextInt(wordCount));
  }
  return picked.toList()..sort();
}

/// Checks the words the user typed back against the phrase.
bool verifyRecoveryWords({
  required String phrase,
  required Map<int, String> answers,
}) {
  final words = recoveryWords(phrase);
  if (answers.isEmpty) return false;
  for (final entry in answers.entries) {
    if (entry.key < 0 || entry.key >= words.length) return false;
    if (entry.value.trim().toLowerCase() != words[entry.key]) return false;
  }
  return true;
}
