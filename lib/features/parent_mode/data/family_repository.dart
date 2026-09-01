import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_providers.dart';
import '../domain/family_models.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(ref.watch(firestoreProvider));
});

/// Repository for parent-child family data wired with real Firestore integration.
class FamilyRepository {
  FamilyRepository(this._db);

  final FirebaseFirestore _db;

  /// Searches for a child user in Firestore by 7-digit numericId, displayId, or UID,
  /// and links the child to the parent.
  Future<Map<String, dynamic>?> linkChild({
    required String parentUid,
    required String parentName,
    required String queryId,
  }) async {
    final query = queryId.trim();
    if (query.isEmpty) return null;

    // Normalize for case-insensitive matching
    final queryLower = query.toLowerCase();

    try {
      DocumentSnapshot<Map<String, dynamic>>? childDoc;

      // 1. Try exact displayId match
      final snapByDisplay = await _db
          .collection('users')
          .where('displayId', isEqualTo: query)
          .limit(1)
          .get();

      if (snapByDisplay.docs.isNotEmpty) {
        childDoc = snapByDisplay.docs.first;
      } else {
        // 2. Try lowercase displayId match
        final snapByDisplayLower = await _db
            .collection('users')
            .where('displayId', isEqualTo: queryLower)
            .limit(1)
            .get();

        if (snapByDisplayLower.docs.isNotEmpty) {
          childDoc = snapByDisplayLower.docs.first;
        } else {
          // 3. Try numericId match
          final snapByNumeric = await _db
              .collection('users')
              .where('numericId', isEqualTo: query)
              .limit(1)
              .get();

          if (snapByNumeric.docs.isNotEmpty) {
            childDoc = snapByNumeric.docs.first;
          } else {
            // 4. Try direct UID match
            final directDoc = await _db.collection('users').doc(query).get();
            if (directDoc.exists) {
              childDoc = directDoc;
            } else {
              // 5. Broad fallback: scan users — increased limit to 500
              final allUsers = await _db.collection('users').limit(500).get();
              for (final d in allUsers.docs) {
                final uid = d.id;
                final data = d.data();
                final hash = uid.hashCode.abs();
                final calcNum = (1000000 + (hash % 9000000)).toString();
                // Match by computed numericId, UID prefix, or case-insensitive displayId
                final dId = (data['displayId'] as String? ?? '').toLowerCase();
                if (calcNum == query ||
                    uid.startsWith(query) ||
                    dId == queryLower) {
                  childDoc = d;
                  break;
                }
              }
            }
          }
        }
      }

      if (childDoc == null || !childDoc.exists) {
        return null;
      }

      final childUid = childDoc.id;

      // Prevent self-linking
      if (childUid == parentUid) return null;

      final childData = childDoc.data() ?? {};
      final childName = (childData['displayName'] as String?) ??
          (childData['name'] as String?) ??
          'Farzand';
      final childAvatar = (childData['avatar'] as String?) ?? 'leaf';

      // Link on parent user doc — write BOTH field names for compatibility
      await _db.collection('users').doc(parentUid).set({
        'childUid': childUid,
        'linkedChildUid': childUid, // Alias used by some parent screens
        'childName': childName,
        'childAvatar': childAvatar,
        'connectedChildren': FieldValue.arrayUnion([childUid]),
        'appRole': 'family',
        'familyRole': 'parent',
        'childLinkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Link on child user doc
      await _db.collection('users').doc(childUid).set({
        'parentUid': parentUid,
        'parentName': parentName,
        'connectedParents': FieldValue.arrayUnion([parentUid]),
        'appRole': 'family',
        'familyRole': 'child',
        'parentLinkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send in-app notification to child's inbox
      final msgId = 'fam_link_${DateTime.now().millisecondsSinceEpoch}';
      await _db
          .collection('users')
          .doc(childUid)
          .collection('inbox')
          .doc(msgId)
          .set({
        'id': msgId,
        'title': 'Ota-onangiz ulandi! 👨‍👩‍👧‍👦',
        'body': '$parentName ota-ona panelidan sizga ulandi. O\'qish va sportdagi natijalaringiz oilaviy monitoringda ko\'rinadi.',
        'type': 'parentReward',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'uid': childUid,
        'name': childName,
        'avatar': childAvatar,
      };
    } catch (e) {
      debugPrint('⚠️ Error linking child: $e');
      return null;
    }
  }

  /// Returns the live status of a connected child from Firestore.
  /// Streams the real-time GPS coordinates of the connected child.

  Stream<Map<String, dynamic>?> watchChildLiveLocation(String parentUid) {
    return _db.collection('users').doc(parentUid).snapshots().asyncExpand((parentSnap) {
      final childUid = _resolveChildUid(parentSnap.data());
      if (childUid == null || childUid.isEmpty) {
        return Stream.value(null);
      }
      return _db
          .collection('users')
          .doc(childUid)
          .collection('live_location')
          .doc('current')
          .snapshots()
          .map((snap) {
        if (!snap.exists) return null;
        final data = snap.data();
        if (data != null) {
          data['childUid'] = childUid;
        }
        return data;
      });
    });
  }

  /// Streams the location history of the connected child for today.
  Stream<List<Map<String, dynamic>>> watchChildLocationHistory(String parentUid) {
    return _db.collection('users').doc(parentUid).snapshots().asyncExpand((parentSnap) {
      final childUid = _resolveChildUid(parentSnap.data());
      if (childUid == null || childUid.isEmpty) {
        return Stream.value([]);
      }
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      return _db
          .collection('users')
          .doc(childUid)
          .collection('location_history')
          .doc(todayStr)
          .snapshots()
          .map((snap) {
        if (!snap.exists) return [];
        final data = snap.data();
        if (data != null && data['points'] != null) {
          return (data['points'] as List).map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      });
    });
  }

  /// Resolves the child UID from parent doc data.
  /// Prefers `childUid`, falls back to first element of `connectedChildren`.
  String? _resolveChildUid(Map<String, dynamic>? data) {
    if (data == null) return null;
    final uid = data['childUid'] as String?;
    if (uid != null && uid.isNotEmpty) return uid;
    final list = data['connectedChildren'] as List?;
    if (list != null && list.isNotEmpty) return list.first as String?;
    return null;
  }

  Future<ChildLiveStatus?> getChildLiveStatus(String parentUid) async {
    try {
      final parentDoc = await _db.collection('users').doc(parentUid).get();
      if (!parentDoc.exists) return null;

      final pData = parentDoc.data() ?? {};
      final childUid = _resolveChildUid(pData);
      if (childUid == null || childUid.isEmpty) return null;

      final childDoc = await _db.collection('users').doc(childUid).get();
      if (!childDoc.exists) return null;

      final cData = childDoc.data() ?? {};
      final name = (cData['displayName'] as String?) ?? (cData['name'] as String?) ?? 'Farzand';
      final avatar = (cData['avatar'] as String?) ?? 'leaf';
      final totalPoints = (cData['totalPoints'] as num?)?.toInt() ?? 0;
      final streak = (cData['streak'] as num?)?.toInt() ?? 0;
      final weeklyFocusMin = (cData['weeklyFocusMinutes'] as num?)?.toInt() ?? 0;

      // Read live location doc for real-time data
      final liveDoc = await _db
          .collection('users')
          .doc(childUid)
          .collection('live_location')
          .doc('current')
          .get();

      final liveData = liveDoc.data() ?? {};
      final isOnline = (liveData['isOnline'] as bool?) ?? false;
      final batteryLevel = (liveData['batteryLevel'] as num?)?.toInt() ?? 0;
      final isCharging = (liveData['isCharging'] as bool?) ?? false;
      final locationName = (liveData['locationName'] as String?) ??
          (cData['lastKnownLocation'] as String?) ?? '—';
      final updatedAt = liveData['updatedAt'];
      String locationUpdatedAtStr = '—';
      if (updatedAt is Timestamp) {
        final diff = DateTime.now().difference(updatedAt.toDate());
        if (diff.inMinutes < 1) {
          locationUpdatedAtStr = 'Hozir';
        } else if (diff.inMinutes < 60) {
          locationUpdatedAtStr = '${diff.inMinutes} daq oldin';
        } else {
          locationUpdatedAtStr = '${diff.inHours} soat oldin';
        }
      }

      final screenTimeMin = (cData['todayScreenTimeMinutes'] as num?)?.toInt() ?? 0;
      final tasksCompleted = (cData['todayTasksCompleted'] as num?)?.toInt() ?? 0;
      final tasksTotal = (cData['todayTasksTotal'] as num?)?.toInt() ??
          (tasksCompleted > 0 ? tasksCompleted + 2 : 0);
      final progressPct = tasksTotal > 0
          ? ((tasksCompleted / tasksTotal) * 100).round().clamp(0, 100)
          : (totalPoints > 0 ? (totalPoints % 100).clamp(0, 100) : 0);
      final disciplineScore = (cData['disciplineScore'] as num?)?.toInt() ??
          (streak > 7 ? 90 : streak > 3 ? 75 : streak > 0 ? 60 : 50);

      return ChildLiveStatus(
        childUid: childUid,
        name: name,
        avatar: avatar,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        locationName: locationName,
        locationUpdatedAtStr: locationUpdatedAtStr,
        todayScreenTimeMinutes: screenTimeMin,
        todayStudyMinutes: weeklyFocusMin,
        todayTasksCompleted: tasksCompleted,
        todayTasksTotal: tasksTotal,
        dailyProgressPercent: progressPct,
        disciplineScore: disciplineScore,
        isOnline: isOnline,
      );
    } catch (e) {
      debugPrint('⚠️ Error fetching child live status: $e');
      return null;
    }
  }

  /// Returns today's family missions for the parent.
  Future<List<FamilyMission>> getTodayMissions(String parentUid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(parentUid)
          .collection('family_missions')
          .get();
      return snap.docs.map((doc) => FamilyMission.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching family missions: $e');
      return [];
    }
  }

  /// Returns pending extra-time requests sent by the child.
  Future<List<ExtraTimeRequest>> getPendingExtraTimeRequests(String parentUid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(parentUid)
          .collection('extra_time_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      return snap.docs.map((doc) => ExtraTimeRequest.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching extra time requests: $e');
      return [];
    }
  }

  /// Returns recent AI study verifications for the parent's child.
  Future<List<AiStudyVerification>> getRecentStudyVerifications(String childUid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(childUid)
          .collection('study_verifications')
          .orderBy('verifiedAtStr', descending: true)
          .limit(10)
          .get();
      return snap.docs.map((doc) => AiStudyVerification.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching study verifications: $e');
      return [];
    }
  }

  /// Returns the detected learning interests of the child (AI engine output).
  Future<List<LearningInterest>> getLearningInterests(String childUid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(childUid)
          .collection('learning_interests')
          .get();
      return snap.docs.map((doc) => LearningInterest.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching learning interests: $e');
      return [];
    }
  }

  /// Returns the Fenix wallet details for the child from Firestore.
  Future<FenixWalletModel?> getFenixWallet(String childUid) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(childUid)
          .collection('fenix_wallet')
          .doc('data')
          .get();

      if (!doc.exists) {
        // Fallback: build wallet from main user doc fenixCoins field
        final userDoc = await _db.collection('users').doc(childUid).get();
        if (!userDoc.exists) return null;
        final d = userDoc.data() ?? {};
        final coins = (d['fenixCoins'] as num?)?.toInt() ?? 0;
        return FenixWalletModel(
          totalBalance: coins,
          availableCoins: coins,
          savingsVaultCoins: 0,
          todayEarnedCoins: (d['todayEarnedCoins'] as num?)?.toInt() ?? 0,
          goals: const [],
        );
      }

      final d = doc.data() ?? {};
      final goalsRaw = (d['goals'] as List?) ?? [];
      final goals = goalsRaw.map((g) {
        final gMap = g as Map<String, dynamic>;
        return SavingsGoal(
          id: gMap['id'] as String? ?? '',
          title: gMap['title'] as String? ?? '',
          targetCoins: (gMap['targetCoins'] as num?)?.toInt() ?? 0,
          savedCoins: (gMap['savedCoins'] as num?)?.toInt() ?? 0,
          iconName: gMap['iconName'] as String? ?? 'star',
          isParentAgreed: (gMap['isParentAgreed'] as bool?) ?? true,
        );
      }).toList();

      return FenixWalletModel(
        totalBalance: (d['totalBalance'] as num?)?.toInt() ?? 0,
        availableCoins: (d['availableCoins'] as num?)?.toInt() ?? 0,
        savingsVaultCoins: (d['savingsVaultCoins'] as num?)?.toInt() ?? 0,
        todayEarnedCoins: (d['todayEarnedCoins'] as num?)?.toInt() ?? 0,
        goals: goals,
      );
    } catch (e) {
      debugPrint('⚠️ Error fetching Fenix wallet: $e');
      return null;
    }
  }

  /// Returns the safety timeline events for today.
  Future<List<SafetyTimelineEvent>> getSafetyTimeline(String childUid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(childUid)
          .collection('safety_timeline')
          .get();
      return snap.docs.map((doc) => SafetyTimelineEvent.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching safety timeline: $e');
      return [];
    }
  }

  /// Returns the configured safe zones (geofences) for the family.
  Future<List<SafeZone>> getSafeZones(String parentUid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(parentUid)
          .collection('safe_zones')
          .get();
      return snap.docs.map((doc) => SafeZone.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching safe zones: $e');
      return [];
    }
  }

  /// Returns app usage data for the child (screen time per app).
  Future<List<AppUsageStat>> getAppUsageStats(String childUid) async {
    try {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final snap = await _db
          .collection('users')
          .doc(childUid)
          .collection('app_usage')
          .doc(dateStr)
          .collection('apps')
          .get();
      return snap.docs.map((doc) => AppUsageStat.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching app usage stats: $e');
      return [];
    }
  }

  Future<void> stopTracking(String childUid) async {
    return;
  }
}

/// App usage stat model for screen time per application.
class AppUsageStat {
  const AppUsageStat({
    required this.packageName,
    required this.appName,
    required this.iconName,
    required this.usageMinutes,
    required this.limitMinutes,
    required this.category,
  });

  final String packageName;
  final String appName;
  final String iconName;
  final int usageMinutes;
  final int limitMinutes; // 0 = no limit set
  final String category; // 'social', 'games', 'education', 'other'

  double get usageRatio => limitMinutes > 0 ? (usageMinutes / limitMinutes).clamp(0.0, 1.0) : 0.0;
  bool get isOverLimit => limitMinutes > 0 && usageMinutes >= limitMinutes;

  String get formattedUsage {
    if (usageMinutes < 60) return '${usageMinutes}d';
    final h = usageMinutes ~/ 60;
    final m = usageMinutes % 60;
    return m > 0 ? '${h}s ${m}d' : '${h}s';
  }

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'appName': appName,
        'iconName': iconName,
        'usageMinutes': usageMinutes,
        'limitMinutes': limitMinutes,
        'category': category,
      };

  factory AppUsageStat.fromMap(Map<String, dynamic> map) {
    return AppUsageStat(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'android',
      usageMinutes: (map['usageMinutes'] as num?)?.toInt() ?? 0,
      limitMinutes: (map['limitMinutes'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? 'other',
    );
  }
}
