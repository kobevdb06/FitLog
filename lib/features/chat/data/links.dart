import 'package:flutter/services.dart';

/// Where the photos of an exercise are made: Gemini, in its own app or in the
/// browser.
///
/// Opened, never talked to. FitLog hands the address to Android and is done
/// with it; the prompt gets there because the user pastes it.
const String kGeminiUrl = 'https://gemini.google.com/app';

/// Google's terms for the Gemini API: what it may do with what the coach
/// sends on a free key.
const String kGeminiTermsUrl = 'https://ai.google.dev/gemini-api/terms';

/// Where a key for the coach is made. New users find one waiting there.
const String kAiStudioKeyUrl = 'https://aistudio.google.com/apikey';

/// FitLog's privacy policy, on the site. Health Connect opens it too, through
/// `PrivacyPolicyActivity`, which has the same address.
const String kPrivacyUrl = 'https://kobevdb06.github.io/FitLog/privacy.html';

/// FitLog's download page: the newest version, what changed in it, and how
/// to install it. Where "Nieuwe versie zoeken" goes; the app itself never asks
/// anyone which version is the newest.
const String kSiteUrl = 'https://kobevdb06.github.io/FitLog/';

/// Opens an address in whatever the phone opens it with.
abstract interface class LinkOpener {
  /// False when nothing on the phone could open it.
  Future<bool> open(String url);

  /// The same, over the app rather than instead of it: a Chrome Custom Tab,
  /// for a page the user comes back from.
  Future<bool> openOver(String url);
}

/// Android's own answer to a link, through `FitLogActivity`.
class AndroidLinkOpener implements LinkOpener {
  const AndroidLinkOpener();

  static const _channel = MethodChannel('be.fitlog.app/links');

  @override
  Future<bool> open(String url) async =>
      await _channel.invokeMethod<bool>('open', {'url': url}) ?? false;

  @override
  Future<bool> openOver(String url) async =>
      await _channel.invokeMethod<bool>('tab', {'url': url}) ?? false;
}
