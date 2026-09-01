package com.flowa.flowa.focus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import com.flowa.flowa.MainActivity
import com.flowa.flowa.R
import com.flowa.flowa.blocking.AppBlockerAccessibilityService
import com.flowa.flowa.blocking.BlockerState
import com.flowa.flowa.blocking.BlockingOverlayActivity
import com.flowa.flowa.blocking.ForegroundAppDetector

/**
 * The background owner of a focus session. It counts down to the session's end
 * time, updates an ongoing notification every second with the live remaining
 * time, keeps app blocking active, and streams ticks to Flutter via
 * [FocusRuntime.eventSink]. When the end time is reached it stops blocking,
 * removes the notification, records a pending completion (so the app can award
 * points), and stops itself.
 *
 * It is started either immediately (MethodChannel) or by [FocusAlarmReceiver]
 * at the scheduled time — even if the app process was not running.
 */
class FocusForegroundService : Service() {

    private val handler = Handler(Looper.getMainLooper())

    /** Whether the previous tick saw the user away (for "leave"/"return" edges). */
    private var wasAway = false

    /** Consecutive seconds spent away, for the gentle re-nudge cadence. */
    private var awayTicks = 0

    private var wakeLock: PowerManager.WakeLock? = null

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Flowa:FocusWakeLock").apply {
            setReferenceCounted(false)
            acquire(4 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Throwable) {}
    }

    private val ticker = object : Runnable {
        override fun run() {
            tick()
            handler.postDelayed(this, 1000L)
        }
    }

    private val fastBlocker = object : Runnable {
        override fun run() {
            try {
                if (BlockerState.inWindow()) {
                    val pkg = ForegroundAppDetector.current(this@FocusForegroundService)
                    if (pkg != null && pkg != packageName) {
                        if (BlockerState.shouldBlock(pkg)) {
                            Log.d(TAG, "FocusForegroundService FAST DETECT BLOCKED: $pkg (strict=${BlockerState.strict})")
                            if (BlockerState.strict) {
                                AppBlockerAccessibilityService.performHomeAction()
                                try {
                                    val appIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    }
                                    if (appIntent != null) startActivity(appIntent)
                                } catch (_: Throwable) {}
                            }
                            if (!BlockerState.overlayShowing) {
                                BlockerState.overlayShowing = true
                                startActivity(
                                    Intent(this@FocusForegroundService, BlockingOverlayActivity::class.java).addFlags(
                                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                            Intent.FLAG_ACTIVITY_CLEAR_TASK or
                                            Intent.FLAG_ACTIVITY_NO_ANIMATION,
                                    ),
                                )
                            }
                        } else {
                            BlockerState.overlayShowing = false
                        }
                    } else if (pkg == packageName) {
                        BlockerState.overlayShowing = false
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "fastBlocker error: ${t.message}")
            } finally {
                handler.postDelayed(this, 250L)
            }
        }
    }

    companion object {
        private const val TAG = "FlowaFocusSvc"
        private const val CHANNEL_ID = "flowa_focus_session"
        private const val NOTIFICATION_ID = 7311
        // Bumped to "_v2" so the custom sound applies on existing installs — a
        // channel's sound is immutable once created. The old id is deleted below.
        private const val NUDGE_CHANNEL_ID = "flowa_focus_nudge_v2"
        private const val OLD_NUDGE_CHANNEL_ID = "flowa_focus_nudge"
        private const val NUDGE_NOTIFICATION_ID = 7313

        /** Re-send the gentle nudge every N seconds while still away. */
        private const val NUDGE_REPEAT_SECONDS = 25

        const val EXTRA_TASK_ID = "taskId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_START = "startAt"
        const val EXTRA_END = "endAt"
        const val EXTRA_PACKAGES = "packages"
        const val EXTRA_STRICT = "strict"
        const val EXTRA_LANG = "lang"

        fun start(
            context: Context,
            taskId: String,
            title: String,
            startAt: Long,
            endAt: Long,
            packages: ArrayList<String>,
            strict: Boolean = false,
            lang: String = "en",
        ) {
            val intent = Intent(context, FocusForegroundService::class.java).apply {
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_START, startAt)
                putExtra(EXTRA_END, endAt)
                putStringArrayListExtra(EXTRA_PACKAGES, packages)
                putExtra(EXTRA_STRICT, strict)
                putExtra(EXTRA_LANG, lang)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Restart from a persisted session (alarm receiver / boot). */
        fun startFromStore(context: Context) {
            start(
                context,
                FocusRuntime.taskId(context) ?: return,
                FocusRuntime.title(context),
                FocusRuntime.startAt(context),
                FocusRuntime.endAt(context),
                ArrayList(FocusRuntime.packages(context)),
                FocusRuntime.strict(context),
                FocusRuntime.lang(context),
            )
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FocusForegroundService::class.java))
        }

        /**
         * Adjusts the session end time by [deltaMs] ms while the service is running.
         * Updates the persisted [FocusRuntime] endAt so the ticker immediately reads
         * the new deadline on its very next second, and updates [BlockerState] so
         * the blocking window tracks the extension/reduction.
         *
         * Called from the MethodChannel handler in response to the user tapping
         * "+5 min" / "−5 min" inside the Flutter UI.
         */
        fun adjustEndAt(context: Context, deltaMs: Long) {
            FocusRuntime.adjustEndAt(context, deltaMs)
            // Update BlockerState's end window to match the new deadline.
            val newEnd = FocusRuntime.endAt(context)
            BlockerState.extendEndTime(newEnd)
            Log.d(TAG, "adjustEndAt: deltaMs=$deltaMs → newEnd=$newEnd")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()

        if (intent != null && intent.hasExtra(EXTRA_END)) {
            val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: ""
            val title = intent.getStringExtra(EXTRA_TITLE) ?: "Focus"
            val startAt = intent.getLongExtra(EXTRA_START, System.currentTimeMillis())
            val endAt = intent.getLongExtra(EXTRA_END, System.currentTimeMillis())
            val packages = intent.getStringArrayListExtra(EXTRA_PACKAGES) ?: arrayListOf()
            val strict = intent.getBooleanExtra(EXTRA_STRICT, false)
            val lang = intent.getStringExtra(EXTRA_LANG) ?: "en"

            Log.d(TAG, "onStartCommand: taskId=$taskId title='$title' " +
                "packages=${packages.size} strict=$strict " +
                "startAt=$startAt endAt=$endAt")
            if (packages.isEmpty()) {
                Log.w(TAG, "onStartCommand: WARNING — packages list is EMPTY. No apps will be blocked!")
            } else {
                Log.d(TAG, "onStartCommand: blocking packages: $packages")
            }

            FocusRuntime.save(this, taskId, title, startAt, endAt, packages, strict, lang)
            // Activate app blocking for the whole session window. Soft-friction
            // (default) vs hard wall (strict) is read from BlockerState by the
            // overlay. Note: FocusAlarmReceiver may have already called this;
            // calling again is safe (idempotent) and ensures the service is the
            // authoritative owner once it is running.
            BlockerState.start(packages, startAt, endAt, title, strict, lang)
            Log.d(TAG, "BlockerState armed: active=${BlockerState.active} " +
                "inWindow=${BlockerState.inWindow()} " +
                "accessibilitySvcRunning=${AppBlockerAccessibilityService.running}")
        } else {
            Log.w(TAG, "onStartCommand: intent has no EXTRA_END — skipping BlockerState.start()")
        }

        acquireWakeLock()
        startForeground(NOTIFICATION_ID, buildNotification())
        handler.removeCallbacks(ticker)
        handler.post(ticker)
        handler.removeCallbacks(fastBlocker)
        handler.post(fastBlocker)
        // Kick the immediate-focus enforcement AFTER startForeground so we are
        // allowed to launch activities from the foreground context. Retry for up
        // to 3 seconds in case the OS hasn't fully propagated the window change.
        scheduleEnforceImmediateFocus(attemptsLeft = 3)
        return START_STICKY
    }

    /**
     * Schedules up to [attemptsLeft] attempts (1 s apart) to pull the user out
     * of a distracting app. Stops as soon as the user is no longer in a
     * blocked app, or all attempts are exhausted. The retry loop covers the
     * window between the alarm firing and the AccessibilityService / activity
     * manager fully registering the window change.
     */
    private fun scheduleEnforceImmediateFocus(attemptsLeft: Int) {
        if (attemptsLeft <= 0) return
        // Run the first attempt immediately; subsequent attempts after 1 s each.
        val delayMs = if (attemptsLeft == 3) 0L else 1000L
        handler.postDelayed({
            val stillBlocked = enforceImmediateFocus()
            if (stillBlocked) {
                // User is still in the blocked app — retry after 1 s.
                scheduleEnforceImmediateFocus(attemptsLeft - 1)
            }
        }, delayMs)
    }

    /**
     * Attempts to pull the user back to Flowa if they are currently in a
     * blocked app. Returns true if a blocked app was detected (so the caller
     * may retry), false if nothing needed to be done.
     */
    private fun enforceImmediateFocus(): Boolean {
        val currentPkg = ForegroundAppDetector.current(this) ?: return false
        if (currentPkg == packageName) return false
        if (!BlockerState.shouldBlock(currentPkg)) return false

        Log.d(TAG, "enforceImmediateFocus: user is in blocked app '$currentPkg' — pulling back")

        // First send them HOME to close the distracting app forcefully (works on MIUI)
        val sentHome = AppBlockerAccessibilityService.performHomeAction()
        if (!sentHome) {
            // Fallback if AccessibilityService is not running
            try {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            } catch (_: Exception) {}
        }

        // Immediately launch Flowa MainActivity
        try {
            val appIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(appIntent)
        } catch (_: Exception) {}

        return true  // blocked app was detected; caller should retry to confirm
    }

    private fun tick() {
        if (!FocusRuntime.isActive(this)) {
            stopNow()
            return
        }
        if (FocusRuntime.isExpired(this)) {
            complete()
            return
        }

        // Integrity signals: are they focused, or off in another app?
        trackAway()
        // Keep blocking enforced.
        detectAndBlock()

        // Update the ongoing notification + push a tick to Flutter (if listening).
        val remaining = FocusRuntime.remainingSeconds(this)
        val status = FocusRuntime.status(this)
        updateNotification(remaining, status)
        FocusRuntime.eventSink?.success(
            mapOf(
                "taskId" to FocusRuntime.taskId(this),
                "remainingSeconds" to remaining,
                "status" to status,
                "endAt" to FocusRuntime.endAt(this),
                "totalSeconds" to FocusRuntime.totalSeconds(this),
                "distractingOpens" to FocusRuntime.distractingOpens(this),
                "awayCount" to FocusRuntime.awayCount(this),
                "awaySeconds" to FocusRuntime.awaySeconds(this),
            ),
        )
    }

    /**
     * Tracks whether the user has left to ANOTHER app. Locking the phone /
     * turning the screen off is STAYING FOCUSED (they put the phone down to
     * study) — it does NOT break focus. Only actively switching to a different
     * app counts as away. While away during a running session, a gentle nudge
     * (soft vibration + notification) reminds them to come back; it stops the
     * moment they return.
     */
    private fun trackAway() {
        if (FocusRuntime.status(this) != "running") {
            if (wasAway) cancelNudge()
            wasAway = false
            awayTicks = 0
            return
        }

        val pm = getSystemService(PowerManager::class.java)
        val interactive = pm?.isInteractive ?: true
        val pkg = ForegroundAppDetector.current(this)
        // Away ONLY when the screen is on AND they're in another app. Screen
        // off/locked is treated as focused (phone put down to focus).
        val away = interactive && pkg != null && pkg != packageName

        if (away) {
            FocusRuntime.recordAway(this, newTransition = !wasAway)
            awayTicks++
            // Gentle nudge on leaving, then a soft reminder periodically.
            if (!wasAway || awayTicks % NUDGE_REPEAT_SECONDS == 0) {
                vibrateGently()
                postNudge()
            }
        } else {
            if (wasAway) cancelNudge()
            awayTicks = 0
        }
        wasAway = away
    }

    private fun postNudge() {
        val contentIntent = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NUDGE_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setContentTitle("Stay with your focus 🌱")
            .setContentText("Come back to your session — your focus is waiting.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true) // soft: chime once, then re-pulse gently
            .setContentIntent(contentIntent)
            .build()
        getSystemService(NotificationManager::class.java)
            .notify(NUDGE_NOTIFICATION_ID, notification)
    }

    private fun cancelNudge() {
        getSystemService(NotificationManager::class.java).cancel(NUDGE_NOTIFICATION_ID)
    }

    /** A short, low-amplitude buzz — gentle, never a harsh alarm. */
    private fun vibrateGently() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        } ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(140, 90))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(140)
            }
        } catch (_: Throwable) {
            // Vibration unavailable — the notification still nudges.
        }
    }

    private fun detectAndBlock() {
        if (!BlockerState.inWindow() || BlockerState.overlayShowing) return
        val pkg = ForegroundAppDetector.current(this) ?: return
        if (pkg == packageName) return
        if (BlockerState.shouldBlock(pkg)) {
            Log.d(TAG, "detectAndBlock: blocking $pkg via FocusForegroundService detector")
            if (BlockerState.strict) {
                AppBlockerAccessibilityService.performHomeAction()
            }
            BlockerState.overlayShowing = true
            startActivity(
                Intent(this, BlockingOverlayActivity::class.java).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION,
                ),
            )
        }
    }

    private fun complete() {
        val taskId = FocusRuntime.taskId(this)
        // Capture integrity signals before clearing the session.
        val distracting = FocusRuntime.distractingOpens(this)
        val awayCount = FocusRuntime.awayCount(this)
        val awaySeconds = FocusRuntime.awaySeconds(this)
        val total = FocusRuntime.totalSeconds(this)

        // Record a pending completion (with signals) so the app can score points
        // even if it was closed, then tell Flutter (if running) it finished.
        if (taskId != null) FocusRuntime.markCompleted(this, taskId)
        FocusRuntime.eventSink?.success(
            mapOf(
                "taskId" to taskId,
                "remainingSeconds" to 0,
                "status" to "finished",
                "totalSeconds" to total,
                "distractingOpens" to distracting,
                "awayCount" to awayCount,
                "awaySeconds" to awaySeconds,
            ),
        )

        BlockerState.stop()
        FocusRuntime.clear(this)
        stopNow()
    }

    private fun stopNow() {
        handler.removeCallbacks(ticker)
        handler.removeCallbacks(fastBlocker)
        releaseWakeLock()
        if (wasAway) cancelNudge()
        BlockerState.stop()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        handler.removeCallbacks(fastBlocker)
        releaseWakeLock()
        super.onDestroy()
    }

    // ---- Notification ----

    private fun buildNotification(
        remaining: Int = FocusRuntime.remainingSeconds(this),
        status: String = FocusRuntime.status(this),
    ): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val text = if (status == "waiting") {
            "Starts in ${format(remaining)}"
        } else {
            "${format(remaining)} left • distractions blocked"
        }

        return builder
            .setContentTitle(FocusRuntime.title(this))
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun updateNotification(remaining: Int, status: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(remaining, status))
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Focus session",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description =
                        "Live countdown while a focus session is running."
                    setShowBadge(false)
                    enableVibration(false)
                },
            )
        }
        // Retire the old (default-sound) channel so it doesn't linger in the
        // system settings now that the custom-sound v2 channel replaces it.
        manager.deleteNotificationChannel(OLD_NUDGE_CHANNEL_ID)
        if (manager.getNotificationChannel(NUDGE_CHANNEL_ID) == null) {
            // Soft custom chime (res/raw/focus_nudge.mp3) played as a gentle
            // notification — default importance for a soft heads-up, not an alarm.
            val soundUri = Uri.parse(
                "android.resource://$packageName/${R.raw.focus_nudge}",
            )
            val soundAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            manager.createNotificationChannel(
                NotificationChannel(
                    NUDGE_CHANNEL_ID,
                    "Odat diqqat rejimi",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Odat intizomi eslatmasi."
                    setShowBadge(false)
                    setSound(soundUri, soundAttrs)
                },
            )
        }
    }

    private fun format(totalSeconds: Int): String {
        val m = totalSeconds / 60
        val s = totalSeconds % 60
        return "%02d:%02d".format(m, s)
    }
}
