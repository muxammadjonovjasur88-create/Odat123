package com.flowa.flowa.blocking

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import com.flowa.flowa.MainActivity
import com.flowa.flowa.R

/**
 * Keeps the focus/blocking session alive with an ongoing notification, polls
 * the foreground app via [ForegroundAppDetector] (Usage Access), and shows the
 * blocking overlay when a blocked app is opened. Auto-stops when the session's
 * end time is reached. Started/stopped from the Flutter MethodChannel via
 * [start] / [stop].
 */
class BlockingForegroundService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var autoStop: Runnable? = null

    private val poller = object : Runnable {
        override fun run() {
            detectAndBlock()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    companion object {
        private const val CHANNEL_ID = "flowa_focus_blocking"
        private const val NOTIFICATION_ID = 4711
        private const val EXTRA_END_TIME = "endTime"

        /** How often to check the foreground app. */
        private const val POLL_INTERVAL_MS = 800L

        fun start(context: Context, endTime: Long) {
            val intent = Intent(context, BlockingForegroundService::class.java)
                .putExtra(EXTRA_END_TIME, endTime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BlockingForegroundService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        val endTime = intent?.getLongExtra(EXTRA_END_TIME, 0L) ?: 0L
        scheduleAutoStop(endTime)

        // Begin watching the foreground app for this session.
        handler.removeCallbacks(poller)
        handler.post(poller)
        return START_STICKY
    }

    /** One poll: if a blocked app is in front, raise the blocking overlay. */
    private fun detectAndBlock() {
        // Defer to the accessibility service when it's enabled (instant + no lag).
        if (AppBlockerAccessibilityService.running) return
        if (!BlockerState.active || BlockerState.isExpired()) return
        if (BlockerState.overlayShowing) return

        val pkg = ForegroundAppDetector.current(this) ?: return
        if (pkg == packageName) return // never block ourselves / the overlay

        if (BlockerState.shouldBlock(pkg)) {
            // Optimistically guard against a double-launch before onResume runs.
            BlockerState.overlayShowing = true
            val intent = Intent(this, BlockingOverlayActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION,
                )
            }
            startActivity(intent)
        }
    }

    private fun scheduleAutoStop(endTime: Long) {
        autoStop?.let { handler.removeCallbacks(it) }
        val delay = (endTime - System.currentTimeMillis()).coerceAtLeast(0L)
        autoStop = Runnable {
            BlockerState.stop()
            SessionStore.clear(applicationContext)
            stopSelf()
        }.also { handler.postDelayed(it, delay) }
    }

    override fun onDestroy() {
        autoStop?.let { handler.removeCallbacks(it) }
        handler.removeCallbacks(poller)
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("Focus session active")
            .setContentText("Helping you stay focused until you're finished.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Focus sessions",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while distracting apps are blocked."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }
}
