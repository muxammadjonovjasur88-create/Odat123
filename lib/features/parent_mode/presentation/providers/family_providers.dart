import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_repository.dart';
import '../../data/family_repository.dart';
import '../../domain/family_models.dart';

/// Live status of the connected child. Returns null if no child is connected yet.
final childLiveStatusProvider = FutureProvider.autoDispose<ChildLiveStatus?>((ref) async {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return null;
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getChildLiveStatus(uid);
});

/// Real-time live GPS stream of the connected child.
final childLiveLocationStreamProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  final authUid = ref.watch(authStateProvider).asData?.value?.uid;
  if (authUid == null) return Stream.value(null);
  return repo.watchChildLiveLocation(authUid);
});

final childLocationHistoryStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  final authUid = ref.watch(authStateProvider).asData?.value?.uid;
  if (authUid == null) return Stream.value([]);
  return repo.watchChildLocationHistory(authUid);
});

final todayMissionsProvider = FutureProvider.autoDispose<List<FamilyMission>>((ref) async {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return [];
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getTodayMissions(uid);
});

final pendingExtraTimeRequestsProvider = FutureProvider.autoDispose<List<ExtraTimeRequest>>((ref) async {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return [];
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getPendingExtraTimeRequests(uid);
});

final recentStudyVerificationsProvider = FutureProvider.autoDispose<List<AiStudyVerification>>((ref) async {
  final status = await ref.watch(childLiveStatusProvider.future);
  final childUid = status?.childUid;
  if (childUid == null) return [];
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getRecentStudyVerifications(childUid);
});

final learningInterestsProvider = FutureProvider.autoDispose<List<LearningInterest>>((ref) async {
  final status = await ref.watch(childLiveStatusProvider.future);
  final childUid = status?.childUid;
  if (childUid == null) return [];
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getLearningInterests(childUid);
});

final fenixWalletProvider = FutureProvider.autoDispose<FenixWalletModel?>((ref) async {
  final status = await ref.watch(childLiveStatusProvider.future);
  final childUid = status?.childUid;
  if (childUid == null) return null;
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getFenixWallet(childUid);
});

final safetyTimelineProvider = FutureProvider.autoDispose<List<SafetyTimelineEvent>>((ref) async {
  final status = await ref.watch(childLiveStatusProvider.future);
  final childUid = status?.childUid;
  if (childUid == null) return [];
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getSafetyTimeline(childUid);
});

final safeZonesProvider = FutureProvider.autoDispose<List<SafeZone>>((ref) async {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return [];
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getSafeZones(uid);
});

final childAppUsageProvider = FutureProvider.autoDispose<List<AppUsageStat>>((ref) async {
  final status = await ref.watch(childLiveStatusProvider.future);
  final childUid = status?.childUid;
  if (childUid == null) return [];
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getAppUsageStats(childUid);
});

