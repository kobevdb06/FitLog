import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workout/data/workout_notice_channel.dart';

part 'live_update_tile.g.dart';

/// Android's switch for FitLog's live notifications: the workout in the
/// status bar, and in the island of a phone that has one.
abstract interface class LiveUpdateSettings {
  /// Null where there is no such switch: before Android 16, or not Android.
  Future<bool?> allowed();

  /// Android's page where it is switched.
  Future<void> open();
}

class _AndroidLiveUpdateSettings implements LiveUpdateSettings {
  const _AndroidLiveUpdateSettings();

  static const _channel = WorkoutNoticeChannel();

  @override
  Future<bool?> allowed() async {
    try {
      return await _channel.canPromote();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> open() => _channel.openPromoteSettings();
}

class _NoLiveUpdates implements LiveUpdateSettings {
  const _NoLiveUpdates();

  @override
  Future<bool?> allowed() async => null;

  @override
  Future<void> open() async {}
}

@Riverpod(keepAlive: true)
LiveUpdateSettings liveUpdateSettings(Ref ref) => Platform.isAndroid
    ? const _AndroidLiveUpdateSettings()
    : const _NoLiveUpdates();

/// Whether the workout may be a live notification; null where it cannot be.
@riverpod
Future<bool?> liveUpdatesAllowed(Ref ref) =>
    ref.watch(liveUpdateSettingsProvider).allowed();

/// Workout in het eiland: whether Android lets the running workout into the
/// status bar and the island, and the way to its switch.
///
/// A OnePlus has it off for an app until you switch it on, and nothing asks:
/// the permission comes with the install. Without it the workout is an
/// ordinary notification under Stil.
class LiveUpdateTile extends ConsumerStatefulWidget {
  const LiveUpdateTile({super.key});

  @override
  ConsumerState<LiveUpdateTile> createState() => _LiveUpdateTileState();
}

class _LiveUpdateTileState extends ConsumerState<LiveUpdateTile>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from Android's page: it may have been switched there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(liveUpdatesAllowedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(liveUpdatesAllowedProvider).value;
    if (allowed == null) return const SizedBox.shrink();

    return ListTile(
      leading: Icon(
        allowed ? Icons.notifications_active : Icons.notifications_none,
      ),
      title: const Text('Workout in het eiland'),
      subtitle: Text(
        allowed
            ? 'Aan: je workout staat bovenaan, met wat je moet tillen.'
            : 'Uit. Tik om het aan te zetten bij Android.',
      ),
      trailing: const Icon(Icons.chevron_right),
      // Both ways: off is switched at the same place.
      onTap: () => ref.read(liveUpdateSettingsProvider).open(),
    );
  }
}
