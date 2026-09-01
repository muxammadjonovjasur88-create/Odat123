import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_usage_info.dart';
import '../domain/installed_app.dart';

final digitalWellbeingServiceProvider = Provider<DigitalWellbeingService>((ref) {
  return DigitalWellbeingService();
});

class DigitalWellbeingService {
  static const _channel = MethodChannel('flowa/blocking');
  static const _limitsPrefKey = 'odat_user_app_limits';

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Check whether Android Usage Access permission is granted.
  Future<bool> hasUsageAccess() async {
    if (!isSupported) return true;
    try {
      final res = await _channel.invokeMethod<bool>('hasUsageAccess');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Android system settings for Usage Access.
  Future<void> openUsageAccessSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  /// Fetch all installed launchable apps with cached icons.
  Future<List<InstalledApp>> getInstalledApps() async {
    if (!isSupported) return [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (raw == null) return [];
      return raw
          .whereType<Map>()
          .map((m) => InstalledApp.fromMap(m.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[DigitalWellbeingService] getInstalledApps error: $e');
      return [];
    }
  }

  /// Fetch real-time app-by-app usage statistics for today (from 00:00 to now).
  Future<List<AppUsageInfo>> getTodayAppUsageStats() async {
    if (!isSupported) return [];
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final endOfToday = now.millisecondsSinceEpoch;

      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'getAppUsageStats',
        {'startTime': startOfToday, 'endTime': endOfToday},
      );

      if (rawList == null) return [];

      final limits = await getSavedAppLimits();
      final limitMap = {for (final l in limits) l.packageName: l};

      final apps = await getInstalledApps();
      final iconMap = {for (final a in apps) a.packageName: a.icon};

      return rawList.whereType<Map>().map((m) {
        final pkg = m['packageName'] as String? ?? '';
        final rule = limitMap[pkg];
        return AppUsageInfo.fromMap(
          m,
          dailyLimitMinutes: (rule != null && rule.isEnabled) ? rule.limitMinutes : 0,
          level: rule?.disciplineLevel ?? DisciplineLevel.strict,
          iconBytes: iconMap[pkg],
        );
      }).toList();
    } catch (e) {
      debugPrint('[DigitalWellbeingService] getTodayAppUsageStats error: $e');
      return [];
    }
  }

  /// Calculates total screen time summary for today and yesterday.
  Future<ScreenTimeSummary> getScreenTimeSummary() async {
    final todayUsage = await getTodayAppUsageStats();
    int totalTodayMin = 0;
    final catMinutes = <AppCategory, int>{};
    int exceededCount = 0;
    int activeLimits = 0;

    for (final app in todayUsage) {
      totalTodayMin += app.usageMinutes;
      catMinutes[app.category] = (catMinutes[app.category] ?? 0) + app.usageMinutes;
      if (app.hasLimit) {
        activeLimits++;
        if (app.isLimitExceeded) exceededCount++;
      }
    }

    // Yesterday usage for trend
    int totalYesterdayMin = (totalTodayMin * 0.9).round();
    if (isSupported) {
      try {
        final now = DateTime.now();
        final startOfYesterday = DateTime(now.year, now.month, now.day - 1).millisecondsSinceEpoch;
        final endOfYesterday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        final sec = await _channel.invokeMethod<int>(
          'getPhoneUsageSeconds',
          {'startTime': startOfYesterday, 'endTime': endOfYesterday},
        );
        if (sec != null && sec > 0) {
          totalYesterdayMin = sec ~/ 60;
        }
      } catch (_) {}
    }

    // Deterministic Discipline Score (0 to 100)
    final score = _calculateDisciplineScore(
      totalScreenMinutes: totalTodayMin,
      exceededLimitsCount: exceededCount,
      activeLimitsCount: activeLimits,
      socialMediaMinutes: catMinutes[AppCategory.social] ?? 0,
      gamesMinutes: catMinutes[AppCategory.games] ?? 0,
    );

    return ScreenTimeSummary(
      totalMinutesToday: totalTodayMin,
      totalMinutesYesterday: totalYesterdayMin,
      topApps: todayUsage.take(8).toList(),
      categoryMinutes: catMinutes,
      disciplineScore: score,
      activeLimitsCount: activeLimits,
      exceededLimitsCount: exceededCount,
    );
  }

  /// Transparent, deterministic Discipline Score formula (0 - 100).
  int _calculateDisciplineScore({
    required int totalScreenMinutes,
    required int exceededLimitsCount,
    required int activeLimitsCount,
    required int socialMediaMinutes,
    required int gamesMinutes,
  }) {
    int baseScore = 100;

    // Penalty for excessive screen time (> 4 hours = 240m)
    if (totalScreenMinutes > 240) {
      final excessHours = (totalScreenMinutes - 240) / 60;
      baseScore -= (excessHours * 8).round();
    }

    // Penalty for social media (> 1.5 hours = 90m)
    if (socialMediaMinutes > 90) {
      final excessSocial = (socialMediaMinutes - 90) / 30;
      baseScore -= (excessSocial * 5).round();
    }

    // Penalty for games (> 1 hour = 60m)
    if (gamesMinutes > 60) {
      final excessGames = (gamesMinutes - 60) / 30;
      baseScore -= (excessGames * 6).round();
    }

    // Heavy penalty for exceeding limits
    baseScore -= (exceededLimitsCount * 12);

    // Bonus for having active limits configured
    if (activeLimitsCount > 0 && exceededLimitsCount == 0) {
      baseScore += 5;
    }

    return baseScore.clamp(10, 100);
  }

  /// Retrieves user-configured per-app limits.
  Future<List<AppLimitRule>> getSavedAppLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_limitsPrefKey);
    if (raw == null || raw.isEmpty) return _defaultAppLimits();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => AppLimitRule.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultAppLimits();
    }
  }

  /// Saves user-configured per-app limits and syncs with Android native blocker.
  Future<void> saveAppLimits(List<AppLimitRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(rules.map((r) => r.toMap()).toList());
    await prefs.setString(_limitsPrefKey, jsonStr);

    if (isSupported) {
      try {
        await _channel.invokeMethod('saveAppLimits', {'limitsJson': jsonStr});
      } catch (e) {
        debugPrint('[DigitalWellbeingService] saveAppLimits native sync error: $e');
      }
    }
  }

  /// Starts a Digital Detox full focus countdown.
  Future<bool> startDigitalDetox({
    required int durationMinutes,
    required List<String> packageList,
    bool strict = true,
    String lang = 'uz',
  }) async {
    if (!isSupported) return true;
    try {
      final res = await _channel.invokeMethod<bool>('startDigitalDetox', {
        'durationMinutes': durationMinutes,
        'packages': packageList,
        'strict': strict,
        'lang': lang,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[DigitalWellbeingService] startDigitalDetox error: $e');
      return false;
    }
  }

  /// Default suggested app limits for new users.
  List<AppLimitRule> _defaultAppLimits() {
    return const [
      AppLimitRule(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        limitMinutes: 45,
        disciplineLevel: DisciplineLevel.strict,
      ),
      AppLimitRule(
        packageName: 'org.telegram.messenger',
        appName: 'Telegram',
        limitMinutes: 60,
        disciplineLevel: DisciplineLevel.focus,
      ),
      AppLimitRule(
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        limitMinutes: 60,
        disciplineLevel: DisciplineLevel.strict,
      ),
      AppLimitRule(
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
        limitMinutes: 30,
        disciplineLevel: DisciplineLevel.strict,
      ),
    ];
  }
}
