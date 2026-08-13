package com.flowa.flowa

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import com.flowa.flowa.blocking.AppBlockerAccessibilityService
import com.flowa.flowa.blocking.BlockerState
import com.flowa.flowa.blocking.BlockingForegroundService
import com.flowa.flowa.blocking.InstalledApps
import com.flowa.flowa.blocking.SessionStore
import com.flowa.flowa.focus.FocusForegroundService
import com.flowa.flowa.focus.FocusRuntime
import com.flowa.flowa.focus.FocusScheduler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "FlowaMain"
    }

    private val blockingChannel = "flowa/blocking"
    private val focusChannel = "flowa/focus"
    private val focusEvents = "flowa/focus/events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // ---- App blocking (settings / permissions) ----
        MethodChannel(messenger, blockingChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSession" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val now = System.currentTimeMillis()
                    val startAt = call.argument<Number>("startAt")?.toLong() ?: now
                    val endTime = call.argument<Number>("endTime")?.toLong() ?: now
                    val strict = call.argument<Boolean>("strict") ?: false
                    val lang = call.argument<String>("lang") ?: "en"
                    Log.d(TAG, "[blocking/startSession] packages=${packages.size} startAt=$startAt endTime=$endTime strict=$strict lang=$lang")
                    Log.d(TAG, "[blocking/startSession] usageAccess=${hasUsageAccess()} a11y=${isAccessibilityServiceEnabled()} overlay=${android.provider.Settings.canDrawOverlays(this)}")
                    if (packages.isEmpty()) {
                        Log.w(TAG, "[blocking/startSession] WARNING: packages list is EMPTY — nothing to block!")
                    } else {
                        Log.d(TAG, "[blocking/startSession] packages=$packages")
                    }
                    BlockerState.start(packages, startAt, endTime, strict = strict, lang = lang)
                    Log.d(TAG, "[blocking/startSession] BlockerState armed: active=${BlockerState.active} inWindow=${BlockerState.inWindow()}")
                    SessionStore.save(this, packages, startAt, endTime)
                    BlockingForegroundService.start(this, endTime)
                    Log.d(TAG, "[blocking/startSession] BlockingForegroundService started")
                    result.success(true)
                }

                "stopSession" -> {
                    Log.d(TAG, "[blocking/stopSession] stopping blocking session")
                    BlockerState.stop()
                    SessionStore.clear(this)
                    BlockingForegroundService.stop(this)
                    Log.d(TAG, "[blocking/stopSession] done")
                    result.success(true)
                }

                "hasUsageAccess" -> result.success(hasUsageAccess())
                "openUsageAccessSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }

                "getInstalledApps" -> {
                    // Rasterizing icons is heavy — do it off the main thread.
                    Thread {
                        val apps = runCatching { InstalledApps.launchable(this) }
                            .getOrDefault(emptyList())
                        runOnUiThread { result.success(apps) }
                    }.start()
                }

                "isAccessibilityEnabled" ->
                    result.success(isAccessibilityServiceEnabled())
                "openAccessibilitySettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }

                "isMiui" -> result.success(isMiui())
                "openAutostartSettings" -> {
                    openAutostartSettings()
                    result.success(null)
                }
                "openMiuiOtherPermissions" -> {
                    openMiuiOtherPermissions()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // ---- Background focus session (foreground service + alarm) ----
        MethodChannel(messenger, focusChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleSession" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val title = call.argument<String>("title") ?: "Focus"
                    val now = System.currentTimeMillis()
                    val startAt = call.argument<Number>("startAt")?.toLong() ?: now
                    val endAt = call.argument<Number>("endAt")?.toLong() ?: now
                    val packages = ArrayList(
                        call.argument<List<String>>("packages") ?: emptyList(),
                    )
                    val strict = call.argument<Boolean>("strict") ?: false
                    val lang = call.argument<String>("lang") ?: "en"
                    Log.d(TAG, "[focus/scheduleSession] taskId=$taskId title='$title' " +
                        "packages=${packages.size} strict=$strict startAt=$startAt endAt=$endAt")
                    if (packages.isEmpty()) {
                        Log.w(TAG, "[focus/scheduleSession] WARNING: packages is EMPTY — no apps will be blocked!")
                    }
                    if (endAt <= now) {
                        Log.w(TAG, "[focus/scheduleSession] endAt is in the past — rejecting")
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    FocusRuntime.save(this, taskId, title, startAt, endAt, packages, strict, lang)
                    if (startAt <= now) {
                        // Begin right away; drop any previously-scheduled alarm.
                        Log.d(TAG, "[focus/scheduleSession] startAt<=now — starting FocusForegroundService immediately")
                        FocusScheduler.cancel(this)
                        FocusForegroundService.start(
                            this, taskId, title, startAt, endAt, packages, strict, lang,
                        )
                    } else {
                        // Wake up at the scheduled time, even if the app is closed.
                        Log.d(TAG, "[focus/scheduleSession] startAt is in future — scheduling alarm")
                        FocusScheduler.schedule(this, startAt)
                    }
                    result.success(true)
                }

                "stopSession" -> {
                    Log.d(TAG, "[focus/stopSession] stopping focus session")
                    FocusScheduler.cancel(this)
                    FocusForegroundService.stop(this)
                    BlockerState.stop()
                    FocusRuntime.clear(this)
                    Log.d(TAG, "[focus/stopSession] done")
                    result.success(true)
                }

                "getActiveSession" -> result.success(FocusRuntime.snapshot(this))
                "takePendingCompletion" ->
                    result.success(FocusRuntime.takePendingCompletion(this))
                "debugDistraction" -> {
                    // Test hook: simulate the user leaving to a distracting app.
                    FocusRuntime.incDistractingOpens(this)
                    FocusRuntime.recordAway(this, true)
                    result.success(true)
                }
                "adjustTime" -> {
                    // Flutter's +5 min / −5 min button: shift the native end time.
                    val deltaSeconds = call.argument<Number>("deltaSeconds")?.toLong() ?: 0L
                    val deltaMs = deltaSeconds * 1000L
                    Log.d(TAG, "[focus/adjustTime] deltaSeconds=$deltaSeconds")
                    if (!FocusRuntime.isActive(this)) {
                        Log.w(TAG, "[focus/adjustTime] no active session — ignoring")
                        result.success(false)
                    } else {
                        FocusForegroundService.adjustEndAt(this, deltaMs)
                        Log.d(TAG, "[focus/adjustTime] newEndAt=${FocusRuntime.endAt(this)}")
                        result.success(true)
                    }
                }

                "canScheduleExactAlarms" ->
                    result.success(FocusScheduler.canScheduleExact(this))
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:$packageName"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ---- Live ticks from the focus service to Flutter ----
        EventChannel(messenger, focusEvents).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    FocusRuntime.eventSink = events
                    // Push the current state immediately so the UI syncs on attach.
                    FocusRuntime.snapshot(this@MainActivity)?.let { events?.success(it) }
                }

                override fun onCancel(arguments: Any?) {
                    FocusRuntime.eventSink = null
                }
            },
        )
    }

    /** Whether the user granted Usage Access (PACKAGE_USAGE_STATS). */
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(AppOpsManager::class.java) ?: return false
        val mode = appOps.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Whether Flowa's accessibility blocking service is enabled by the user. */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = ComponentName(
            this,
            AppBlockerAccessibilityService::class.java,
        ).flattenToString()
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    /** Best-effort MIUI (Xiaomi) detection. */
    private fun isMiui(): Boolean {
        if (Build.MANUFACTURER.equals("Xiaomi", true) ||
            Build.MANUFACTURER.equals("Redmi", true) ||
            Build.BRAND.equals("Xiaomi", true) ||
            Build.BRAND.equals("Redmi", true)
        ) {
            return true
        }
        return try {
            val c = Class.forName("android.os.SystemProperties")
            val get = c.getMethod("get", String::class.java)
            val v = get.invoke(null, "ro.miui.ui.version.name") as? String
            v != null && v.isNotBlank()
        } catch (_: Throwable) {
            false
        }
    }

    /** Opens MIUI Autostart (so the service isn't killed); falls back to app info. */
    private fun openAutostartSettings() {
        val intent = Intent().setComponent(
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity",
            ),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (!tryStart(intent)) openAppDetails()
    }

    /** Opens MIUI "Other permissions" editor (background pop-up); falls back. */
    private fun openMiuiOtherPermissions() {
        val intent = Intent("miui.intent.action.APP_PERM_EDITOR")
            .setClassName(
                "com.miui.securitycenter",
                "com.miui.permcenter.permissions.PermissionsEditorActivity",
            )
            .putExtra("extra_pkgname", packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (!tryStart(intent)) openAppDetails()
    }

    private fun openAppDetails() {
        tryStart(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    private fun tryStart(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (_: Throwable) {
        false
    }
}
