package com.flowa.flowa.blocking

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

/**
 * Lists the real launchable apps installed on the device (name + package +
 * icon), for the blocking settings screen. Replaces the old hardcoded catalog.
 */
object InstalledApps {

    private const val ICON_SIZE_PX = 96

    /** Launchable user-facing apps, sorted by name, excluding Flowa itself. */
    fun launchable(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(intent, 0)

        val seen = HashSet<String>()
        val apps = ArrayList<Map<String, Any?>>()
        for (info in resolved) {
            val pkg = info.activityInfo.packageName
            if (pkg == context.packageName) continue // never block ourselves
            if (!seen.add(pkg)) continue

            val label = info.loadLabel(pm).toString()
            val icon = runCatching { info.loadIcon(pm) }.getOrNull()
            apps.add(
                mapOf(
                    "packageName" to pkg,
                    "appName" to label,
                    "icon" to icon?.let { drawableToPng(it) },
                ),
            )
        }
        apps.sortBy { (it["appName"] as String).lowercase() }
        return apps
    }

    /** Rasterizes [drawable] to a small PNG byte array for Flutter. */
    private fun drawableToPng(drawable: Drawable): ByteArray? {
        return try {
            val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                Bitmap.createScaledBitmap(
                    drawable.bitmap,
                    ICON_SIZE_PX,
                    ICON_SIZE_PX,
                    true,
                )
            } else {
                val bmp = Bitmap.createBitmap(
                    ICON_SIZE_PX,
                    ICON_SIZE_PX,
                    Bitmap.Config.ARGB_8888,
                )
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bmp
            }
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
        } catch (_: Throwable) {
            null
        }
    }
}
