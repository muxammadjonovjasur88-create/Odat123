import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/installed_app.dart';

/// Why [BlockingService.startSession] could not arm blocking.
enum BlockingStartFailReason {
  /// Neither Accessibility Service nor Usage Access is granted — the app
  /// cannot detect which app is in the foreground.
  noDetectionPermission,

  /// The "draw over other apps" (SYSTEM_ALERT_WINDOW) permission is not granted
  /// so the blocking overlay cannot be shown.
  noOverlayPermission,
}

/// Result returned by [BlockingService.startSession].
class BlockingStartResult {
  const BlockingStartResult({required this.armed, required this.reason});

  /// Whether the native blocking session was successfully started.
  final bool armed;

  /// Non-null when [armed] is false and blocking failed due to a missing
  /// permission (rather than an empty package list or non-Android platform).
  final BlockingStartFailReason? reason;
}

/// Dart side of the `flowa/blocking` MethodChannel (Android only).
///
/// Drives the native AppBlockerAccessibilityService + blocking overlay: during
/// a focus session, the chosen distracting apps are blocked until the session
/// ends. On non-Android platforms every call is a safe no-op.
class BlockingService {
  static const _channel = MethodChannel('flowa/blocking');

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _invokeSafe<T>(String method, [dynamic arguments]) async {
    try {
      debugPrint('[BlockingService] → $method($arguments)');
      final result = await _channel.invokeMethod<T>(method, arguments);
      debugPrint('[BlockingService] ← $method result: $result');
      return result;
    } on MissingPluginException catch (e) {
      debugPrint('[BlockingService] ✗ $method: MethodChannel not registered — $e');
      return null;
    } on PlatformException catch (e) {
      debugPrint('[BlockingService] ✗ $method: PlatformException ${e.code}: ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('[BlockingService] ✗ $method failed: $e\n$st');
      return null;
    }
  }

  /// The real launchable apps installed on the device (name + package + icon).
  Future<List<InstalledApp>> getInstalledApps() async {
    if (!_supported) return const [];
    final raw = await _invokeSafe<List<dynamic>>('getInstalledApps');
    if (raw == null) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(InstalledApp.fromMap)
        .where((a) => a.packageName.isNotEmpty)
        .toList();
  }

  /// Whether Flowa's accessibility blocking service is enabled by the user.
  /// This is the primary, instant way Flowa detects the foreground app.
  Future<bool> isAccessibilityEnabled() async {
    if (!_supported) return false;
    return await _invokeSafe<bool>('isAccessibilityEnabled') ?? false;
  }

  Future<void> openAccessibilitySettings() async {
    if (!_supported) return;
    await _invokeSafe<void>('openAccessibilitySettings');
  }

  /// Whether the device runs MIUI (Xiaomi), which needs extra permissions.
  Future<bool> isMiui() async {
    if (!_supported) return false;
    return await _invokeSafe<bool>('isMiui') ?? false;
  }

  /// MIUI Autostart, so the service isn't killed in the background.
  Future<void> openAutostartSettings() async {
    if (!_supported) return;
    await _invokeSafe<void>('openAutostartSettings');
  }

  /// MIUI "Other permissions" (the "Display pop-up while running in background"
  /// permission the overlay needs).
  Future<void> openMiuiOtherPermissions() async {
    if (!_supported) return;
    await _invokeSafe<void>('openMiuiOtherPermissions');
  }

  /// Arms blocking of [packages] for the window [startAt, endTime). Blocking is
  /// only enforced once `startAt` is reached, so the session can be armed early
  /// (e.g. while the app is open) yet kick in exactly at the 5-minutes-before
  /// moment, surviving the app being closed. Package names are Android
  /// application IDs, e.g. `com.instagram.android`, `org.telegram.messenger`.
  ///
  /// Returns [BlockingStartResult] describing whether blocking was actually
  /// armed, or which permission is missing so the caller can show a prompt.
  Future<BlockingStartResult> startSession({
    required List<String> packages,
    required DateTime startAt,
    required DateTime endTime,
    bool strict = false,
    String lang = 'en',
  }) async {
    if (!_supported) return const BlockingStartResult(armed: false, reason: null);
    if (packages.isEmpty) {
      debugPrint('[BlockingService] startSession: packages list is empty — nothing to block');
      return const BlockingStartResult(armed: false, reason: null);
    }

    // Pre-flight: check that at least one detection method and the overlay are available.
    final hasA11y = await isAccessibilityEnabled();
    final hasUsage = await hasUsageAccess();
    final hasOverlay = await canDrawOverlays();

    debugPrint(
      '[BlockingService] startSession pre-flight: '
      'accessibility=$hasA11y usageAccess=$hasUsage overlay=$hasOverlay '
      'packages=${packages.length}',
    );

    if (!hasA11y && !hasUsage) {
      debugPrint('[BlockingService] ✗ startSession ABORTED: no foreground-app detection method enabled');
      return const BlockingStartResult(
        armed: false,
        reason: BlockingStartFailReason.noDetectionPermission,
      );
    }
    if (!hasOverlay) {
      debugPrint('[BlockingService] ✗ startSession ABORTED: overlay permission not granted');
      return const BlockingStartResult(
        armed: false,
        reason: BlockingStartFailReason.noOverlayPermission,
      );
    }

    await _invokeSafe<void>('startSession', {
      'packages': packages,
      'startAt': startAt.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'strict': strict,
      'lang': lang,
    });
    debugPrint('[BlockingService] ✓ startSession armed for ${packages.length} packages');
    return const BlockingStartResult(armed: true, reason: null);
  }

  Future<void> stopSession() async {
    if (!_supported) return;
    await _invokeSafe<void>('stopSession');
  }

  /// Whether Usage Access (PACKAGE_USAGE_STATS) is granted. This is how Flowa
  /// detects the foreground app — the Play-friendly alternative to an
  /// AccessibilityService.
  Future<bool> hasUsageAccess() async {
    if (!_supported) return false;
    return await _invokeSafe<bool>('hasUsageAccess') ?? false;
  }

  Future<void> openUsageAccessSettings() async {
    if (!_supported) return;
    await _invokeSafe<void>('openUsageAccessSettings');
  }

  /// Whether the "draw over other apps" permission is granted.
  Future<bool> canDrawOverlays() async {
    if (!_supported) return false;
    return await _invokeSafe<bool>('canDrawOverlays') ?? false;
  }

  Future<void> requestOverlayPermission() async {
    if (!_supported) return;
    await _invokeSafe<void>('requestOverlayPermission');
  }

  // --- Additional General Permissions ---

  Future<bool> hasNotificationPermission() async {
    if (!_supported) return false;
    return await Permission.notification.isGranted;
  }

  Future<void> requestNotificationPermission() async {
    if (!_supported) return;
    await Permission.notification.request();
  }

  Future<bool> hasExactAlarmPermission() async {
    if (!_supported) return false;
    return await Permission.scheduleExactAlarm.isGranted;
  }

  Future<void> requestExactAlarmPermission() async {
    if (!_supported) return;
    await Permission.scheduleExactAlarm.request();
  }

  Future<bool> hasIgnoreBatteryOptimizationsPermission() async {
    if (!_supported) return false;
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  Future<void> requestIgnoreBatteryOptimizationsPermission() async {
    if (!_supported) return;
    await Permission.ignoreBatteryOptimizations.request();
  }

  Future<bool> hasAudioPermission() async {
    if (!_supported) return false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;
      final storageStatus = await Permission.storage.status;
      return storageStatus.isGranted;
    }
    return false;
  }

  Future<void> requestAudioPermission() async {
    if (!_supported) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final audioResult = await Permission.audio.request();
      if (!audioResult.isGranted) {
        await Permission.storage.request();
      }
    }
  }
}

final blockingServiceProvider = Provider<BlockingService>(
  (ref) => BlockingService(),
);

/// The real installed apps, fetched once from the native side for the settings
/// list. Sorted with common distracting apps surfaced first.
final installedAppsProvider = FutureProvider<List<InstalledApp>>((ref) async {
  final apps = await ref.watch(blockingServiceProvider).getInstalledApps();
  final sorted = [...apps]
    ..sort((a, b) {
      final ad = kCommonDistractingPackages.contains(a.packageName);
      final bd = kCommonDistractingPackages.contains(b.packageName);
      if (ad != bd) return ad ? -1 : 1; // distracting apps first
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return sorted;
});
