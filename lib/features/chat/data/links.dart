import 'package:flutter/services.dart';

/// Where the photos of an exercise are made: Gemini, in its own app or in the
/// browser.
///
/// Opened, never talked to. FitLog hands the address to Android and is done
/// with it; the prompt gets there because the user pastes it.
const String kGeminiUrl = 'https://gemini.google.com/app';

/// Opens an address in whatever the phone opens it with.
abstract interface class LinkOpener {
  /// False when nothing on the phone could open it.
  Future<bool> open(String url);
}

/// Android's own answer to a link, through `FitLogActivity`.
class AndroidLinkOpener implements LinkOpener {
  const AndroidLinkOpener();

  static const _channel = MethodChannel('be.fitlog.app/links');

  @override
  Future<bool> open(String url) async =>
      await _channel.invokeMethod<bool>('open', {'url': url}) ?? false;
}
