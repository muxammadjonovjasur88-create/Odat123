package com.flowa.flowa.blocking

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context

/**
 * Determines the current foreground app via [UsageStatsManager] (the
 * Play-friendly alternative to an AccessibilityService).
 */
object ForegroundAppDetector {

    private const val WINDOW_MS = 60_000L

    private val IGNORED_PACKAGES = setOf(
        "com.android.systemui",
        "android",
        "com.google.android.inputmethod.latin",
        "com.touchtype.swiftkey",
        "com.samsung.android.honeyboard",
        "com.sec.android.inputmethod",
        "com.miui.home",
        "com.sec.android.app.launcher",
        "com.google.android.apps.nexuslauncher",
        "com.huawei.android.launcher",
        "com.oppo.launcher",
        "com.vivo.launcher",
    )

    fun current(context: Context): String? {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? android.app.ActivityManager
        try {
            @Suppress("DEPRECATION")
            val topTask = am?.getRunningTasks(1)?.firstOrNull()?.topActivity?.packageName
            if (topTask != null && !IGNORED_PACKAGES.contains(topTask)) {
                return topTask
            }
        } catch (_: Throwable) {}

        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return null

        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - WINDOW_MS, now + 5000L)
        val event = UsageEvents.Event()
        var latestPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                event.eventType == 7 // USER_INTERACTION
            ) {
                val pkg = event.packageName
                if (pkg != null && !IGNORED_PACKAGES.contains(pkg)) {
                    latestPackage = pkg
                }
            }
        }

        if (latestPackage != null) return latestPackage

        val usageStats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - WINDOW_MS,
            now + 5000L,
        )
        return usageStats
            .filter { !IGNORED_PACKAGES.contains(it.packageName) }
            .maxByOrNull { it.lastTimeUsed }
            ?.packageName
    }
}
