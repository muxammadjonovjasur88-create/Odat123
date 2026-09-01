package com.flowa.flowa.blocking

import android.content.Context

/**
 * Persists the active session (blocked packages + end time) so it can be
 * restored after a reboot by [BootReceiver] or after the Accessibility
 * Service is killed and restarted by MIUI/Samsung aggressive memory management.
 * Backed by SharedPreferences.
 */
object SessionStore {
    private const val PREFS = "flowa_blocking"
    private const val KEY_PACKAGES = "packages"
    private const val KEY_START_AT = "startAt"
    private const val KEY_END_TIME = "endTime"
    private const val KEY_STRICT = "strict"
    private const val KEY_LANG = "lang"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(
        context: Context,
        packages: List<String>,
        startAt: Long,
        endTime: Long,
        strict: Boolean = false,
        lang: String = "uz",
    ) {
        prefs(context).edit()
            .putStringSet(KEY_PACKAGES, packages.toSet())
            .putLong(KEY_START_AT, startAt)
            .putLong(KEY_END_TIME, endTime)
            .putBoolean(KEY_STRICT, strict)
            .putString(KEY_LANG, lang)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun startAt(context: Context): Long =
        prefs(context).getLong(KEY_START_AT, 0L)

    fun endTime(context: Context): Long =
        prefs(context).getLong(KEY_END_TIME, 0L)

    fun packages(context: Context): List<String> =
        prefs(context).getStringSet(KEY_PACKAGES, emptySet())?.toList() ?: emptyList()

    fun strict(context: Context): Boolean =
        prefs(context).getBoolean(KEY_STRICT, false)

    fun lang(context: Context): String =
        prefs(context).getString(KEY_LANG, "uz") ?: "uz"

    /** Returns true if there is an unexpired session stored on disk. */
    fun hasActiveSession(context: Context): Boolean {
        val end = endTime(context)
        return end > 0L && System.currentTimeMillis() < end
    }
}
