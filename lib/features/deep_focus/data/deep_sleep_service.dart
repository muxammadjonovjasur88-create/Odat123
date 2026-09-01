import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/user_repository.dart';

class SleepStats {
  final int totalPeriodMinutes;
  final int usageMinutes;
  final int restMinutes;

  SleepStats({
    required this.totalPeriodMinutes,
    required this.usageMinutes,
    required this.restMinutes,
  });
}

final deepSleepServiceProvider = Provider<DeepSleepService>((ref) {
  return DeepSleepService(ref);
});

class DeepSleepService {
  DeepSleepService(this._ref);

  final Ref _ref;

  static const String _kLastSleepCheckKey = 'last_sleep_check_epoch';
  static const String _kAccumulatedSleepMinutesKey = 'accumulated_sleep_minutes';
  static const String _kLastClaimDateKey = 'last_sleep_claim_date';

  /// Calculates eligible sleep minutes (between 22:00 and 06:30)
  Future<int> getUnclaimedSleepMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _getTodayStr();
    final lastClaim = prefs.getString(_kLastClaimDateKey);

    if (lastClaim == todayStr) {
      return 0; // Already claimed today's sleep reward
    }

    final stats = await getSleepStats();
    return stats.restMinutes;
  }

  /// Calculates screen-on phone usage and sleep/rest minutes in real time
  Future<SleepStats> getSleepStats() async {
    final now = DateTime.now();
    DateTime nightStart;
    DateTime nightEnd;

    if (now.hour >= 22) {
      // Night has just started tonight (22:00 to now)
      nightStart = DateTime(now.year, now.month, now.day, 22, 0);
      nightEnd = now;
    } else if (now.hour < 7) {
      // We are in the middle of the night (e.g. 02:14 AM)
      nightStart = DateTime(now.year, now.month, now.day - 1, 22, 0);
      nightEnd = now;
    } else {
      // Daytime (after 07:00) — full night completed from 22:00 to 07:00
      nightStart = DateTime(now.year, now.month, now.day - 1, 22, 0);
      nightEnd = DateTime(now.year, now.month, now.day, 7, 0);
    }

    final totalPeriodMinutes = nightEnd.difference(nightStart).inMinutes.clamp(1, 540);

    int usageMinutes = 0;
    try {
      final int? usageSeconds = await const MethodChannel('flowa/blocking').invokeMethod<int>(
        'getPhoneUsageSeconds',
        {
          'startTime': nightStart.millisecondsSinceEpoch,
          'endTime': nightEnd.millisecondsSinceEpoch,
        },
      );
      if (usageSeconds != null) {
        usageMinutes = usageSeconds ~/ 60;
      }
    } catch (_) {}

    final restMinutes = (totalPeriodMinutes - usageMinutes).clamp(0, 540);

    return SleepStats(
      totalPeriodMinutes: totalPeriodMinutes,
      usageMinutes: usageMinutes.clamp(0, totalPeriodMinutes),
      restMinutes: restMinutes,
    );
  }

  /// Claims the accumulated sleep PTS
  Future<int> claimSleepPoints(String uid) async {
    final minutes = await getUnclaimedSleepMinutes();
    if (minutes <= 0) return 0;

    final ptsToAward = minutes; // 1 minute = 1 PTS
    await _ref.read(userRepositoryProvider).awardPoints(uid, ptsToAward);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastClaimDateKey, _getTodayStr());
    await prefs.setInt(_kAccumulatedSleepMinutesKey, 0);

    debugPrint('🌙 [Deep Sleep] +$ptsToAward PTS claimed for $minutes sleep minutes.');
    return ptsToAward;
  }

  String _getTodayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
