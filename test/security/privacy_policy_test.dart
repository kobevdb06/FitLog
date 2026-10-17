import 'dart:io';

import 'package:fitlog/features/chat/data/links.dart';
import 'package:flutter_test/flutter_test.dart';

/// The privacy policy: one page on the site, one address everywhere that
/// opens it, and nothing read from Health Connect that it does not name.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const manifest = 'android/app/src/main/AndroidManifest.xml';
  const page = 'docs/privacy.html';

  test('the address in the app is a page the site has', () {
    expect(kPrivacyUrl, startsWith('https://'));
    expect(Uri.parse(kPrivacyUrl).pathSegments.last, 'privacy.html');
    expect(File(page).existsSync(), isTrue);
  });

  test('and Health Connect opens the same address', () {
    final activity = read(
      'android/app/src/main/kotlin/be/fitlog/app/PrivacyPolicyActivity.kt',
    );
    expect(activity, contains('"$kPrivacyUrl"'));
  });

  test('Health Connect reaches the policy, not the app', () {
    final xml = read(manifest);
    final policy = RegExp(
      r'<activity\s+android:name="\.PrivacyPolicyActivity"[\s\S]*?</activity>',
    ).firstMatch(xml)!.group(0)!;
    expect(
      policy,
      contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'),
    );
    expect(policy, contains('android:exported="true"'));

    final usage = RegExp(
      r'<activity-alias\s+android:name="ViewPermissionUsageActivity"[^>]*>',
    ).firstMatch(xml)!.group(0)!;
    expect(usage, contains('android:targetActivity=".PrivacyPolicyActivity"'));

    // Only once, and not on the app itself.
    expect(
      RegExp('ACTION_SHOW_PERMISSIONS_RATIONALE"/>\\s*</intent-filter>')
          .allMatches(xml),
      hasLength(1),
    );
  });

  test('every Health Connect permission is named in the policy', () {
    // What someone reads before granting it. A permission added to the
    // manifest without a line in the policy fails here.
    const named = {
      'READ_SLEEP': 'Slaap, met de fasen',
      'READ_HEART_RATE_VARIABILITY': 'HRV',
      'READ_RESTING_HEART_RATE': 'rusthartslag',
      'READ_HEART_RATE': '<td>Hartslag</td>',
      'READ_OXYGEN_SATURATION': 'Zuurstofsaturatie',
      'READ_STEPS': 'Stappen',
      'READ_WEIGHT': 'Gewicht',
      'READ_EXERCISE': 'Loop- en fietssessies',
      'WRITE_EXERCISE': 'Trainingen ook naar Health\n    Connect',
      'READ_HEALTH_DATA_IN_BACKGROUND': 'Op de achtergrond',
    };
    final policy = read(page);
    final asked = RegExp(r'android\.permission\.health\.([A-Z_]+)')
        .allMatches(read(manifest))
        .map((m) => m.group(1)!)
        .toSet();

    expect(asked, isNotEmpty);
    for (final permission in asked) {
      expect(named, contains(permission), reason: '$permission is not named');
      expect(policy, contains(named[permission]!), reason: permission);
    }
  });

  test('and so is every other permission the app declares', () {
    const named = {
      'INTERNET': 'Internet',
      'USE_BIOMETRIC': 'Vingerafdruk',
      'POST_NOTIFICATIONS': 'Meldingen',
      'VIBRATE': 'Trillen',
      'SCHEDULE_EXACT_ALARM': 'Wekkers en herinneringen',
      'POST_PROMOTED_NOTIFICATIONS': 'Live-meldingen',
      'WAKE_LOCK': 'Wakker houden',
      'RECEIVE_BOOT_COMPLETED': 'Na het opstarten',
    };
    final policy = read(page);
    final declared = RegExp(
      r'uses-permission android:name="android\.permission\.([A-Z_]+)"',
    ).allMatches(read(manifest)).map((m) => m.group(1)!).toSet();

    for (final permission in declared) {
      expect(named, contains(permission), reason: '$permission is not named');
      expect(policy, contains(named[permission]!), reason: permission);
    }
    // Brought in by the QR scanner.
    expect(policy, contains('<td>Camera</td>'));
    expect(policy, contains('Netwerkstatus'));
  });

  test('it says who to ask, and the site and the manual point to it', () {
    final policy = read(page);
    expect(policy, contains('Kobe Vandenberk'));
    expect(policy, contains('mailto:kobe.vandenberk@gmail.com'));
    expect(policy, contains('Gezondheidsgegevens delen met de coach'));

    expect(read('docs/index.html'), contains('href="privacy.html"'));
    expect(read('docs/handleiding.html'), contains('href="privacy.html"'));
  });
}
