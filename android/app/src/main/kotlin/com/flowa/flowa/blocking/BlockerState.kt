package com.flowa.flowa.blocking

import java.util.Collections

/**
 * Process-wide state for an active focus/blocking session.
 *
 * Shared between the [AppBlockerAccessibilityService] (which reads the
 * foreground app), the [BlockingForegroundService] (which keeps the session
 * alive), and the MethodChannel in MainActivity (which starts/stops it from
 * Flutter). Kept as a simple singleton because Android may hold the
 * accessibility service in a separate component from the Flutter engine.
 */
object BlockerState {

    @Volatile
    var active: Boolean = false
        private set

    /** Epoch millis when blocking begins (e.g. 5 min before the task). */
    @Volatile
    var startAtMillis: Long = 0L
        private set

    /** Epoch millis when the session ends; apps unblock automatically after. */
    @Volatile
    var endTimeMillis: Long = 0L

    /** Set while the blocking overlay is on screen, to avoid relaunch loops. */
    @Volatile
    var overlayShowing: Boolean = false

    /** The current task's title, shown on the blocking overlay. */
    @Volatile
    var taskTitle: String = ""
        private set

    /**
     * When true, blocked apps are a HARD wall (old behavior). When false (the
     * default), the overlay is a gentle "soft friction" reminder the user can
     * choose to bypass.
     */
    @Volatile
    var strict: Boolean = false
        private set

    /** App language for the overlay copy ('en' | 'ru' | 'uz'). */
    @Volatile
    var lang: String = "en"
        private set

    private val blockedPackages: MutableSet<String> =
        Collections.synchronizedSet(mutableSetOf())

    /** Apps the user chose "Open anyway" for — not re-blocked this session. */
    private val bypassed: MutableSet<String> =
        Collections.synchronizedSet(mutableSetOf())

    fun start(
        packages: List<String>,
        startAt: Long,
        endTime: Long,
        title: String = "",
        strict: Boolean = false,
        lang: String = "en",
    ) {
        synchronized(blockedPackages) {
            blockedPackages.clear()
            blockedPackages.addAll(packages)
        }
        synchronized(bypassed) { bypassed.clear() }
        startAtMillis = startAt
        endTimeMillis = endTime
        taskTitle = title
        this.strict = strict
        this.lang = lang
        active = true
        AppBlockerAccessibilityService.instance?.startWatchdog()
    }

    fun stop() {
        active = false
        startAtMillis = 0L
        endTimeMillis = 0L
        overlayShowing = false
        strict = false
        synchronized(blockedPackages) { blockedPackages.clear() }
        synchronized(bypassed) { bypassed.clear() }
        AppBlockerAccessibilityService.instance?.stopWatchdog()
    }

    /**
     * Lets [pkg] through for the rest of this session — set when the user taps
     * "Open anyway" on the soft-friction reminder, so they aren't re-blocked.
     */
    fun allow(pkg: String) {
        if (!strict) {
            bypassed.add(pkg)
        }
    }

    fun isExpired(): Boolean = active && System.currentTimeMillis() >= endTimeMillis

    /**
     * Updates only [endTimeMillis] (e.g. when the user taps "+5 min" / "−5 min").
     * Has no effect when blocking is not active.
     */
    fun extendEndTime(newEndMillis: Long) {
        if (!active) return
        endTimeMillis = newEndMillis
    }

    /** Whether we're inside the [startAtMillis, endTimeMillis) blocking window. */
    fun inWindow(): Boolean {
        if (!active) return false
        val now = System.currentTimeMillis()
        return now >= startAtMillis && now < endTimeMillis
    }

    fun millisRemaining(): Long =
        (endTimeMillis - System.currentTimeMillis()).coerceAtLeast(0L)

    /** True when [pkg] should be blocked right now (and not user-bypassed). */
    fun shouldBlock(pkg: String?): Boolean {
        if (pkg == null || !inWindow()) return false
        if (!strict && bypassed.contains(pkg)) return false
        if (strict) {
            // Anti-circumvention: Block phone settings and uninstaller while strict discipline is active
            if (pkg == "com.android.settings" ||
                pkg == "com.android.packageinstaller" ||
                pkg == "com.google.android.packageinstaller" ||
                pkg == "com.miui.securitycenter" ||
                pkg == "com.samsung.android.lool") {
                return true
            }
        }
        return synchronized(blockedPackages) { blockedPackages.contains(pkg) }
    }
}
