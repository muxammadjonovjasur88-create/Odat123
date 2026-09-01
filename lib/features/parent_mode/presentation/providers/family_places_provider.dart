import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../domain/family_place_models.dart';
import 'family_providers.dart'; // To get childUid

final familyPlacesProvider = NotifierProvider<FamilyPlacesNotifier, List<FamilyPlace>>(() {
  return FamilyPlacesNotifier();
});

class FamilyPlacesNotifier extends Notifier<List<FamilyPlace>> {
  @override
  List<FamilyPlace> build() {
    _listenToSafeZones();
    return [];
  }

  void _listenToSafeZones() {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    
    final db = ref.read(firestoreProvider);
    db
        .collection('users')
        .doc(uid)
        .collection('safe_zones')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      final places = snap.docs.map((doc) => FamilyPlace.fromMap(doc.data())).toList();
      state = places;
    }, onError: (e) {
      debugPrint('⚠️ Error streaming safe zones: $e');
    });
  }

  Future<void> addPlace({
    required String name,
    required String iconName,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required String address,
    bool notifyOnArrival = true,
    bool notifyOnDeparture = true,
  }) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    final placeId = 'place_${DateTime.now().millisecondsSinceEpoch}';
    final newPlace = FamilyPlace(
      id: placeId,
      name: name,
      iconName: iconName,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      notifyOnArrival: notifyOnArrival,
      notifyOnDeparture: notifyOnDeparture,
      address: address,
      createdAt: DateTime.now(),
    );

    state = [newPlace, ...state];

    try {
      await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('safe_zones')
          .doc(placeId)
          .set(newPlace.toMap());
    } catch (e) {
      debugPrint('⚠️ Error saving safe zone: $e');
    }
  }

  Future<void> removePlace(String id) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    state = state.where((p) => p.id != id).toList();

    try {
      await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('safe_zones')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint('⚠️ Error deleting safe zone: $e');
    }
  }

  Future<void> toggleArrivalAlert(String id, bool val) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    state = state.map((p) => p.id == id ? p.copyWith(notifyOnArrival: val) : p).toList();
    try {
      await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('safe_zones')
          .doc(id)
          .update({'notifyOnArrival': val});
    } catch (_) {}
  }

  Future<void> toggleDepartureAlert(String id, bool val) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    state = state.map((p) => p.id == id ? p.copyWith(notifyOnDeparture: val) : p).toList();
    try {
      await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('safe_zones')
          .doc(id)
          .update({'notifyOnDeparture': val});
    } catch (_) {}
  }
}

/// Today's Place Events — Streamed from Firestore
final todayPlaceEventsProvider = StreamProvider.autoDispose<List<PlaceEvent>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value([]);
  
  // We need childUid to get child's location events
  final status = ref.watch(childLiveStatusProvider).value;
  final childUid = status?.childUid;
  if (childUid == null) return Stream.value([]);

  final db = ref.watch(firestoreProvider);
  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  return db
      .collection('users')
      .doc(childUid)
      .collection('location_events')
      .where('dateStr', isEqualTo: todayStr)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => PlaceEvent.fromMap(d.data())).toList());
});

/// Route history for a given day
final routeHistoryProvider = StreamProvider.autoDispose.family<DayRouteHistory, DateTime>((ref, date) {
  final status = ref.watch(childLiveStatusProvider).value;
  final childUid = status?.childUid;
  if (childUid == null) {
    return Stream.value(DayRouteHistory(date: date, totalDistanceKm: 0, points: [], events: []));
  }

  final db = ref.watch(firestoreProvider);
  final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  return db
      .collection('users')
      .doc(childUid)
      .collection('location_history')
      .doc(dateStr)
      .snapshots()
      .map((snap) {
        if (!snap.exists) return DayRouteHistory(date: date, totalDistanceKm: 0, points: [], events: []);
        return DayRouteHistory.fromMap(snap.data()!);
      });
});
