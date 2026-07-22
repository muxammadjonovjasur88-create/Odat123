package com.flowa.flowa.focus

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Schedules an exact alarm that fires at a session's start time and broadcasts
 * to [FocusAlarmReceiver], which starts [FocusForegroundService] — even if the
 * app process is not running.
 */
object FocusScheduler {
    const val ACTION_FOCUS_ALARM = "com.flowa.flowa.action.FOCUS_ALARM"
    private const val REQUEST_CODE = 7312

    fun schedule(context: Context, startAt: Long) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val pi = pendingIntent(context)
        if (canScheduleExact(context)) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, startAt, pi)
        } else {
            // Fall back to an inexact (but still doze-friendly) alarm.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, startAt, pi)
        }
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        am.cancel(pendingIntent(context))
    }

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(AlarmManager::class.java) ?: return false
        return am.canScheduleExactAlarms()
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, FocusAlarmReceiver::class.java)
            .setAction(ACTION_FOCUS_ALARM)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
