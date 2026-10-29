import 'package:flutter/services.dart';

/// The phone, in the words a bug report needs.
abstract interface class PhoneInfo {
  /// "Google Pixel 7 · Android 15".
  Future<String> describe();
}

/// Android's own answer, through `FitLogActivity`.
class AndroidPhoneInfo implements PhoneInfo {
  const AndroidPhoneInfo();

  static const _channel = MethodChannel('be.fitlog.app/phone');

  @override
  Future<String> describe() async =>
      await _channel.invokeMethod<String>('describe') ?? 'Android';
}
