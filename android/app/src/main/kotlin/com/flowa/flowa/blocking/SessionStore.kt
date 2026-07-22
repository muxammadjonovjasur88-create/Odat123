package com.flowa.flowa.blocking

import android.content.Context

/**
 * Persists the active session (blocked packages + end time) so it can be
 * restored after a reboot by [BootReceiver]. Backed by SharedPreferences.
 */
object SessionStore {
    private const val PREFS = "flowa_blocking"
    private const val KEY_PACKAGES = "packages"
    private const val KEY_START_AT = "startAt"
    private const val KEY_END_TIME = "endTime"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(context: Context, packages: List<String>, startAt: Long, endTime: Long) {
        prefs(context).edit()
            .putStringSet(KEY_PACKAGES, packages.toSet())
            .putLong(KEY_START_AT, startAt)
            .putLong(KEY_END_TIME, endTime)
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
}
