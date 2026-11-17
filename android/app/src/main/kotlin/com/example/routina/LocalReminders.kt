package com.example.routina

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

internal object LocalReminders {
    const val CHANNEL = "planner_reminders"
    private const val PREFS = "routina_notification_queue"

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun recordPermissionRequest(context: Context) {
        preferences(context).edit().putBoolean("asked", true).apply()
    }

    fun permission(context: Context): String {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33) {
            val known = preferences(context).getBoolean("asked", false)
            if (context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                return if (known) "denied" else "notDetermined"
            }
            if (!known) recordPermissionRequest(context)
        }
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return "denied"
        if (Build.VERSION.SDK_INT >= 26 &&
            manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE
        ) return "denied"
        return "authorized"
    }

    private fun plan(context: Context) =
        JSONObject(preferences(context).getString("plan", "{}") ?: "{}")

    private fun save(context: Context, plan: JSONObject) {
        check(preferences(context).edit().putString("plan", plan.toString()).commit())
    }

    private fun bootCount(context: Context): Int =
        Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)

    private fun wallOffset(): Long = System.currentTimeMillis() - SystemClock.elapsedRealtime()

    // A timer goal uses an elapsed duration. A cached RTC estimate can fire
    // early after a wall-clock jump. Dart projects it again on resume.
    private fun validTimerClock(context: Context, plan: JSONObject, row: JSONObject): Boolean =
        row.optString("kind") != "timerGoal" ||
            (plan.has("wallOffset") && plan.optInt("bootCount", -2) == bootCount(context) &&
                kotlin.math.abs(wallOffset() - plan.getLong("wallOffset")) < 2000)

    private fun alarm(context: Context, id: String): PendingIntent =
        PendingIntent.getBroadcast(
            context, 0,
            Intent(context, ReminderReceiver::class.java)
                .setData(Uri.Builder().scheme("routina").authority("reminder").appendPath(id).build()),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

    private fun arm(context: Context, id: String, at: Long) {
        context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            maxOf(System.currentTimeMillis() + 1000, at),
            alarm(context, id)
        )
    }

    private fun cancel(context: Context, id: String) {
        context.getSystemService(AlarmManager::class.java).cancel(alarm(context, id))
        context.getSystemService(NotificationManager::class.java).cancel(id, 0)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Pengingat Routina", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
    }

    fun synchronize(context: Context, arguments: Map<*, *>, rebuild: Boolean) {
        val old = plan(context)
        val previous = old.optJSONObject("jobs") ?: JSONObject()
        val incoming = JSONObject(arguments)
        val jobs = JSONObject()
        val now = System.currentTimeMillis()
        val zone = TimeZone.getDefault().id
        val zoneChanged = old.optString("zone") != zone
        val requests = incoming.optJSONArray("reminders") ?: JSONArray()
        val rearm = mutableListOf<String>()
        if (permission(context) == "authorized") {
            ensureChannel(context)
            for (i in 0 until requests.length()) {
                val next = requests.getJSONObject(i)
                val id = next.getString("id")
                if (next.getLong("expires") <= now) continue
                val before = previous.optJSONObject(id)
                val sameTime = before != null && before.getLong("at") == next.getLong("at")
                val posted = before?.optBoolean("posted") == true &&
                    (sameTime || next.optString("kind") == "timerGoal")
                val wasArmed = sameTime && before!!.optBoolean("armed")
                val armed = wasArmed && !rebuild && validTimerClock(context, old, next) &&
                    !(zoneChanged && next.optBoolean("deviceTime"))
                next.put("posted", posted)
                next.put("armed", armed)
                jobs.put(id, next)
                if (!posted && !armed &&
                    (next.getLong("at") > now || next.optBoolean("catchUp") || wasArmed)
                ) rearm.add(id)
            }
        }
        val result = JSONObject().put("jobs", jobs).put("zone", zone)
            .put("bootCount", bootCount(context)).put("wallOffset", wallOffset())
            .put("quiet", incoming.opt("quiet") ?: JSONObject.NULL)
        // Persist eligibility before replacing alarms. An old broadcast that
        // reaches the receiver after this point uses the new eligibility.
        save(context, result)
        previous.keys().forEach { id ->
            val next = jobs.optJSONObject(id)
            if (next == null ||
                (!next.optBoolean("posted") && previous.getJSONObject(id).getLong("at") != next.getLong("at"))
            ) {
                cancel(context, id)
            }
        }
        for (id in rearm) {
            val job = jobs.getJSONObject(id)
            arm(context, id, job.getLong("at"))
            job.put("armed", true)
        }
        if (rearm.isNotEmpty()) save(context, result)
    }

    fun recover(context: Context) {
        val plan = plan(context)
        val jobs = plan.optJSONObject("jobs") ?: return
        val now = System.currentTimeMillis()
        val enabled = permission(context) == "authorized"
        var repaired = false
        jobs.keys().forEach { id ->
            val row = jobs.getJSONObject(id)
            if (enabled && !row.optBoolean("posted") &&
                (row.optBoolean("armed") || row.getLong("at") > now || row.optBoolean("catchUp")) &&
                row.getLong("expires") > now && validZone(plan, row) && validTimerClock(context, plan, row)
            ) {
                arm(context, id, row.getLong("at"))
                if (!row.optBoolean("armed")) {
                    row.put("armed", true)
                    repaired = true
                }
            } else if (!row.optBoolean("posted")) {
                context.getSystemService(AlarmManager::class.java).cancel(alarm(context, id))
            }
        }
        if (repaired) save(context, plan)
    }

    private fun validZone(plan: JSONObject, row: JSONObject) =
        !row.optBoolean("deviceTime") || plan.optString("zone") == TimeZone.getDefault().id

    private fun quietNow(plan: JSONObject, kind: String): Boolean {
        val quiet = plan.optJSONObject("quiet") ?: return false
        val exceptions = quiet.optJSONArray("exceptions") ?: JSONArray()
        if ((0 until exceptions.length()).any { exceptions.optString(it) == kind }) return false
        val clock = Calendar.getInstance()
        val minute = clock.get(Calendar.HOUR_OF_DAY) * 60 + clock.get(Calendar.MINUTE)
        val start = quiet.getInt("start")
        val end = quiet.getInt("end")
        return when {
            start < end -> minute in start until end
            start > end -> minute >= start || minute < end
            else -> false
        }
    }

    fun deliver(context: Context, id: String) {
        val plan = plan(context)
        val row = plan.optJSONObject("jobs")?.optJSONObject(id) ?: return
        val now = System.currentTimeMillis()
        if (row.optBoolean("posted") || now >= row.getLong("expires") ||
            !validZone(plan, row) || !validTimerClock(context, plan, row)
        ) return
        if (permission(context) != "authorized") return
        if (now < row.getLong("at")) {
            arm(context, id, row.getLong("at"))
            return
        }
        row.put("posted", true)
        save(context, plan)
        if (permission(context) != "authorized" || quietNow(plan, row.getString("kind"))) return

        val manager = context.getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            ensureChannel(context)
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setDefaults(Notification.DEFAULT_ALL)
        }
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        try {
            manager.notify(id, 0, builder
                .setContentTitle(row.getString("title"))
                .setContentText(row.getString("body"))
                .setSmallIcon(R.drawable.ic_stat_reminder)
                .setContentIntent(open)
                .setAutoCancel(true)
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .build())
        } catch (_: SecurityException) {
            // Permission can be revoked between the check and delivery.
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != null) {
            LocalReminders.recover(context)
        } else {
            intent.data?.lastPathSegment?.let { LocalReminders.deliver(context, it) }
        }
    }
}
