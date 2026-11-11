package be.fitlog.app

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * What keeps the PIN and the twelve words off other people's screens
 * (DECISIONS 265): no screenshots or recordings while a screen with them is
 * up, no picture in the recent apps with a PIN, and the twelve words on the
 * clipboard marked as sensitive and gone again after a minute.
 *
 * One channel in each engine that shows a PIN: the app's and the panel's.
 */
object ScreenGuard {
    const val CHANNEL = "be.fitlog.app/guard"

    private val main = Handler(Looper.getMainLooper())
    private var clear: Runnable? = null

    fun attach(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            handle(activity, call, result)
        }
    }

    private fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "secure" -> {
                if (call.arguments == true) {
                    activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
            "recents" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    activity.setRecentsScreenshotEnabled(call.arguments == true)
                }
                result.success(null)
            }
            "copySecret" -> {
                val arguments = call.arguments as? Map<*, *>
                val text = arguments?.get("text") as? String
                val after = (arguments?.get("clearAfterMs") as? Number)?.toLong()
                if (text == null || after == null) {
                    result.error("arguments", "copySecret needs text and clearAfterMs", null)
                    return
                }
                copySecret(activity.applicationContext, text, after)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Marked as sensitive, Android 13 and later leave it out of the preview
     * that comes up after a copy, and keyboards out of their suggestions.
     *
     * It goes again after [clearAfterMs], whatever is on the clipboard by
     * then: in the background Android lets FitLog see nothing of it, so it
     * cannot tell the twelve words from what was copied after them. Copied
     * from another app within that minute, that goes too - a smaller loss
     * than the words lying there until the next copy.
     */
    private fun copySecret(context: Context, text: String, clearAfterMs: Long) {
        val clipboard = context.getSystemService(ClipboardManager::class.java) ?: return
        val clip = ClipData.newPlainText("FitLog", text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    ClipDescription.EXTRA_IS_SENSITIVE
                } else {
                    "android.content.extra.IS_SENSITIVE"
                },
                true,
            )
        }
        clipboard.setPrimaryClip(clip)

        clear?.let(main::removeCallbacks)
        val task = Runnable {
            clear = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                clipboard.clearPrimaryClip()
            } else {
                clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
            }
        }
        clear = task
        main.postDelayed(task, clearAfterMs)
    }
}
