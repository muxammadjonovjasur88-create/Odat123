import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/installed_app.dart';

/// Dart side of the `flowa/blocking` MethodChannel (Android only).
///
/// Drives the native AppBlockerAccessibilityService + blocking overlay: during
/// a focus session, the chosen distracting apps are blocked until the session
/// ends. On non-Android platforms every call is a safe no-op.
class BlockingService {
  static const _channel = MethodChannel('flowa/blocking');

  bool get _supported => Platform.isAndroid;

  Future<T?> _invokeSafe<T>(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } catch (e) {
      debugPrint('BlockingService.$method failed: $e');
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
  Future<void> startSession({
    required List<String> packages,
    required DateTime startAt,
    required DateTime endTime,
    bool strict = false,
    String lang = 'en',
  }) async {
    if (!_supported) return;
    await _invokeSafe<void>('startSession', {
      'packages': packages,
      'startAt': startAt.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'strict': strict,
      'lang': lang,
    });
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
