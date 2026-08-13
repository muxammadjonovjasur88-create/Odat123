package com.flowa.flowa.focus

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.flowa.flowa.blocking.BlockerState

/**
 * Fired by the exact alarm at a session's scheduled start time. Starts the
 * [FocusForegroundService] from the persisted session record. Because this is
 * triggered by an exact alarm, starting a foreground service from the
 * background is permitted even on Android 12+.
 *
 * IMPORTANT: BlockerState is armed HERE — before the foreground service even
 * starts — so that [AppBlockerAccessibilityService] reacts instantly to any
 * window-state change without waiting for the service's onCreate/onStartCommand
 * latency (which can be 2–5 s on restricted OEMs such as MIUI/ColorOS).
 */
class FocusAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "FlowaAlarmRcv"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != FocusScheduler.ACTION_FOCUS_ALARM) return

        val endAt = FocusRuntime.endAt(context)
        val now = System.currentTimeMillis()

        // Guard: only proceed when there is a valid, non-expired session.
        if (!FocusRuntime.isActive(context) || endAt <= now) {
            Log.w(TAG, "onReceive: no active session or already expired — ignoring")
            return
        }

        // ── STEP 1: Arm BlockerState IMMEDIATELY ──────────────────────────────
        // This happens synchronously in the BroadcastReceiver, before the
        // foreground service process even starts. AppBlockerAccessibilityService
        // (if enabled) will therefore react to the very next window-state event
        // with zero extra latency.
        val packages = FocusRuntime.packages(context)
        val startAt  = FocusRuntime.startAt(context)
        val title    = FocusRuntime.title(context)
        val strict   = FocusRuntime.strict(context)
        val lang     = FocusRuntime.lang(context)

        BlockerState.start(packages, startAt, endAt, title, strict, lang)
        Log.d(TAG, "onReceive: BlockerState armed immediately " +
            "(packages=${packages.size} strict=$strict inWindow=${BlockerState.inWindow()})")

        // ── STEP 2: Start the foreground service ──────────────────────────────
        // The service will call BlockerState.start() again in onStartCommand —
        // that is harmless and keeps it as the single source of truth once alive.
        FocusForegroundService.startFromStore(context)
    }
}
