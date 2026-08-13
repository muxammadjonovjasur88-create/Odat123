import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/firebase_providers.dart';
import '../domain/lobby.dart';

/// Outcome of trying to join a lobby by code.
enum JoinResult { ok, notFound, full, alreadyMember, error }

/// Firestore operations for private competition lobbies.
class LobbyRepository {
  LobbyRepository(this._db);

  final FirebaseFirestore _db;

  // No ambiguous characters (0/O/1/I) so codes are easy to read + type.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('lobbies');

  /// Lobbies the user belongs to, newest first.
  Stream<List<Lobby>> watchMyLobbies(String uid) => _col
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map(
        (q) => q.docs.map(Lobby.fromDoc).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
              a.createdAt ?? DateTime(2000),
            ),
          ),
      );

  Stream<Lobby?> watchLobby(String id) =>
      _col.doc(id).snapshots().map((s) => s.exists ? Lobby.fromDoc(s) : null);

  /// Live profiles of a lobby's members, ranked by weekly (honest) points.
  /// `whereIn` on the document id supports up to 30 ids — within the member cap.
  Stream<List<UserProfile>> watchMembers(List<String> uids) {
    if (uids.isEmpty) return Stream.value(const []);
    return _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .snapshots()
        .map((q) {
          final list = q.docs.map(UserProfile.fromDoc).toList()
            ..sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));
          return list;
        });
  }

  /// Creates a lobby owned by [uid] with a unique-ish join code.
  /// Season 1 starts immediately at creation with [kDefaultSeasonDays] duration.
  Future<Lobby> createLobby({required String uid, required String name}) async {
    var code = _generateCode();
    for (var i = 0; i < 3; i++) {
      final existing = await _col.where('code', isEqualTo: code).limit(1).get();
      if (existing.docs.isEmpty) break;
      code = _generateCode();
    }

    final cleanName = name.trim().isEmpty ? 'Focus Circle' : name.trim();
    final now = DateTime.now().toUtc();
    final seasonStart = _utcMidnight(now);

    final ref = await _col.add({
      'name': cleanName,
      'code': code,
      'creatorUid': uid,
      'memberUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
      // Legacy field kept for backwards-compat.
      'weekStart': Timestamp.fromDate(_mondayOf(DateTime.now())),
      // Season fields.
      'seasonDurationDays': kDefaultSeasonDays,
      'seasonNumber': 1,
      'seasonStart': Timestamp.fromDate(seasonStart),
      'seasonWinners': [],
    });
    final snap = await ref.get();
    return Lobby.fromDoc(snap);
  }

  /// Joins the lobby with [code]. Atomic: enforces the member cap + no dupes.
  /// Returns the outcome and, when known, the lobby id (to navigate to it).
  Future<({JoinResult result, String? lobbyId})> joinByCode({
    required String uid,
    required String code,
  }) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) return (result: JoinResult.notFound, lobbyId: null);

    final q = await _col.where('code', isEqualTo: normalized).limit(1).get();
    if (q.docs.isEmpty) return (result: JoinResult.notFound, lobbyId: null);
    final ref = q.docs.first.reference;

    try {
      final result = await _db.runTransaction<JoinResult>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? const {};
        final members =
            (data['memberUids'] as List?)?.whereType<String>().toList() ??
            <String>[];
        if (members.contains(uid)) return JoinResult.alreadyMember;
        if (members.length >= kLobbyMemberLimit) return JoinResult.full;
        tx.update(ref, {
          'memberUids': FieldValue.arrayUnion([uid]),
        });
        return JoinResult.ok;
      });
      return (result: result, lobbyId: ref.id);
    } catch (_) {
      return (result: JoinResult.error, lobbyId: null);
    }
  }

  /// Removes [uid] from the lobby; deletes the lobby if it becomes empty.
  Future<void> leaveLobby({required String uid, required String lobbyId}) {
    final ref = _col.doc(lobbyId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final members =
          (snap.data()!['memberUids'] as List?)?.whereType<String>().toList() ??
          <String>[];
      members.remove(uid);
      if (members.isEmpty) {
        tx.delete(ref);
      } else {
        tx.update(ref, {'memberUids': members});
      }
    });
  }

  /// Rolls the season forward if [lobby.seasonStart] + [lobby.seasonDurationDays]
  /// is in the past. Records the current leader as the season winner, increments
  /// [seasonNumber], and advances [seasonStart] to the next season.
  ///
  /// Handles multiple consecutive missed rollovers (e.g. app was offline for
  /// several seasons) via an elapsed-seasons loop.
  ///
  /// Best-effort; only the first viewer in the new season triggers the write.
  Future<void> rollSeasonIfNeeded(
    Lobby lobby,
    List<UserProfile> rankedMembers,
  ) async {
    final start = lobby.seasonStart;
    if (start == null || rankedMembers.isEmpty) return;

    final now = DateTime.now().toUtc();
    if (!now.isAfter(start.add(Duration(days: lobby.seasonDurationDays)))) {
      return; // Season not over yet.
    }

    // Count how many full seasons have elapsed since [start].
    int elapsed = 0;
    DateTime cursor = start;
    while (now.isAfter(cursor.add(Duration(days: lobby.seasonDurationDays)))) {
      cursor = cursor.add(Duration(days: lobby.seasonDurationDays));
      elapsed++;
    }
    if (elapsed == 0) return;

    final top = rankedMembers.first;

    // Prepend the new winner; keep at most kMaxSeasonHistory entries.
    final newWinner = LobbyWinner(
      uid: top.uid,
      name: top.name,
      avatar: top.avatar,
      points: top.weeklyPoints,
      seasonStart: start,
      seasonNumber: lobby.seasonNumber,
    );
    final updatedWinners = [
      newWinner.toMap(),
      ...lobby.seasonWinners.take(kMaxSeasonHistory - 1).map((w) => w.toMap()),
    ];

    await _col.doc(lobby.id).set({
      'seasonNumber': lobby.seasonNumber + elapsed,
      'seasonStart': Timestamp.fromDate(cursor),
      'seasonWinners': updatedWinners,
      // Keep legacy lastWinner pointing to the most recent winner.
      'lastWinner': newWinner.toMap(),
      // Legacy weekStart update.
      'weekStart': Timestamp.fromDate(_mondayOf(DateTime.now())),
    }, SetOptions(merge: true));
  }

  /// Legacy weekly rollover — kept for backwards-compat with old lobby docs
  /// that don't have [seasonStart] yet. Migrates them to the season system on
  /// first call.
  Future<void> rollWeekIfNeeded(
    Lobby lobby,
    List<UserProfile> rankedMembers,
  ) async {
    // If the lobby already has a seasonStart, delegate to the season system.
    if (lobby.seasonStart != null) {
      return rollSeasonIfNeeded(lobby, rankedMembers);
    }

    // Legacy path: migrate old weekly lobby to season system.
    final monday = _mondayOf(DateTime.now());
    final lobbyWeek = lobby.weekStart == null
        ? null
        : DateUtils.dateOnly(lobby.weekStart!);
    if (lobbyWeek == null ||
        !monday.isAfter(lobbyWeek) ||
        rankedMembers.isEmpty) {
      return;
    }
    final top = rankedMembers.first;
    final winner = LobbyWinner(
      uid: top.uid,
      name: top.name,
      avatar: top.avatar,
      points: top.weeklyPoints,
      seasonStart: lobbyWeek,
      seasonNumber: 1,
    );
    // Migrate to season system.
    await _col.doc(lobby.id).set({
      'weekStart': Timestamp.fromDate(monday),
      'lastWinner': winner.toMap(),
      // Initialize season fields for this lobby.
      'seasonDurationDays': kDefaultSeasonDays,
      'seasonNumber': 2,
      'seasonStart': Timestamp.fromDate(_utcMidnight(DateTime.now().toUtc())),
      'seasonWinners': [winner.toMap()],
    }, SetOptions(merge: true));
  }

  /// Normalizes user-typed codes: upper-cases, trims, and adds the FLOWA-
  /// prefix if the user only typed the suffix.
  static String normalizeCode(String input) {
    var c = input.trim().toUpperCase().replaceAll(' ', '');
    if (c.isEmpty) return '';
    if (!c.startsWith('FLOWA-')) {
      c = c.startsWith('FLOWA')
          ? c.replaceFirst('FLOWA', 'FLOWA-')
          : 'FLOWA-$c';
    }
    return c;
  }

  String _generateCode([int length = 4]) {
    final r = Random.secure();
    final chars = List.generate(
      length,
      (_) => _alphabet[r.nextInt(_alphabet.length)],
    ).join();
    return 'FLOWA-$chars';
  }

  /// Returns UTC midnight on [d].
  static DateTime _utcMidnight(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day);

  static DateTime _mondayOf(DateTime d) {
    final date = DateUtils.dateOnly(d);
    return date.subtract(Duration(days: date.weekday - 1));
  }
}

final lobbyRepositoryProvider = Provider<LobbyRepository>(
  (ref) => LobbyRepository(ref.watch(firestoreProvider)),
);

final _lobbyUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).asData?.value?.uid,
);

/// The lobbies the signed-in user is a member of. autoDispose so the Firestore
/// stream is cancelled when no screen is listening.
final myLobbiesProvider = StreamProvider.autoDispose<List<Lobby>>((ref) {
  final uid = ref.watch(_lobbyUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(lobbyRepositoryProvider).watchMyLobbies(uid);
});

/// A single lobby, live. autoDispose so the stream is cancelled when the lobby
/// detail screen is popped (prevents dangling listeners on teardown).
final lobbyProvider = StreamProvider.autoDispose.family<Lobby?, String>(
  (ref, id) => ref.watch(lobbyRepositoryProvider).watchLobby(id),
);

/// A lobby's members ranked by weekly points, live (re-subscribes when the
/// member list changes). autoDispose alongside the detail screen.
final lobbyMembersProvider = StreamProvider.autoDispose
    .family<List<UserProfile>, String>((ref, id) {
      final lobby = ref.watch(lobbyProvider(id)).asData?.value;
      if (lobby == null || lobby.memberUids.isEmpty) {
        return Stream.value(const []);
      }
      return ref.watch(lobbyRepositoryProvider).watchMembers(lobby.memberUids);
    });
