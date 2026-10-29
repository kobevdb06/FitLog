import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/phone.dart';

part 'feedback_providers.g.dart';

/// What says which phone this is, or null where there is no Android to ask.
@Riverpod(keepAlive: true)
PhoneInfo? phoneInfo(Ref ref) =>
    Platform.isAndroid ? const AndroidPhoneInfo() : null;

/// "Google Pixel 7 · Android 15", for the end of an e-mail to the maker.
@Riverpod(keepAlive: true)
Future<String?> phoneDescription(Ref ref) async =>
    ref.watch(phoneInfoProvider)?.describe();
