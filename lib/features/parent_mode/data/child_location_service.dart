import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';

import '../../../../core/services/firebase_providers.dart';

final childLocationServiceProvider = Provider<ChildLocationService>((ref) {
  return ChildLocationService(ref.watch(firestoreProvider));
});

class ChildLocationService {
  ChildLocationService(this._db);

  final FirebaseFirestore _db;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _periodicFallbackTimer;
  String? _activeChildUid;
  Position? _lastPosition;
  DateTime? _lastHistoryWrite;

  Position? get lastPosition => _lastPosition;

  /// Starts listening to GPS position and streams updates to Firestore in real time.
  Future<bool> startTracking(String childUid) async {
    _activeChildUid = childUid;
    stopTracking();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services are disabled.');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permissions are permanently denied.');
        return false;
      }

      // 1. Initial immediate location push
      try {
        final initialPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _lastPosition = initialPos;
        await _pushLocationToFirestore(childUid, initialPos);
      } catch (e) {
        debugPrint('⚠️ Initial position fetch timeout/failed: $e');
      }

      // 2. Continuous real-time position stream (5 meters threshold)
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position pos) {
          _lastPosition = pos;
          _pushLocationToFirestore(childUid, pos);
        },
        onError: (err) {
          debugPrint('⚠️ Geolocator stream error: $err');
        },
      );

      // 3. Periodic heartbeat (every 30 seconds even if stationary)
      _periodicFallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (_activeChildUid != null && _lastPosition != null) {
          await _pushLocationToFirestore(_activeChildUid!, _lastPosition!);
        }
      });

      debugPrint('🛰️ Real-time GPS tracking started for child: $childUid');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error starting GPS tracking: $e');
      return false;
    }
  }

  Future<void> _pushLocationToFirestore(String childUid, Position pos) async {
    try {
      final speedKmh = (pos.speed * 3.6).clamp(0.0, 200.0);
      
      int batteryLevel = 0;
      bool isCharging = false;
      try {
        final battery = Battery();
        batteryLevel = await battery.batteryLevel;
        final state = await battery.batteryState;
        isCharging = state == BatteryState.charging || state == BatteryState.full;
      } catch (e) {
        debugPrint('⚠️ Error fetching battery: $e');
      }

      // Save live position in child's live_location document
      await _db
          .collection('users')
          .doc(childUid)
          .collection('live_location')
          .doc('current')
          .set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speedKmh': speedKmh,
        'heading': pos.heading,
        'accuracy': pos.accuracy,
        'altitude': pos.altitude,
        'isOnline': true,
        'batteryLevel': batteryLevel,
        'isCharging': isCharging,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update main user doc for quick parent previews
      await _db.collection('users').doc(childUid).set({
        'locationLat': pos.latitude,
        'locationLng': pos.longitude,
        'speedKmh': speedKmh,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));

      // Throttled Route History Write (Every 30 seconds max)
      final now = DateTime.now();
      if (_lastHistoryWrite == null || now.difference(_lastHistoryWrite!).inSeconds > 30) {
        _lastHistoryWrite = now;
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        
        await _db
            .collection('users')
            .doc(childUid)
            .collection('location_history')
            .doc(todayStr)
            .set({
          'points': FieldValue.arrayUnion([{
            'lat': pos.latitude,
            'lng': pos.longitude,
            'timestamp': now.millisecondsSinceEpoch,
          }])
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('⚠️ Error pushing location to Firestore: $e');
    }
  }

  /// Stops tracking GPS
  Future<void> stopTracking() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicFallbackTimer?.cancel();
    _periodicFallbackTimer = null;

    if (_activeChildUid != null) {
      try {
        await _db
            .collection('users')
            .doc(_activeChildUid!)
            .collection('live_location')
            .doc('current')
            .set({'isOnline': false, 'updatedAt': FieldValue.serverTimestamp()},
                SetOptions(merge: true));
      } catch (_) {}
      _activeChildUid = null;
    }
  }
}
