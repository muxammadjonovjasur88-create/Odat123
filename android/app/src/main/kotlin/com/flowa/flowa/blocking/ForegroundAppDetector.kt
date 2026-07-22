package com.flowa.flowa.blocking

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context

/**
 * Determines the current foreground app via [UsageStatsManager] (the
 * Play-friendly alternative to an AccessibilityService).
 *
 * There is no push callback for usage events, so callers poll [current]
 * periodically. Requires the user to grant Usage Access (PACKAGE_USAGE_STATS).
 */
object ForegroundAppDetector {

    /** Look-back window for the most recent foreground event. */
    private const val WINDOW_MS = 10_000L

    /**
     * The package name of the app most recently moved to the foreground, or
     * null if it can't be determined (e.g. permission not granted).
     */
    fun current(context: Context): String? {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return null

        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - WINDOW_MS, now)
        val event = UsageEvents.Event()
        var latestPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            ) {
                latestPackage = event.packageName
            }
        }
        return latestPackage
    }
}
