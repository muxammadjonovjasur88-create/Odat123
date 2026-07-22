package com.flowa.flowa.blocking

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * Detects the foreground app instantly via accessibility window events (no
 * polling lag) and enforces blocking during an active focus session.
 *
 * When a blocked app comes to the foreground it (1) sends the user HOME via
 * [performGlobalAction] — which works even on MIUI where background overlay
 * launches are dropped — and (2) raises the calm [BlockingOverlayActivity] on
 * top, if allowed. The service must be enabled by the user in
 * Settings → Accessibility; once enabled Android keeps it running.
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "FlowaBlocker"

        /** Whether the service is currently connected (enabled + running). */
        @Volatile
        var running: Boolean = false
            private set
    }

    private var lastBlockAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        running = true
        Log.d(TAG, "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkg = event.packageName?.toString() ?: return
        // Log every foreground change so detection can be verified via logcat.
        Log.d(TAG, "Foreground app: $pkg (blocking=${BlockerState.inWindow()})")

        if (pkg == packageName) return
        if (!BlockerState.inWindow()) return
        if (BlockerState.shouldBlock(pkg)) {
            block(pkg)
        }
    }

    private fun block(pkg: String) {
        val now = SystemClock.elapsedRealtime()
        // Skip if the overlay is already up, and debounce rapid re-triggers.
        if (BlockerState.overlayShowing) return
        if (now - lastBlockAt < 800L) return
        lastBlockAt = now
        Log.d(TAG, "Blocking $pkg (strict=${BlockerState.strict})")

        // STRICT: leave the blocked app immediately (the hard wall). SOFT: do
        // NOT send the user home — just raise the gentle reminder over the app,
        // so "Open anyway" can return them to it. They never feel trapped.
        if (BlockerState.strict) {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }

        // Raise the Zen reminder overlay on top (if overlay permission allows).
        try {
            startActivity(
                Intent(this, BlockingOverlayActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TASK or
                            Intent.FLAG_ACTIVITY_NO_ANIMATION,
                    )
                    putExtra(BlockingOverlayActivity.EXTRA_BLOCKED_PACKAGE, pkg)
                },
            )
        } catch (t: Throwable) {
            Log.w(TAG, "Overlay launch failed: ${t.message}")
        }
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        running = false
        Log.d(TAG, "Accessibility service destroyed")
        super.onDestroy()
    }
}
