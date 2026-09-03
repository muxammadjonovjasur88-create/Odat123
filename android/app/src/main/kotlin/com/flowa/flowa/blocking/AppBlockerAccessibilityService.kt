package com.flowa.flowa.blocking

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Detects the foreground app instantly via accessibility window events (no
 * polling lag) and enforces blocking during an active focus session.
 *
 * Uses native [WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY] which draws
 * a hardware overlay directly over ANY blocked app on MIUI, Samsung, and pure Android
 * with ZERO background launch restrictions.
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "FlowaBlocker"

        @Volatile
        var running: Boolean = false
            private set

        @Volatile
        var instance: AppBlockerAccessibilityService? = null
            private set

        fun performHomeAction(): Boolean {
            return instance?.performGlobalAction(GLOBAL_ACTION_HOME) ?: false
        }
    }

    private var windowManager: WindowManager? = null
    private var activeOverlayView: View? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastBlockAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        running = true
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager

        // ── CRITICAL: Restore session after MIUI/Samsung kills & restarts the service ──
        // BlockerState is in-memory only. If the process was killed, all state is gone.
        // We rebuild it from the persisted SessionStore so blocking resumes immediately.
        if (!BlockerState.inWindow() && SessionStore.hasActiveSession(this)) {
            val pkgs = SessionStore.packages(this)
            val startAt = SessionStore.startAt(this)
            val endTime = SessionStore.endTime(this)
            val strict = SessionStore.strict(this)
            val lang = SessionStore.lang(this)
            if (pkgs.isNotEmpty()) {
                BlockerState.start(pkgs, startAt, endTime, strict = strict, lang = lang)
                Log.d(TAG, "Session restored from disk: ${pkgs.size} packages, strict=$strict, endTime=$endTime")
            }
        }

        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = (info.flags or
            AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
            AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
            AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS)
        info.notificationTimeout = 20
        serviceInfo = info

        mainHandler.removeCallbacks(watchdogRunnable)
        mainHandler.post(watchdogRunnable)

        Log.d(TAG, "Accessibility service connected. active=${BlockerState.active} inWindow=${BlockerState.inWindow()}")
    }

    private var wakeLock: android.os.PowerManager.WakeLock? = null

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager ?: return
        wakeLock = pm.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "Flowa:BlockerWakeLock").apply {
            setReferenceCounted(false)
            acquire(60 * 60 * 1000L)
        }
        Log.d(TAG, "WakeLock acquired for uninterrupted blocking")
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "WakeLock released")
            }
        } catch (_: Throwable) {}
    }

    fun startWatchdog() {
        acquireWakeLock()
        mainHandler.removeCallbacks(watchdogRunnable)
        mainHandler.post(watchdogRunnable)
        Log.d(TAG, "Watchdog explicitly started by BlockerState")
    }

    fun stopWatchdog() {
        mainHandler.removeCallbacks(watchdogRunnable)
        hideOverlay()
        releaseWakeLock()
        Log.d(TAG, "Watchdog explicitly stopped")
    }

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            try {
                if (BlockerState.inWindow()) {
                    var currentPkg: String? = null
                    
                    try {
                        currentPkg = rootInActiveWindow?.packageName?.toString()
                    } catch (_: Throwable) {}

                    if (currentPkg == null || currentPkg == "com.miui.home" || currentPkg == "com.android.systemui") {
                        try {
                            val activeWin = windows?.firstOrNull { it.isFocused || it.isActive }
                            val winPkg = activeWin?.root?.packageName?.toString()
                            if (winPkg != null) {
                                currentPkg = winPkg
                            }
                        } catch (_: Throwable) {}
                    }

                    if (currentPkg == null || currentPkg == "com.miui.home" || currentPkg == "com.android.systemui") {
                        currentPkg = ForegroundAppDetector.current(this@AppBlockerAccessibilityService)
                    }
                    
                    if (currentPkg != null && currentPkg != packageName && currentPkg != "com.miui.home" && currentPkg != "com.android.systemui") {
                        if (BlockerState.shouldBlock(currentPkg)) {
                            Log.d(TAG, "⚡ HIGH-FREQ WATCHDOG BLOCKED: $currentPkg (strict=${BlockerState.strict})")
                            if (BlockerState.strict) {
                                performGlobalAction(GLOBAL_ACTION_HOME)
                                try {
                                    val appIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    }
                                    if (appIntent != null) {
                                        startActivity(appIntent)
                                    }
                                } catch (_: Throwable) {}
                                hideOverlay()
                            } else {
                                showHardwareOverlay(currentPkg)
                            }
                        }
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "watchdog error: ${t.message}")
            } finally {
                mainHandler.postDelayed(this, 150L)
            }
        }
    }



    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val eventPkg = event.packageName?.toString()
            ?: rootInActiveWindow?.packageName?.toString()

        Log.d(TAG, "RAW A11Y: pkg=$eventPkg inWin=${BlockerState.inWindow()} shouldBlock=${BlockerState.shouldBlock(eventPkg)}")
        if (!BlockerState.inWindow() || eventPkg == null) {
            return
        }

        if (eventPkg == packageName) {
            // User returned to ODAT
            hideOverlay()
            return
        }

        // 2. If the foreground package is blocked, enforce strict mode or raise overlay.
        if (BlockerState.shouldBlock(eventPkg)) {
            Log.d(TAG, "Foreground app blocked: $eventPkg (strict=${BlockerState.strict})")
            
            // In strict mode, immediately execute HOME action and bring ODAT back to front with single timer
            if (BlockerState.strict) {
                performGlobalAction(GLOBAL_ACTION_HOME)
                try {
                    val appIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    if (appIntent != null) {
                        startActivity(appIntent)
                    }
                } catch (_: Throwable) {}
                hideOverlay()
            } else {
                mainHandler.post {
                    showHardwareOverlay(eventPkg)
                }
            }
        }
    }

    private fun showHardwareOverlay(blockedPackage: String) {
        val wm = windowManager ?: return
        
        // Remove stale view if it exists but is not attached
        activeOverlayView?.let { existing ->
            try {
                if (existing.isAttachedToWindow) return // already visible on screen
                wm.removeViewImmediate(existing)
            } catch (_: Throwable) {}
            activeOverlayView = null
        }

        try {
            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutType,
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.CENTER
            }

            val overlay = buildOverlayView(blockedPackage)
            wm.addView(overlay, params)
            activeOverlayView = overlay
            BlockerState.overlayShowing = true
            Log.d(TAG, "Hardware Accessibility Modal Overlay added successfully for $blockedPackage")
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to add hardware overlay: ${t.message}")
        }
    }

    fun hideOverlay() {
        if (activeOverlayView == null) return
        mainHandler.post {
            val view = activeOverlayView ?: return@post
            try {
                windowManager?.removeViewImmediate(view)
            } catch (_: Throwable) {}
            activeOverlayView = null
            BlockerState.overlayShowing = false
            Log.d(TAG, "Hardware Accessibility Overlay removed")
        }
    }

    private fun buildOverlayView(blockedPkg: String): View {
        val dp24 = dp(24)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xFF060B13.toInt()) // Stitch OLED Void Black
            setPadding(dp24, dp24, dp24, dp24)
            isClickable = true
            isFocusable = true
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        // Top Stitch Brand Badge
        val brandBadge = TextView(this).apply {
            text = "ODAT · ZEN KINETIC DISCIPLINE"
            setTextColor(0xFF00F3FF.toInt()) // Stitch Neon Cyan
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTypeface(Typeface.create("sans-serif-medium", Typeface.BOLD))
            gravity = Gravity.CENTER
            letterSpacing = 0.2f
            setPadding(dp(16), dp(6), dp(16), dp(6))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(20).toFloat()
                setColor(0x1A00F3FF.toInt())
                setStroke(dp(1), 0x4D00F3FF.toInt())
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(28) }
        }
        root.addView(brandBadge)

        // Center High-Tech Glowing Shield Emblem (No cheap emojis)
        val shieldEmblem = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            val size = dp(88)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                bottomMargin = dp(24)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0x1400F3FF.toInt())
                setStroke(dp(2), 0xFF00F3FF.toInt())
            }
        }

        val shieldInner = TextView(this).apply {
            text = "LOCK"
            setTextColor(0xFF00F3FF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(Typeface.create("sans-serif-black", Typeface.BOLD))
            gravity = Gravity.CENTER
            letterSpacing = 0.25f
        }
        shieldEmblem.addView(shieldInner)
        root.addView(shieldEmblem)

        // Main Title
        val title = TextView(this).apply {
            text = if (BlockerState.lang == "ru") "ДОСТУП ЗАБЛОКИРОВАН" else "ILOVA BLOKLANDI"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 21f)
            setTypeface(Typeface.create("sans-serif-black", Typeface.BOLD))
            gravity = Gravity.CENTER
            letterSpacing = 0.08f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(10) }
        }
        root.addView(title)

        // Subtitle
        val sub = TextView(this).apply {
            text = if (BlockerState.lang == "ru")
                "Режим Строгой Дисциплины активен.\nСессия продолжается — сосредоточьтесь на главном."
            else
                "Qat'iy Intizom rejimi faol.\nDiqqat seansi davom etmoqda — maqsadingizga e'tibor qarating."
            setTextColor(0xFF8E9BAE.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
            gravity = Gravity.CENTER
            setLineSpacing(dp(4).toFloat(), 1.0f)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(32) }
        }
        root.addView(sub)

        // Time Left Glassmorphic Card
        val timeCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(20), dp(24), dp(20))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(20).toFloat()
                setColor(0xFF0F1726.toInt())
                setStroke(dp(1), 0x3300F3FF.toInt())
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(36) }
        }

        val timeLabel = TextView(this).apply {
            text = if (BlockerState.lang == "ru") "ОСТАВШЕЕСЯ ВРЕМЯ ФОКУСА" else "QOLGAN FOKUS VAQTI"
            setTextColor(0xFF00F3FF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTypeface(Typeface.create("sans-serif-medium", Typeface.BOLD))
            letterSpacing = 0.15f
            gravity = Gravity.CENTER
        }
        timeCard.addView(timeLabel)

        val timeVal = TextView(this).apply {
            val remSec = (BlockerState.millisRemaining() / 1000).coerceAtLeast(0)
            val min = remSec / 60
            val sec = remSec % 60
            text = String.format("%02d:%02d", min, sec)
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 36f)
            setTypeface(Typeface.create("sans-serif-medium", Typeface.BOLD))
            gravity = Gravity.CENTER
            setPadding(0, dp(4), 0, 0)
        }
        timeCard.addView(timeVal)
        root.addView(timeCard)

        // Stitch Kinetic Action Button (Clean Cyberpunk Neon)
        val btn = Button(this).apply {
            text = if (BlockerState.lang == "ru") "ВЕРНУТЬСЯ В ODAT" else "ODAT ILOVASIGA QAYTISH"
            isAllCaps = false
            setTextColor(0xFF060B13.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14.5f)
            setTypeface(Typeface.create("sans-serif-black", Typeface.BOLD))
            letterSpacing = 0.08f
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                colors = intArrayOf(0xFF00F3FF.toInt(), 0xFF00D2DF.toInt())
                gradientType = GradientDrawable.LINEAR_GRADIENT
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(54),
            )
            setOnClickListener {
                hideOverlay()
                try {
                    val flowaIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    if (flowaIntent != null) {
                        startActivity(flowaIntent)
                    } else {
                        performGlobalAction(GLOBAL_ACTION_HOME)
                    }
                } catch (t: Throwable) {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                }
            }
        }
        root.addView(btn)

        return root
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onInterrupt() {}

    override fun onDestroy() {
        mainHandler.removeCallbacks(watchdogRunnable)
        running = false
        instance = null
        hideOverlay()
        Log.d(TAG, "Accessibility service destroyed")
        super.onDestroy()
    }
}
