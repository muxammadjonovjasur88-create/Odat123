import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../domain/models/boss_raid.dart';

final bossRaidRepositoryProvider = Provider<BossRaidRepository>((ref) {
  return BossRaidRepository(ref.watch(firestoreProvider));
});

final activeBossRaidProvider = StreamProvider.autoDispose<BossRaid>((ref) {
  final profile = ref.watch(userProfileProvider).asData?.value;
  return ref.watch(bossRaidRepositoryProvider).watchActiveBossRaid(
        clanId: profile?.clanId,
        clanName: profile?.clanName,
      );
});

class BossRaidRepository {
  BossRaidRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _raidsCol =>
      _db.collection('boss_raids');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _clansCol =>
      _db.collection('clans');

  /// Streams the active Clan Boss Raid for a specific clan
  Stream<BossRaid> watchActiveBossRaid({String? clanId, String? clanName}) {
    final effectiveRaidId = (clanId != null && clanId.isNotEmpty)
        ? 'clan_boss_$clanId'
        : 'weekly_boss_default';

    return _raidsCol.doc(effectiveRaidId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return BossRaid(
          id: effectiveRaidId,
          bossName: clanName != null ? '[$clanName] Klanining Qora Titani' : 'Dangasalik Titani',
          bossTitle: clanName != null ? 'Klan Darajasi 5 • Jamoaviy Klan Bossi' : 'Daraja 5 • Haftalik Mega Boss',
          bossAvatar: '🐉',
          maxHp: 5000,
          currentHp: 4600,
          targetPushUps: 1500,
          currentPushUps: 240,
          targetRunningKm: 50.0,
          currentRunningKm: 18.5,
          targetFocusMinutes: 600,
          currentFocusMinutes: 180,
          rewardPoints: 2000,
          rewardCoins: 5,
          status: BossStatus.active,
          expiresAt: DateTime.now().add(const Duration(days: 3)),
          participants: const [],
        );
      }
      return BossRaid.fromDoc(snap);
    });
  }

  /// Attacks the Boss by dealing damage via push-ups, running, or focus
  Future<int> attackBoss({
    required String raidId,
    required String uid,
    required String actionType, // 'pushup', 'running', 'focus'
    required int amount,
    String? clanId,
  }) async {
    final damage = switch (actionType) {
      'pushup' => amount * 2, // 1 pushup = 2 DMG
      'running' => (amount * 10), // 1 km = 10 DMG
      'focus' => amount ~/ 2, // 1 min focus = 0.5 DMG
      _ => amount,
    };

    if (raidId == 'weekly_boss_default') {
      return damage;
    }

    try {
      final docRef = _raidsCol.doc(raidId);
      final bossSnap = await docRef.get();
      if (!bossSnap.exists) {
        await docRef.set({
          'bossName': 'Klan Qora Titani',
          'bossTitle': 'Klan Jamoaviy Bossi',
          'bossAvatar': '🐉',
          'maxHp': 5000,
          'currentHp': (5000 - damage).clamp(0, 5000),
          'targetPushUps': 1500,
          'currentPushUps': actionType == 'pushup' ? amount : 0,
          'targetRunningKm': 50.0,
          'currentRunningKm': actionType == 'running' ? amount.toDouble() : 0.0,
          'targetFocusMinutes': 600,
          'currentFocusMinutes': actionType == 'focus' ? amount : 0,
          'rewardPoints': 2000,
          'rewardCoins': 5,
          'status': BossStatus.active.name,
          'expiresAt': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          'participants': [uid],
        });
        return damage;
      }

      final data = bossSnap.data() ?? {};
      final currentHp = (data['currentHp'] as num?)?.toInt() ?? 2000;
      final newHp = (currentHp - damage).clamp(0, 1000000);

      final updates = <String, dynamic>{
        'currentHp': newHp,
        'participants': FieldValue.arrayUnion([uid]),
      };

      if (actionType == 'pushup') {
        updates['currentPushUps'] = FieldValue.increment(amount);
      } else if (actionType == 'running') {
        updates['currentRunningKm'] = FieldValue.increment(amount.toDouble());
      } else if (actionType == 'focus') {
        updates['currentFocusMinutes'] = FieldValue.increment(amount);
      }

      if (newHp <= 0) {
        updates['status'] = BossStatus.defeated.name;
        await _usersCol.doc(uid).update({
          'totalPoints': FieldValue.increment(1000),
          'fenixCoins': FieldValue.increment(250),
        });
      }

      await docRef.update(updates);

      // Add points to clan if available
      if (clanId != null && clanId.isNotEmpty) {
        await _clansCol.doc(clanId).update({
          'totalPoints': FieldValue.increment(damage * 2),
          'weeklyPoints': FieldValue.increment(damage * 2),
        });
      }
    } catch (_) {}

    return damage;
  }
}
