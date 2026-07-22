package com.flowa.flowa.blocking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.flowa.flowa.focus.FocusForegroundService
import com.flowa.flowa.focus.FocusRuntime
import com.flowa.flowa.focus.FocusScheduler

/**
 * Restores an in-progress blocking or focus session after the device reboots.
 * If a saved session is still within its time window, its foreground service /
 * blocking state / exact alarm are re-established; otherwise the stale session
 * is cleared.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            return
        }

        // Pure blocking session.
        val endTime = SessionStore.endTime(context)
        if (endTime > System.currentTimeMillis()) {
            BlockerState.start(
                SessionStore.packages(context),
                SessionStore.startAt(context),
                endTime,
            )
            BlockingForegroundService.start(context, endTime)
        } else {
            SessionStore.clear(context)
        }

        // Background focus session.
        val now = System.currentTimeMillis()
        if (FocusRuntime.isActive(context) && FocusRuntime.endAt(context) > now) {
            if (FocusRuntime.startAt(context) <= now) {
                FocusForegroundService.startFromStore(context) // already running window
            } else {
                FocusScheduler.schedule(context, FocusRuntime.startAt(context))
            }
        } else if (FocusRuntime.isActive(context)) {
            FocusRuntime.clear(context)
        }
    }
}
