import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../domain/models/defense_structure.dart';
import '../domain/models/run_session.dart';
import '../domain/models/territory_battle.dart';
import '../domain/models/territory_polygon.dart';

/// Repository handling Firestore persistence for running sessions,
/// global conquered territories, defense structures, and territory battles.
class RunningRepository {
  RunningRepository(this._db, this._userRepository);

  final FirebaseFirestore _db;
  final UserRepository _userRepository;

  CollectionReference<Map<String, dynamic>> _runSessionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('runSessions');

  /// Saves a completed run session to Firestore and awards earned points to the user.
  Future<void> saveRunSession(RunSession session) async {
    final docRef = _runSessionsRef(session.userId).doc(session.id);
    await docRef.set(session.toMap());

    if (session.pointsEarned > 0) {
      await _userRepository.awardPoints(session.userId, session.pointsEarned);
    }

    final distanceKm = session.distanceKm;
    if (distanceKm > 0) {
      await _db.collection('users').doc(session.userId).set({
        'runningDistanceKm': FieldValue.increment(distanceKm),
        'totalRunningKm': FieldValue.increment(distanceKm),
      }, SetOptions(merge: true));
    }
  }

  /// Streams the user's completed run sessions ordered by start date.
  Stream<List<RunSession>> watchRunSessions(String uid) {
    return _runSessionsRef(uid)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => RunSession.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  /// Persists a conquered polygon territory to Firestore so all runners see persistent conquered areas
  Future<String> saveConqueredTerritory({
    required String uid,
    required String userName,
    required String clanTag,
    required List<Map<String, double>> points,
    required double areaSqMeters,
    String? clanId,
    String? clanName,
    String? ownerAvatar,
    double? centroidLat,
    double? centroidLng,
  }) async {
    final territoryRef = _db.collection('global_territories').doc();
    await territoryRef.set({
      'id': territoryRef.id,
      'schemaVersion': 2,
      'uid': uid,
      'userName': userName,
      'clanTag': clanTag,
      'clanId': clanId,
      'clanName': clanName,
      'ownerAvatar': ownerAvatar,
      'points': points,
      'areaSqMeters': areaSqMeters,
      'status': 'owned',
      'centroidLat': centroidLat,
      'centroidLng': centroidLng,
      'conqueredAt': FieldValue.serverTimestamp(),
    });
    return territoryRef.id;
  }

  /// Transfers ownership of territory after successful battle attack
  Future<void> transferTerritoryOwnership({
    required String territoryId,
    required String newOwnerUid,
    required String newOwnerName,
    String? newOwnerAvatar,
    String? clanTag,
    String? clanId,
  }) async {
    try {
      await _db.collection('global_territories').doc(territoryId).update({
        'uid': newOwnerUid,
        'userName': newOwnerName,
        'ownerAvatar': newOwnerAvatar,
        'clanTag': clanTag ?? '',
        'clanId': clanId,
        'status': 'owned',
        'conqueredAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Updates territory status (e.g. 'owned', 'contested', 'under_attack')
  Future<void> updateTerritoryStatus(String territoryId, String status) async {
    try {
      await _db.collection('global_territories').doc(territoryId).update({
        'status': status,
      });
    } catch (_) {}
  }

  /// Streams all players' conquered territories to render on the running map (v2 only)
  Stream<List<TerritoryPolygon>> watchAllConqueredTerritories() {
    return _db
        .collection('global_territories')
        .where('schemaVersion', isEqualTo: 2)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TerritoryPolygon.fromMap(d.data(), id: d.id))
            .toList())
        .handleError((_) => <TerritoryPolygon>[]);
  }

  // ── DEFENSE STRUCTURES ────────────────────────────────────────────────────

  /// Places a new defense structure inside an owned territory
  Future<void> saveDefenseStructure(DefenseStructure structure) async {
    final docRef = _db.collection('territory_defenses').doc(structure.id);
    await docRef.set(structure.toMap());
  }

  /// Upgrades an existing defense structure level and stats
  Future<void> upgradeDefenseStructure({
    required String structureId,
    required int newLevel,
    required int newHp,
    required int newMaxHp,
    required int newAttack,
    required int newDefense,
    required String name,
    required String icon,
  }) async {
    try {
      await _db.collection('territory_defenses').doc(structureId).update({
        'level': newLevel,
        'hp': newHp,
        'maxHp': newMaxHp,
        'attackPower': newAttack,
        'defensePower': newDefense,
        'name': name,
        'icon': icon,
        'upgradedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Streams all defense structures for all territories
  Stream<List<DefenseStructure>> watchAllDefenseStructures() {
    return _db
        .collection('territory_defenses')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DefenseStructure.fromMap(d.data(), id: d.id))
            .toList())
        .handleError((_) => <DefenseStructure>[]);
  }

  /// Streams defense structures for a specific territory
  Stream<List<DefenseStructure>> watchTerritoryDefenses(String territoryId) {
    return _db
        .collection('territory_defenses')
        .where('territoryId', isEqualTo: territoryId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DefenseStructure.fromMap(d.data(), id: d.id))
            .toList())
        .handleError((_) => <DefenseStructure>[]);
  }

  // ── TERRITORY BATTLES ─────────────────────────────────────────────────────

  /// Records battle event into Firestore
  Future<void> recordTerritoryBattle(TerritoryBattleEvent battle) async {
    try {
      await _db.collection('territory_battles').doc(battle.id).set(battle.toMap());
    } catch (_) {}
  }

  // ── LIVE ACTIVE RUNNERS ───────────────────────────────────────────────────

  /// Updates current active runner's live GPS coordinate and path so others see them on the map
  Future<void> updateActiveRunnerLocation({
    required String uid,
    required String userName,
    required String clanTag,
    required double latitude,
    required double longitude,
    required double heading,
    required double speedKmh,
    String? avatar,
    String? photoUrl,
    String? photoBase64,
    double distanceKm = 0.0,
    List<Map<String, double>>? trail,
  }) async {
    try {
      await _db.collection('active_runners').doc(uid).set({
        'uid': uid,
        'userName': userName,
        'clanTag': clanTag,
        'lat': latitude,
        'lng': longitude,
        'heading': heading,
        'speedKmh': speedKmh,
        'avatar': avatar,
        'photoUrl': photoUrl,
        'photoBase64': photoBase64,
        'distanceKm': distanceKm,
        if (trail != null) 'trail': trail,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Removes runner from active runners when workout ends
  Future<void> removeActiveRunner(String uid) async {
    try {
      await _db.collection('active_runners').doc(uid).delete();
    } catch (_) {}
  }

  /// Streams other live runners active in real time
  Stream<List<Map<String, dynamic>>> watchActiveRunners(String myUid) {
    return _db
        .collection('active_runners')
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => d.data())
              .where((d) => d['uid'] != myUid && d['lat'] != null && d['lng'] != null)
              .toList();
        })
        .handleError((_) => <Map<String, dynamic>>[]);
  }
}

final runningRepositoryProvider = Provider<RunningRepository>(
  (ref) => RunningRepository(
    ref.watch(firestoreProvider),
    ref.watch(userRepositoryProvider),
  ),
);
