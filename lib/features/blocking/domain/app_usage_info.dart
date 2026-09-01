import 'package:flutter/foundation.dart';

/// Discipline enforcement level when app limit is reached.
enum DisciplineLevel {
  /// Subtle warning snackbar/dialog, user can proceed.
  gentle,

  /// Strong popup requiring intentional confirmation.
  focus,

  /// Instant full-screen blocking overlay.
  strict,
}

/// Category classification for apps in Digital Wellbeing.
enum AppCategory {
  social,
  entertainment,
  games,
  productivity,
  other,
}

/// Represents real-time app usage telemetry queried from Android UsageStatsManager.
@immutable
class AppUsageInfo {
  const AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.usageMinutes,
    this.usageSeconds = 0,
    this.lastTimeUsed = 0,
    this.category = AppCategory.other,
    this.dailyLimitMinutes = 0,
    this.disciplineLevel = DisciplineLevel.strict,
    this.iconBytes,
  });

  final String packageName;
  final String appName;
  final int usageMinutes;
  final int usageSeconds;
  final int lastTimeUsed;
  final AppCategory category;
  final int dailyLimitMinutes; // 0 means no limit set
  final DisciplineLevel disciplineLevel;
  final Uint8List? iconBytes;

  bool get hasLimit => dailyLimitMinutes > 0;
  bool get isLimitExceeded => hasLimit && usageMinutes >= dailyLimitMinutes;
  double get limitProgress => hasLimit ? (usageMinutes / dailyLimitMinutes).clamp(0.0, 1.0) : 0.0;
  int get remainingMinutes => hasLimit ? (dailyLimitMinutes - usageMinutes).clamp(0, 1440) : 0;

  factory AppUsageInfo.fromMap(Map<dynamic, dynamic> map, {int dailyLimitMinutes = 0, DisciplineLevel level = DisciplineLevel.strict, Uint8List? iconBytes}) {
    final catStr = (map['category'] as String?)?.toLowerCase() ?? 'other';
    AppCategory cat;
    switch (catStr) {
      case 'social':
        cat = AppCategory.social;
        break;
      case 'entertainment':
        cat = AppCategory.entertainment;
        break;
      case 'games':
        cat = AppCategory.games;
        break;
      case 'productivity':
        cat = AppCategory.productivity;
        break;
      default:
        cat = AppCategory.other;
    }

    return AppUsageInfo(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      usageMinutes: (map['usageMinutes'] as num?)?.toInt() ?? 0,
      usageSeconds: (map['usageSeconds'] as num?)?.toInt() ?? 0,
      lastTimeUsed: (map['lastTimeUsed'] as num?)?.toInt() ?? 0,
      category: cat,
      dailyLimitMinutes: dailyLimitMinutes,
      disciplineLevel: level,
      iconBytes: iconBytes,
    );
  }
}

/// Aggregate overview of daily/weekly screen time.
@immutable
class ScreenTimeSummary {
  const ScreenTimeSummary({
    required this.totalMinutesToday,
    required this.totalMinutesYesterday,
    required this.topApps,
    required this.categoryMinutes,
    required this.disciplineScore,
    required this.activeLimitsCount,
    required this.exceededLimitsCount,
  });

  final int totalMinutesToday;
  final int totalMinutesYesterday;
  final List<AppUsageInfo> topApps;
  final Map<AppCategory, int> categoryMinutes;
  final int disciplineScore; // 0 to 100
  final int activeLimitsCount;
  final int exceededLimitsCount;

  int get diffVsYesterday => totalMinutesToday - totalMinutesYesterday;
  bool get isReducedVsYesterday => diffVsYesterday < 0;

  String get formattedTotalTime {
    final h = totalMinutesToday ~/ 60;
    final m = totalMinutesToday % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}

/// A user-configured daily limit rule for a specific app package.
@immutable
class AppLimitRule {
  const AppLimitRule({
    required this.packageName,
    required this.appName,
    required this.limitMinutes,
    this.disciplineLevel = DisciplineLevel.strict,
    this.isEnabled = true,
  });

  final String packageName;
  final String appName;
  final int limitMinutes;
  final DisciplineLevel disciplineLevel;
  final bool isEnabled;

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'appName': appName,
        'limitMinutes': limitMinutes,
        'disciplineLevel': disciplineLevel.name,
        'isEnabled': isEnabled,
      };

  factory AppLimitRule.fromMap(Map<String, dynamic> map) {
    return AppLimitRule(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      limitMinutes: (map['limitMinutes'] as num?)?.toInt() ?? 30,
      disciplineLevel: DisciplineLevel.values.firstWhere(
        (e) => e.name == map['disciplineLevel'],
        orElse: () => DisciplineLevel.strict,
      ),
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}
