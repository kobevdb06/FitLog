package be.fitlog.app

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Extends FlutterFragmentActivity (not FlutterActivity) because local_auth
 * requires a FragmentActivity host to show the biometric prompt.
 */
class MainActivity : FlutterFragmentActivity()
