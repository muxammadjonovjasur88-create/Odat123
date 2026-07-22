package com.flowa.flowa.focus

import android.content.Context
import io.flutter.plugin.common.EventChannel

/**
 * Process-wide state for the background focus session, plus the live
 * [EventChannel] sink used to push ticks to Flutter. The session record and the
 * live "honest focus" integrity signals are persisted to SharedPreferences so
 * they survive process death and reboot, and so points can be scored even if
 * the app was closed when the session ended.
 */
object FocusRuntime {
    private const val PREFS = "flowa_focus"
    private const val KEY_ACTIVE = "active"
    private const val KEY_TASK_ID = "taskId"
    private const val KEY_TITLE = "title"
    private const val KEY_START = "startAt"
    private const val KEY_END = "endAt"
    private const val KEY_PACKAGES = "packages"
    private const val KEY_STRICT = "strict"
    private const val KEY_LANG = "lang"

    // Live integrity signals for the running session.
    private const val KEY_DISTRACTING = "distractingOpens"
    private const val KEY_AWAY_COUNT = "awayCount"
    private const val KEY_AWAY_SECONDS = "awaySeconds"

    // Pending completion record (a finished session awaiting point-scoring).
    private const val KEY_P_TASK = "pendingTaskId"
    private const val KEY_P_COMPLETED = "pendingCompleted"
    private const val KEY_P_DISTRACTING = "pendingDistracting"
    private const val KEY_P_AWAY_COUNT = "pendingAwayCount"
    private const val KEY_P_AWAY_SECONDS = "pendingAwaySeconds"
    private const val KEY_P_TOTAL = "pendingTotalSeconds"

    /** Set by MainActivity while Flutter is listening to the event channel. */
    @Volatile
    var eventSink: EventChannel.EventSink? = null

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(
        context: Context,
        taskId: String,
        title: String,
        startAt: Long,
        endAt: Long,
        packages: List<String>,
        strict: Boolean = false,
        lang: String = "en",
    ) {
        prefs(context).edit()
            .putBoolean(KEY_ACTIVE, true)
            .putString(KEY_TASK_ID, taskId)
            .putString(KEY_TITLE, title)
            .putLong(KEY_START, startAt)
            .putLong(KEY_END, endAt)
            .putStringSet(KEY_PACKAGES, packages.toSet())
            .putBoolean(KEY_STRICT, strict)
            .putString(KEY_LANG, lang)
            // Fresh session → reset integrity signals.
            .putInt(KEY_DISTRACTING, 0)
            .putInt(KEY_AWAY_COUNT, 0)
            .putInt(KEY_AWAY_SECONDS, 0)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit()
            .remove(KEY_ACTIVE)
            .remove(KEY_TASK_ID)
            .remove(KEY_TITLE)
            .remove(KEY_START)
            .remove(KEY_END)
            .remove(KEY_PACKAGES)
            .remove(KEY_STRICT)
            .remove(KEY_LANG)
            .remove(KEY_DISTRACTING)
            .remove(KEY_AWAY_COUNT)
            .remove(KEY_AWAY_SECONDS)
            .apply()
    }

    fun isActive(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ACTIVE, false)

    fun taskId(context: Context): String? =
        prefs(context).getString(KEY_TASK_ID, null)

    fun title(context: Context): String =
        prefs(context).getString(KEY_TITLE, "Focus") ?: "Focus"

    fun startAt(context: Context): Long = prefs(context).getLong(KEY_START, 0L)

    fun endAt(context: Context): Long = prefs(context).getLong(KEY_END, 0L)

    fun packages(context: Context): List<String> =
        prefs(context).getStringSet(KEY_PACKAGES, emptySet())?.toList() ?: emptyList()

    fun strict(context: Context): Boolean =
        prefs(context).getBoolean(KEY_STRICT, false)

    fun lang(context: Context): String =
        prefs(context).getString(KEY_LANG, "en") ?: "en"

    fun remainingSeconds(context: Context): Int {
        val ms = endAt(context) - System.currentTimeMillis()
        return (ms / 1000).coerceAtLeast(0L).toInt()
    }

    fun totalSeconds(context: Context): Int =
        ((endAt(context) - startAt(context)) / 1000).coerceAtLeast(0L).toInt()

    fun hasStarted(context: Context): Boolean =
        System.currentTimeMillis() >= startAt(context)

    fun isExpired(context: Context): Boolean =
        isActive(context) && System.currentTimeMillis() >= endAt(context)

    /** Status string mirrored to Flutter. */
    fun status(context: Context): String = when {
        !isActive(context) -> "idle"
        isExpired(context) -> "finished"
        !hasStarted(context) -> "waiting"
        else -> "running"
    }

    // ---- Integrity signals --------------------------------------------------

    fun distractingOpens(context: Context): Int =
        prefs(context).getInt(KEY_DISTRACTING, 0)

    fun awayCount(context: Context): Int = prefs(context).getInt(KEY_AWAY_COUNT, 0)

    fun awaySeconds(context: Context): Int =
        prefs(context).getInt(KEY_AWAY_SECONDS, 0)

    fun incDistractingOpens(context: Context) {
        prefs(context).edit()
            .putInt(KEY_DISTRACTING, distractingOpens(context) + 1)
            .apply()
    }

    /** Records one tick spent in another app; [newTransition] starts a new leave. */
    fun recordAway(context: Context, newTransition: Boolean) {
        val e = prefs(context).edit()
            .putInt(KEY_AWAY_SECONDS, awaySeconds(context) + 1)
        if (newTransition) e.putInt(KEY_AWAY_COUNT, awayCount(context) + 1)
        e.apply()
    }

    /** Snapshot for the `getActiveSession` MethodChannel call. */
    fun snapshot(context: Context): Map<String, Any?>? {
        if (!isActive(context)) return null
        return mapOf(
            "taskId" to taskId(context),
            "title" to title(context),
            "startAt" to startAt(context),
            "endAt" to endAt(context),
            "remainingSeconds" to remainingSeconds(context),
            "status" to status(context),
            "distractingOpens" to distractingOpens(context),
            "awayCount" to awayCount(context),
            "awaySeconds" to awaySeconds(context),
        )
    }

    // ---- Pending completion (session ended while the app wasn't running) ----

    fun markCompleted(context: Context, taskId: String) {
        prefs(context).edit()
            .putString(KEY_P_TASK, taskId)
            .putBoolean(KEY_P_COMPLETED, true)
            .putInt(KEY_P_DISTRACTING, distractingOpens(context))
            .putInt(KEY_P_AWAY_COUNT, awayCount(context))
            .putInt(KEY_P_AWAY_SECONDS, awaySeconds(context))
            .putInt(KEY_P_TOTAL, totalSeconds(context))
            .apply()
    }

    /** The pending completion record (taskId + signals), or null. Clears it. */
    fun takePendingCompletion(context: Context): Map<String, Any?>? {
        val p = prefs(context)
        val id = p.getString(KEY_P_TASK, null) ?: return null
        val record = mapOf<String, Any?>(
            "taskId" to id,
            "completed" to p.getBoolean(KEY_P_COMPLETED, true),
            "distractingOpens" to p.getInt(KEY_P_DISTRACTING, 0),
            "awayCount" to p.getInt(KEY_P_AWAY_COUNT, 0),
            "awaySeconds" to p.getInt(KEY_P_AWAY_SECONDS, 0),
            "totalSeconds" to p.getInt(KEY_P_TOTAL, 0),
        )
        p.edit()
            .remove(KEY_P_TASK)
            .remove(KEY_P_COMPLETED)
            .remove(KEY_P_DISTRACTING)
            .remove(KEY_P_AWAY_COUNT)
            .remove(KEY_P_AWAY_SECONDS)
            .remove(KEY_P_TOTAL)
            .apply()
        return record
    }
}
