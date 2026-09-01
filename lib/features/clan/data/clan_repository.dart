import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../domain/models/clan.dart';

final clanRepositoryProvider = Provider<ClanRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return ClanRepository(db);
});

final topClansProvider = StreamProvider<List<Clan>>((ref) {
  return ref.watch(clanRepositoryProvider).watchTopClans();
});

final userClanProvider = StreamProvider<Clan?>((ref) {
  final user = ref.watch(userProfileProvider).asData?.value;
  if (user == null || user.clanId == null || user.clanId!.isEmpty) {
    return Stream.value(null);
  }

  final clanId = user.clanId!;
  final fallbackClan = user.clanName != null && user.clanName!.isNotEmpty
      ? Clan(
          id: clanId,
          name: user.clanName!,
          tag: user.clanTag ?? 'ODAT',
          description: 'ODAT jangchilari klani',
          emblem: user.clanEmblem ?? '🦅',
          leaderId: user.uid,
          leaderName: user.displayName ?? user.name,
          region: user.clanRegion ?? 'Navoiy',
          maxMembers: 25,
          membersCount: 1,
          totalPoints: user.totalPoints,
          weeklyPoints: user.weeklyPoints,
          memberUids: [user.uid],
          isPublic: true,
          createdAt: DateTime.now(),
        )
      : null;

  return ref.watch(clanRepositoryProvider).watchClan(clanId, fallback: fallbackClan);
});

class ClanMemberItem {
  const ClanMemberItem({
    required this.uid,
    required this.name,
    required this.role, // 'Lider' or 'A\'zo'
    required this.avatar,
    required this.points,
    required this.weeklyPoints,
  });

  final String uid;
  final String name;
  final String role;
  final String avatar;
  final int points;
  final int weeklyPoints;
}

class ClanRepository {
  ClanRepository(this._db) {
    _initPersistentClans();
  }

  final FirebaseFirestore _db;
  static const String _persistentClansKey = 'odat_persistent_clans_v2';

  CollectionReference<Map<String, dynamic>> get _clans =>
      _db.collection('clans');

  static final List<Clan> _defaultClans = [];

  static final List<Clan> _localClans = [];
  static final StreamController<List<Clan>> _clansController =
      StreamController<List<Clan>>.broadcast();

  Future<void> _initPersistentClans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_persistentClansKey);
      if (savedList != null && savedList.isNotEmpty) {
        final parsed = savedList
            .map((str) {
              try {
                return Clan.fromJson(str);
              } catch (_) {
                return null;
              }
            })
            .whereType<Clan>()
            .toList();

        for (final item in parsed) {
          if (!_localClans.any((c) => c.id == item.id)) {
            _localClans.insert(0, item);
          }
        }
        _sanitizeClanMemberships();
      }
    } catch (_) {}
  }

  void _sanitizeClanMemberships() {
    final leaderClanMap = <String, String>{};
    for (final c in _localClans) {
      if (c.leaderId.isNotEmpty) {
        leaderClanMap[c.leaderId] = c.id;
      }
    }

    bool modified = false;
    for (int i = 0; i < _localClans.length; i++) {
      final c = _localClans[i];
      final validUids = c.memberUids.where((uid) {
        final ownedClanId = leaderClanMap[uid];
        if (ownedClanId != null && ownedClanId != c.id) {
          modified = true;
          return false;
        }
        return true;
      }).toList();

      if (validUids.length != c.memberUids.length) {
        _localClans[i] = Clan(
          id: c.id,
          name: c.name,
          tag: c.tag,
          description: c.description,
          emblem: c.emblem,
          leaderId: c.leaderId,
          leaderName: c.leaderName,
          region: c.region,
          maxMembers: c.maxMembers,
          membersCount: validUids.length.clamp(1, c.maxMembers),
          totalPoints: c.totalPoints,
          weeklyPoints: c.weeklyPoints,
          memberUids: validUids,
          createdAt: c.createdAt,
        );
      }
    }
    if (modified) {
      _savePersistentClans();
    }
  }

  Future<void> _savePersistentClans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _localClans.map((c) => c.toJson()).toList();
      await prefs.setStringList(_persistentClansKey, jsonList);
    } catch (_) {}
  }

  /// Streams top clans ordered by totalPoints directly from Firestore
  Stream<List<Clan>> watchTopClans({String? region, int limit = 50}) {
    try {
      return _clans
          .snapshots(includeMetadataChanges: true)
          .map((snap) {
            final list = snap.docs.map((d) => Clan.fromDoc(d)).toList();
            // Merge with local newly created persistent clans if not yet committed
            for (final local in _localClans) {
              if (!list.any((c) => c.id == local.id)) {
                list.add(local);
              }
            }
            if (region != null && region.isNotEmpty && region != 'Barchasi') {
              list.retainWhere((c) => c.region.toLowerCase() == region.toLowerCase());
            }
            list.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
            return list;
          })
          .handleError((_) => _filterList(_localClans, region));
    } catch (_) {
      return Stream.value(_filterList(_localClans, region));
    }
  }

  List<Clan> _filterList(List<Clan> list, String? region) {
    if (region == null || region.isEmpty || region == 'Barchasi') return list;
    return list.where((c) => c.region.toLowerCase() == region.toLowerCase()).toList();
  }

  /// Streams a specific clan
  Stream<Clan?> watchClan(String clanId, {Clan? fallback}) {
    try {
      return _clans.doc(clanId).snapshots().map((snap) {
        if (!snap.exists) {
          final local = _localClans.where((c) => c.id == clanId).firstOrNull;
          return local ?? fallback;
        }
        return Clan.fromDoc(snap);
      }).handleError((_) {
        final local = _localClans.where((c) => c.id == clanId).firstOrNull;
        return local ?? fallback;
      });
    } catch (_) {
      final local = _localClans.where((c) => c.id == clanId).firstOrNull;
      return Stream.value(local ?? fallback);
    }
  }

  /// Creates a new Clan
  Future<String> createClan({
    required String name,
    required String tag,
    required String emblem,
    required String description,
    required UserProfile leader,
    String region = 'Navoiy',
  }) async {
    final cleanTag = tag.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final finalTag = cleanTag.isEmpty ? 'ODAT' : cleanTag.substring(0, cleanTag.length.clamp(1, 5));
    final clanId = 'clan_${DateTime.now().millisecondsSinceEpoch}';

    // Check 10,000 PTS requirement for clan creation
    if (leader.totalPoints < 10000) {
      throw Exception('Klan ochish uchun kamida 10,000 PTS kerak! Sizda: ${leader.totalPoints} PTS mavjud.');
    }

    // Auto-eject: If the user was a member of any other clan, remove them so they remain only in their created clan
    for (int i = 0; i < _localClans.length; i++) {
      final c = _localClans[i];
      if (c.memberUids.contains(leader.uid) && c.leaderId != leader.uid) {
        final updatedUids = c.memberUids.where((u) => u != leader.uid).toList();
        _localClans[i] = Clan(
          id: c.id,
          name: c.name,
          tag: c.tag,
          description: c.description,
          emblem: c.emblem,
          leaderId: c.leaderId,
          leaderName: c.leaderName,
          region: c.region,
          maxMembers: c.maxMembers,
          membersCount: updatedUids.length.clamp(1, c.maxMembers),
          totalPoints: (c.totalPoints - leader.totalPoints).clamp(0, 999999999),
          weeklyPoints: (c.weeklyPoints - leader.weeklyPoints).clamp(0, 999999999),
          memberUids: updatedUids,
          createdAt: c.createdAt,
        );
        try {
          _clans.doc(c.id).update({
            'memberUids': FieldValue.arrayRemove([leader.uid]),
            'membersCount': FieldValue.increment(-1),
          });
        } catch (_) {}
      }
    }

    final clan = Clan(
      id: clanId,
      name: name.trim(),
      tag: finalTag,
      description: description.trim(),
      emblem: emblem,
      leaderId: leader.uid,
      leaderName: leader.displayName ?? leader.name,
      region: region,
      maxMembers: 25,
      membersCount: 1,
      totalPoints: leader.totalPoints,
      weeklyPoints: leader.weeklyPoints,
      memberUids: [leader.uid],
      createdAt: DateTime.now(),
    );

    // Deduct 10,000 PTS and log to pts_history
    try {
      await _db.collection('users').doc(leader.uid).set({
        'totalPoints': FieldValue.increment(-10000),
        'weeklyPoints': FieldValue.increment(-10000),
      }, SetOptions(merge: true));

      await _db.collection('users').doc(leader.uid).collection('pts_history').add({
        'title': 'Yangi klan yaratish ($name)',
        'category': 'Klan',
        'amount': 10000,
        'type': 'spend',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // Save to local cache first so it reflects immediately and permanently
    _localClans.removeWhere((c) => c.id == clanId);
    _localClans.insert(0, clan);
    await _savePersistentClans();

    // Update user document
    try {
      await _db.collection('users').doc(leader.uid).set(
        {
          'clanId': clanId,
          'clanName': clan.name,
          'clanTag': clan.tag,
          'clanEmblem': clan.emblem,
          'clanDescription': clan.description,
          'clanRegion': clan.region,
          'isClanLeader': true,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}

    // Try creating doc in clans collection
    try {
      await _clans.doc(clanId).set(clan.toMap(), SetOptions(merge: true));
    } catch (_) {}

    _clansController.add(_localClans);
    return clanId;
  }

  /// Joins an existing clan (25 members max, costs 1500 PTS)
  Future<void> joinClan({
    required String clanId,
    required UserProfile user,
  }) async {
    final userMap = user.toCreateMap();
    final existingClanId = userMap['clanId'] as String?;
    if (user.isClanLeader || (existingClanId != null && existingClanId.isNotEmpty && existingClanId != clanId)) {
      throw Exception('Siz allaqachon klanga egasiz yoki a’zosiz! Bitta o‘yinchi faqat bitta klanda bo‘la oladi.');
    }

    if (user.totalPoints < 1500) {
      throw Exception('Klanga qo‘shilish uchun 1,500 PTS kerak! Sizda: ${user.totalPoints} PTS');
    }

    final localIndex = _localClans.indexWhere((c) => c.id == clanId);
    final current = localIndex != -1 ? _localClans[localIndex] : null;

    if (current != null && current.membersCount >= current.maxMembers) {
      throw Exception('Klan to‘lgan! Har bir klanga maksimal 25 tagacha a’zo qabul qilinadi.');
    }

    // Deduct 1500 PTS and log to pts_history
    try {
      await _db.collection('users').doc(user.uid).set({
        'totalPoints': FieldValue.increment(-1500),
        'weeklyPoints': FieldValue.increment(-1500),
      }, SetOptions(merge: true));

      await _db.collection('users').doc(user.uid).collection('pts_history').add({
        'title': 'Klanga a’zo bo‘lish to‘lovi',
        'category': 'Klan',
        'amount': 1500,
        'type': 'spend',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    Clan? targetClan;
    if (localIndex != -1 && current != null) {
      targetClan = current;
      if (!current.memberUids.contains(user.uid)) {
        final updatedUids = (current.memberUids.toSet()..add(user.uid)).toList();
        _localClans[localIndex] = Clan(
          id: current.id,
          name: current.name,
          tag: current.tag,
          description: current.description,
          emblem: current.emblem,
          leaderId: current.leaderId,
          leaderName: current.leaderName,
          region: current.region,
          maxMembers: 25,
          membersCount: updatedUids.length.clamp(1, 25),
          totalPoints: current.totalPoints + user.totalPoints,
          weeklyPoints: current.weeklyPoints + user.weeklyPoints,
          memberUids: updatedUids,
          createdAt: current.createdAt,
        );
        await _savePersistentClans();
      }
    }

    try {
      await _db.collection('users').doc(user.uid).set(
        {
          'clanId': clanId,
          'clanName': targetClan?.name ?? 'ODAT Klani',
          'clanTag': targetClan?.tag ?? 'ODAT',
          'clanEmblem': targetClan?.emblem ?? '🦅',
          'clanRegion': targetClan?.region ?? 'Navoiy',
        },
        SetOptions(merge: true),
      );
    } catch (_) {}

    try {
      await _clans.doc(clanId).set({
        'memberUids': FieldValue.arrayUnion([user.uid]),
        'membersCount': FieldValue.increment(1),
        'totalPoints': FieldValue.increment(user.totalPoints),
        'weeklyPoints': FieldValue.increment(user.weeklyPoints),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Leaves current clan
  Future<void> leaveClan({
    required String clanId,
    required UserProfile user,
  }) async {
    final localIndex = _localClans.indexWhere((c) => c.id == clanId);
    if (localIndex != -1) {
      final current = _localClans[localIndex];
      final updatedUids = current.memberUids.where((u) => u != user.uid).toSet().toList();
      _localClans[localIndex] = Clan(
        id: current.id,
        name: current.name,
        tag: current.tag,
        description: current.description,
        emblem: current.emblem,
        leaderId: current.leaderId,
        leaderName: current.leaderName,
        region: current.region,
        maxMembers: 25,
        membersCount: updatedUids.isNotEmpty ? updatedUids.length.clamp(1, 25) : 1,
        totalPoints: (current.totalPoints - user.totalPoints).clamp(0, 99999999),
        weeklyPoints: (current.weeklyPoints - user.weeklyPoints).clamp(0, 99999999),
        memberUids: updatedUids,
        createdAt: current.createdAt,
      );
      await _savePersistentClans();
    }

    try {
      await _db.collection('users').doc(user.uid).set(
        {
          'clanId': null,
          'clanName': null,
          'clanTag': null,
          'clanEmblem': null,
          'clanRegion': null,
          'isClanLeader': false,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}

    try {
      final doc = await _clans.doc(clanId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final currentTotal = (data['totalPoints'] as num?)?.toInt() ?? 0;
        final currentWeekly = (data['weeklyPoints'] as num?)?.toInt() ?? 0;
        final newTotal = (currentTotal - user.totalPoints).clamp(0, 999999999);
        final newWeekly = (currentWeekly - user.weeklyPoints).clamp(0, 999999999);
        await _clans.doc(clanId).update({
          'memberUids': FieldValue.arrayRemove([user.uid]),
          'membersCount': FieldValue.increment(-1),
          'totalPoints': newTotal,
          'weeklyPoints': newWeekly,
        });
      }
    } catch (_) {}
  }

  /// Toggles clan open/closed status (Ochiq / Yopiq)
  Future<void> togglePrivacy({required String clanId, required bool isPublic}) async {
    final localIndex = _localClans.indexWhere((c) => c.id == clanId);
    if (localIndex != -1) {
      final current = _localClans[localIndex];
      _localClans[localIndex] = Clan(
        id: current.id,
        name: current.name,
        tag: current.tag,
        description: current.description,
        emblem: current.emblem,
        leaderId: current.leaderId,
        leaderName: current.leaderName,
        region: current.region,
        maxMembers: current.maxMembers,
        membersCount: current.membersCount,
        totalPoints: current.totalPoints,
        weeklyPoints: current.weeklyPoints,
        memberUids: current.memberUids,
        isPublic: isPublic,
        createdAt: current.createdAt,
      );
      await _savePersistentClans();
    }

    try {
      await _clans.doc(clanId).update({'isPublic': isPublic});
    } catch (_) {}
  }

  /// Updates Clan Settings (Leader only: public/private, description, region, name)
  Future<void> updateClanSettings({
    required String clanId,
    bool? isPublic,
    String? description,
    String? region,
    String? name,
  }) async {
    final updates = <String, dynamic>{
      if (isPublic != null) 'isPublic': isPublic,
      if (description != null) 'description': description.trim(),
      if (region != null) 'region': region,
      if (name != null) 'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final localIndex = _localClans.indexWhere((c) => c.id == clanId);
    if (localIndex != -1) {
      final cur = _localClans[localIndex];
      _localClans[localIndex] = Clan(
        id: cur.id,
        name: name ?? cur.name,
        tag: cur.tag,
        description: description ?? cur.description,
        emblem: cur.emblem,
        leaderId: cur.leaderId,
        leaderName: cur.leaderName,
        region: region ?? cur.region,
        maxMembers: cur.maxMembers,
        membersCount: cur.membersCount,
        totalPoints: cur.totalPoints,
        weeklyPoints: cur.weeklyPoints,
        memberUids: cur.memberUids,
        isPublic: isPublic ?? cur.isPublic,
        createdAt: cur.createdAt,
      );
      await _savePersistentClans();
    }

    try {
      await _clans.doc(clanId).set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Removes a member from clan (Leader kick)
  Future<void> removeClanMember({
    required String clanId,
    required String targetUid,
  }) async {
    final localIndex = _localClans.indexWhere((c) => c.id == clanId);
    if (localIndex != -1) {
      final cur = _localClans[localIndex];
      final newUids = cur.memberUids.where((u) => u != targetUid).toList();
      _localClans[localIndex] = Clan(
        id: cur.id,
        name: cur.name,
        tag: cur.tag,
        description: cur.description,
        emblem: cur.emblem,
        leaderId: cur.leaderId,
        leaderName: cur.leaderName,
        region: cur.region,
        maxMembers: cur.maxMembers,
        membersCount: (cur.membersCount - 1).clamp(1, 25),
        totalPoints: cur.totalPoints,
        weeklyPoints: cur.weeklyPoints,
        memberUids: newUids,
        isPublic: cur.isPublic,
        createdAt: cur.createdAt,
      );
      await _savePersistentClans();
    }

    try {
      await _clans.doc(clanId).update({
        'memberUids': FieldValue.arrayRemove([targetUid]),
        'membersCount': FieldValue.increment(-1),
      });
    } catch (_) {}

    try {
      await _db.collection('users').doc(targetUid).set({
        'clanId': null,
        'clanName': null,
        'clanTag': null,
        'clanEmblem': null,
        'isClanLeader': false,
      }, SetOptions(merge: true));
    } catch (_) {}

    unawaited(recalculateClanPoints(clanId));
  }

  /// Calculates real live total points by summing points of all current clan members
  Future<int> recalculateClanPoints(String clanId) async {
    try {
      final doc = await _clans.doc(clanId).get();
      if (!doc.exists) return 0;
      final uids = List<String>.from(doc.data()?['memberUids'] ?? []);
      if (uids.isEmpty) return 0;

      int total = 0;
      int weekly = 0;
      final chunks = <List<String>>[];
      for (var i = 0; i < uids.length; i += 10) {
        chunks.add(uids.sublist(i, (i + 10 > uids.length) ? uids.length : i + 10));
      }

      for (final chunk in chunks) {
        final usersSnap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        for (final uDoc in usersSnap.docs) {
          final uData = uDoc.data();
          total += (uData['totalPoints'] as num?)?.toInt() ?? 0;
          weekly += (uData['weeklyPoints'] as num?)?.toInt() ?? 0;
        }
      }

      await _clans.doc(clanId).update({
        'totalPoints': total.clamp(0, 999999999),
        'weeklyPoints': weekly.clamp(0, 999999999),
      });

      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Fetches details of clan members with their live total and weekly PTS
  Future<List<ClanMemberItem>> fetchClanMembers(String clanId, List<String> memberUids) async {
    if (memberUids.isEmpty) return [];
    try {
      final chunks = <List<String>>[];
      for (var i = 0; i < memberUids.length; i += 10) {
        chunks.add(memberUids.sublist(i, (i + 10 > memberUids.length) ? memberUids.length : i + 10));
      }

      final members = <ClanMemberItem>[];
      for (final chunk in chunks) {
        final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        for (final d in snap.docs) {
          final data = d.data();
          members.add(ClanMemberItem(
            uid: d.id,
            name: (data['displayName'] ?? data['name'] ?? 'Jangchi').toString(),
            role: (data['isClanLeader'] == true) ? 'Lider' : 'A\'zo',
            avatar: (data['avatar'] ?? '🦅').toString(),
            points: (data['totalPoints'] as num?)?.toInt() ?? 0,
            weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
          ));
        }
      }
      members.sort((a, b) => b.points.compareTo(a.points));
      return members;
    } catch (_) {
      return [];
    }
  }
}
