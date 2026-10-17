package be.fitlog.app

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The small FitLog window over whatever app is open, from Aanpassen or Coach in
 * the workout notification: the set's weight and reps, or a question to the
 * coach, without leaving Spotify for it.
 *
 * Its own Flutter engine (`panelMain`), in a task of its own so FitLog itself
 * does not come to the front, and transparent so the app below stays in view.
 * It reads and writes nothing itself: every question goes to the running app
 * (`relay`), which has the logbook open - one place that touches the
 * database, as everywhere else in FitLog. With the app gone, it says so.
 */
class WorkoutPanelActivity : FlutterFragmentActivity() {

    private var panel: MethodChannel? = null

    override fun getDartEntrypointFunctionName() = "panelMain"

    override fun getBackgroundMode() = FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(::onPanelCall)
        panel = channel
        current = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (current === panel) current = null
        panel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** Aanpassen while Coach is open, or the other way round. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        panel?.invokeMethod("mode", mode())
    }

    private fun mode() = intent.getStringExtra(EXTRA_MODE) ?: MODE_EDIT

    private fun onPanelCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "mode" -> result.success(mode())
            "relay" -> relay(call.arguments as? Map<*, *>, result)
            "close" -> {
                result.success(null)
                finish()
            }
            "openApp" -> {
                val route = (call.arguments as? Map<*, *>)?.get("route") as? String
                if (route != null) WorkoutLiveNotice.dart?.invokeMethod("open", mapOf("route" to route))
                packageManager.getLaunchIntentForPackage(packageName)?.let {
                    startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                result.success(null)
                finish()
            }
            else -> result.notImplemented()
        }
    }

    /** A question for the running app, and its answer back. */
    private fun relay(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val method = arguments?.get("method") as? String
        val dart = WorkoutLiveNotice.dart
        if (method == null || dart == null) {
            result.success(mapOf("closed" to true))
            return
        }
        val args = arguments["args"]
        if (method == "complete") {
            // The island shows the tick at the same moment as the panel.
            ((args as? Map<*, *>)?.get("setId") as? String)?.let {
                WorkoutLiveNotice.confirm(applicationContext, it)
            }
        }
        dart.invokeMethod(
            method,
            args,
            object : MethodChannel.Result {
                override fun success(answer: Any?) = result.success(answer)
                override fun error(code: String, message: String?, details: Any?) =
                    result.error(code, message, details)
                override fun notImplemented() = result.notImplemented()
            },
        )
    }

    companion object {
        const val CHANNEL = "be.fitlog.app/panel"
        const val EXTRA_MODE = "mode"
        const val MODE_EDIT = "edit"
        const val MODE_COACH = "coach"

        /** The open panel's channel, for what the app sends it unasked. */
        @Volatile
        var current: MethodChannel? = null

        /** Something the running app has for the open panel: the coach's answer. */
        fun event(arguments: Any?) {
            current?.invokeMethod("event", arguments)
        }

        fun intent(context: Context, mode: String): Intent =
            Intent(context, WorkoutPanelActivity::class.java)
                .putExtra(EXTRA_MODE, mode)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}
