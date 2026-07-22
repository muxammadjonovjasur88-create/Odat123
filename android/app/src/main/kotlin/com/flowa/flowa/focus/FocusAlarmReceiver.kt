package com.flowa.flowa.focus

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by the exact alarm at a session's scheduled start time. Starts the
 * [FocusForegroundService] from the persisted session record. Because this is
 * triggered by an exact alarm, starting a foreground service from the
 * background is permitted even on Android 12+.
 */
class FocusAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != FocusScheduler.ACTION_FOCUS_ALARM) return
        // Only start if there is still a valid session whose end is in the future.
        if (FocusRuntime.isActive(context) &&
            FocusRuntime.endAt(context) > System.currentTimeMillis()
        ) {
            FocusForegroundService.startFromStore(context)
        }
    }
}
