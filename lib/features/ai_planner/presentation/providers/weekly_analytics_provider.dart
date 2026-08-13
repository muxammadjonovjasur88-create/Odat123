import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/weekly_analytics.dart';
import '../../../gamification/data/gamification_repository.dart';

/// Provides real weekly analytics calculated from the user's Firestore daily stats.
final weeklyAnalyticsProvider = Provider<WeeklyAnalytics>((ref) {
  final weekStatsAsync = ref.watch(weekStatsProvider);
  final weekStats = weekStatsAsync.asData?.value ?? const [];
  return WeeklyAnalytics.compute(weekStats);
});
