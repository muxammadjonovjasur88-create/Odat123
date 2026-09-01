import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/digital_wellbeing_service.dart';
import '../../domain/app_usage_info.dart';

/// Provides real-time Screen Time Summary for Digital Wellbeing Dashboard.
final screenTimeSummaryProvider = FutureProvider.autoDispose<ScreenTimeSummary>((ref) async {
  final service = ref.watch(digitalWellbeingServiceProvider);
  return service.getScreenTimeSummary();
});

/// Provides today's detailed app usage list.
final todayAppUsageListProvider = FutureProvider.autoDispose<List<AppUsageInfo>>((ref) async {
  final service = ref.watch(digitalWellbeingServiceProvider);
  return service.getTodayAppUsageStats();
});

/// Notifier for user-configured per-app limits.
final appLimitsProvider = AsyncNotifierProvider<AppLimitsNotifier, List<AppLimitRule>>(() {
  return AppLimitsNotifier();
});

class AppLimitsNotifier extends AsyncNotifier<List<AppLimitRule>> {
  DigitalWellbeingService get _service => ref.read(digitalWellbeingServiceProvider);

  @override
  Future<List<AppLimitRule>> build() {
    return _service.getSavedAppLimits();
  }

  Future<void> setAppLimit({
    required String packageName,
    required String appName,
    required int limitMinutes,
    DisciplineLevel level = DisciplineLevel.strict,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final current = await _service.getSavedAppLimits();
      final existingIdx = current.indexWhere((r) => r.packageName == packageName);
      final updated = List<AppLimitRule>.from(current);

      final newRule = AppLimitRule(
        packageName: packageName,
        appName: appName,
        limitMinutes: limitMinutes,
        disciplineLevel: level,
        isEnabled: true,
      );

      if (existingIdx >= 0) {
        updated[existingIdx] = newRule;
      } else {
        updated.add(newRule);
      }

      await _service.saveAppLimits(updated);
      return updated;
    });
  }

  Future<void> removeAppLimit(String packageName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final current = await _service.getSavedAppLimits();
      final updated = current.where((r) => r.packageName != packageName).toList();
      await _service.saveAppLimits(updated);
      return updated;
    });
  }

  Future<void> toggleAppLimit(String packageName, bool isEnabled) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final current = await _service.getSavedAppLimits();
      final updated = current.map((r) {
        if (r.packageName == packageName) {
          return AppLimitRule(
            packageName: r.packageName,
            appName: r.appName,
            limitMinutes: r.limitMinutes,
            disciplineLevel: r.disciplineLevel,
            isEnabled: isEnabled,
          );
        }
        return r;
      }).toList();

      await _service.saveAppLimits(updated);
      return updated;
    });
  }
}
