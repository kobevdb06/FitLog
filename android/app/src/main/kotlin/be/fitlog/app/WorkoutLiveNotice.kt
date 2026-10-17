package be.fitlog.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.MethodChannel

/**
 * The notification that stands while a workout runs, drawn here rather than by
 * the notification plugin because the plugin cannot ask for what makes it a
 * Live Update: promotion, the short text of the status bar chip, and the bar
 * with a segment per set. On Android 16 the system then shows it in the
 * status bar - and a OnePlus, Samsung or Xiaomi in its island.
 *
 * What it shows comes from Dart (`WorkoutLiveUpdate`), already worked out and
 * worded. This side only lays it out, and does the two things that cannot
 * wait for Dart: the moment a set is ticked off, and the end of a rest while
 * the app may be frozen in the background.
 */
object WorkoutLiveNotice {
    const val CHANNEL_ID = "fitlog_workout"

    /** The plugin used the same id; posting here replaces what it put up. */
    const val NOTIFICATION_ID = 1002

    const val ACTION_TICK = "be.fitlog.app.workout.TICK"
    const val ACTION_REST_OVER = "be.fitlog.app.workout.REST_OVER"
    const val EXTRA_SET_ID = "setId"
    const val EXTRA_REST_ENDS_AT = "restEndsAt"

    /** How long "Set 3 van 4 afgevinkt" stays before the next set comes. */
    private const val CONFIRM_MS = 1200L

    private val ACCENT = Color.parseColor("#3D7DFF")
    private val DONE = Color.parseColor("#1F9D55")
    private val SKIPPED = Color.parseColor("#7A808A")

    /** Dart's side, while the app runs; null once the engine is gone. */
    @Volatile
    var dart: MethodChannel? = null

    /** The last notice Dart sent, kept to redraw it without asking again. */
    private var latest: Map<*, *>? = null

    /** Until when a confirmation stays up; a newer notice waits for it. */
    private var holdUntil = 0L

    private val main = Handler(Looper.getMainLooper())
    private var waiting: Runnable? = null

    fun show(context: Context, notice: Map<*, *>) {
        latest = notice
        val wait = holdUntil - SystemClock.uptimeMillis()
        if (wait > 0) {
            later(context, wait)
            return
        }
        post(context, notice, confirming = false)
    }

    fun cancel(context: Context) {
        latest = null
        waiting?.let(main::removeCallbacks)
        waiting = null
        restAlarm(context, null)
        manager(context).cancel(NOTIFICATION_ID)
    }

    /**
     * The tap on Afvinken, answered before Dart is: a tick, the segment
     * filled, and then - once Dart has the next set - the next set.
     */
    fun confirm(context: Context, setId: String) {
        val notice = latest ?: return
        val set = notice["set"] as? Map<*, *> ?: return
        if (set["id"] != setId) return
        holdUntil = SystemClock.uptimeMillis() + CONFIRM_MS
        post(context, notice, confirming = true)
        later(context, CONFIRM_MS)
    }

    /** Dart could not tick it off after all: show the set again. */
    fun release(context: Context) {
        holdUntil = 0L
        latest?.let { show(context, it) }
    }

    /**
     * The app is gone - Android closed it - and a tap from here has nothing to
     * write to. Said in the notification, which opens FitLog when tapped.
     */
    fun closed(context: Context) {
        val notice = latest
        val builder = base(context)
            .setContentTitle("FitLog is gesloten")
            .setContentText("Tik om je workout verder te zetten.")
        if (notice != null) builder.setSubText(notice["title"] as? String)
        manager(context).notify(NOTIFICATION_ID, builder.build())
    }

    /** The alarm at the end of a rest: the island shows what to lift again. */
    fun restOver(context: Context, endsAt: Long) {
        val notice = latest ?: return
        if ((notice["restEndsAt"] as? Number)?.toLong() != endsAt) return
        show(context, notice)
    }

    private fun later(context: Context, delay: Long) {
        waiting?.let(main::removeCallbacks)
        val run = Runnable {
            waiting = null
            holdUntil = 0L
            latest?.let { post(context, it, confirming = false) }
        }
        waiting = run
        main.postDelayed(run, delay)
    }

    private fun post(context: Context, notice: Map<*, *>, confirming: Boolean) {
        val now = System.currentTimeMillis()
        val set = notice["set"] as? Map<*, *>
        val startedAt = (notice["startedAt"] as Number).toLong()
        val restEndsAt = (notice["restEndsAt"] as? Number)?.toLong()?.takeIf { it > now }
        val title = notice["title"] as String

        val builder = base(context).setSubText(title)
        val chip: String?
        when {
            set != null && confirming -> {
                builder
                    .setContentTitle("${set["label"]} afgevinkt")
                    .setContentText(line(set["exercise"], set["values"]))
                    .setWhen(startedAt)
                chip = "✓"
            }
            set != null && restEndsAt != null -> {
                builder
                    .setContentTitle("Rust")
                    .setContentText("Hierna: " + line(set["exercise"], set["label"], set["values"]))
                    .setWhen(restEndsAt)
                    .setChronometerCountDown(true)
                chip = null
            }
            set != null -> {
                builder
                    .setContentTitle(set["exercise"] as String)
                    .setContentText(line(set["label"], set["values"]))
                    .setWhen(startedAt)
                chip = set["chip"] as String
            }
            else -> {
                builder
                    .setContentTitle(title)
                    .setContentText(notice["body"] as String)
                    .setWhen(startedAt)
                chip = null
            }
        }

        if (set != null) bar(context, builder, set, confirming)
        if (set != null && !confirming) actions(context, builder, set)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            // What setRequestPromotedOngoing sets; that method only came with
            // 16 QPR1, the extra is read from 16 on.
            builder.extras.putBoolean("android.requestPromotedOngoing", true)
            if (chip != null) builder.setShortCriticalText(chip)
        }

        restAlarm(context, if (confirming) null else restEndsAt)
        manager(context).notify(NOTIFICATION_ID, builder.build())
    }

    /** The parts that are there, with a dot between them. */
    private fun line(vararg parts: Any?): String =
        parts.mapNotNull { (it as? String)?.takeIf(String::isNotBlank) }.joinToString(" · ")

    private fun base(context: Context): Notification.Builder {
        channel(context)
        return Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_fitlog)
            .setColor(ACCENT)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setCategory(Notification.CATEGORY_WORKOUT)
            .setContentIntent(openApp(context))
    }

    /** One segment per working set: done, skipped, or still to come. */
    private fun bar(context: Context, builder: Notification.Builder, set: Map<*, *>, confirming: Boolean) {
        val marks = (set["marks"] as? List<*>).orEmpty().map { it as String }.toMutableList()
        if (marks.isEmpty()) return
        val position = (set["position"] as? Number)?.toInt()
        if (confirming && position != null && position < marks.size) marks[position] = "done"
        val settled = marks.count { it != "open" }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            val style = Notification.ProgressStyle()
            for (mark in marks) {
                style.addProgressSegment(
                    Notification.ProgressStyle.Segment(1).setColor(
                        when (mark) {
                            "done" -> if (confirming) DONE else ACCENT
                            "skipped" -> SKIPPED
                            else -> ACCENT
                        },
                    ),
                )
            }
            style.setProgress(settled)
            // A dot of FitLog's own: without one a OnePlus draws a paper plane.
            style.setProgressTrackerIcon(Icon.createWithResource(context, R.drawable.ic_progress_tracker))
            builder.setStyle(style)
        } else {
            builder.setProgress(marks.size, settled, false)
        }
    }

    /** Coach, for every set: a question needs no values to go with it. */
    private fun coach(context: Context): Notification.Action =
        Notification.Action.Builder(
            Icon.createWithResource(context, R.drawable.ic_stat_fitlog),
            "Coach",
            PendingIntent.getActivity(
                context,
                4,
                WorkoutPanelActivity.intent(context, WorkoutPanelActivity.MODE_COACH),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        ).build()

    private fun actions(context: Context, builder: Notification.Builder, set: Map<*, *>) {
        if (set["outside"] != true) {
            builder.addAction(coach(context))
            return
        }
        builder.addAction(
            Notification.Action.Builder(
                Icon.createWithResource(context, R.drawable.ic_stat_fitlog),
                // Short: three buttons share the width of a phone with
                // large text, and Android cuts what does not fit.
                "Wijzig",
                PendingIntent.getActivity(
                    context,
                    3,
                    WorkoutPanelActivity.intent(context, WorkoutPanelActivity.MODE_EDIT),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            ).build(),
        )
        val tick = PendingIntent.getBroadcast(
            context,
            1,
            Intent(context, WorkoutActionReceiver::class.java)
                .setAction(ACTION_TICK)
                .putExtra(EXTRA_SET_ID, set["id"] as String),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        builder.addAction(
            Notification.Action.Builder(
                Icon.createWithResource(context, R.drawable.ic_stat_fitlog),
                "Klaar",
                tick,
            ).build(),
        )
        builder.addAction(coach(context))
    }

    /**
     * Wakes the receiver when the rest is over, so the island stops at zero
     * and shows the set again even while the app is frozen. To the second
     * when that is allowed (Rusttimer op de seconde), otherwise when Android
     * gets round to it.
     */
    private fun restAlarm(context: Context, endsAt: Long?) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = Intent(context, WorkoutActionReceiver::class.java).setAction(ACTION_REST_OVER)
        if (endsAt == null) {
            PendingIntent.getBroadcast(
                context,
                2,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )?.let(alarms::cancel)
            return
        }
        val pending = PendingIntent.getBroadcast(
            context,
            2,
            intent.putExtra(EXTRA_REST_ENDS_AT, endsAt),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        if (exact) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endsAt, pending)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endsAt, pending)
        }
    }

    private fun openApp(context: Context): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, FitLogActivity::class.java)
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** The channel the plugin made; made here too, the same, when it is not. */
    private fun channel(context: Context) {
        val manager = manager(context)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Lopende workout", NotificationManager.IMPORTANCE_LOW)
                .apply {
                    description = "Blijft staan zolang je workout bezig is, met je oefening, " +
                        "je set en je resterende rust."
                    setSound(null, null)
                    enableVibration(false)
                },
        )
    }

    private fun manager(context: Context) =
        context.getSystemService(NotificationManager::class.java)
}
