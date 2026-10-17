package be.fitlog.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Afvinken in the island, and the end of a rest.
 *
 * A set is written by Dart, in the app that is running - FitLog does not lock
 * during a workout, so its logbook is open. The receiver keeps the process
 * awake (goAsync) until Dart answers, or gives up after a few seconds rather
 * than hold Android up.
 */
class WorkoutActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        when (intent.action) {
            WorkoutLiveNotice.ACTION_REST_OVER ->
                WorkoutLiveNotice.restOver(app, intent.getLongExtra(WorkoutLiveNotice.EXTRA_REST_ENDS_AT, 0))
            WorkoutLiveNotice.ACTION_TICK -> tick(app, intent.getStringExtra(WorkoutLiveNotice.EXTRA_SET_ID))
        }
    }

    private fun tick(context: Context, setId: String?) {
        if (setId == null) return
        val dart = WorkoutLiveNotice.dart
        if (dart == null) {
            WorkoutLiveNotice.closed(context)
            return
        }
        WorkoutLiveNotice.confirm(context, setId)

        val pending = goAsync()
        val main = Handler(Looper.getMainLooper())
        var done = false
        fun finish(ok: Boolean) {
            if (done) return
            done = true
            if (!ok) WorkoutLiveNotice.release(context)
            pending.finish()
        }
        main.postDelayed({ finish(ok = false) }, 8000)
        dart.invokeMethod(
            "tick",
            mapOf("setId" to setId),
            object : MethodChannel.Result {
                override fun success(result: Any?) = finish(ok = (result as? Map<*, *>)?.get("ticked") == true)
                override fun error(code: String, message: String?, details: Any?) = finish(ok = false)
                override fun notImplemented() = finish(ok = false)
            },
        )
    }
}
