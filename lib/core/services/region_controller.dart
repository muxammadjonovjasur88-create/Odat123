import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/uzbekistan_regions.dart';
import 'auth_repository.dart';
import 'firebase_providers.dart';
import 'location_service.dart';

// ---------------------------------------------------------------------------
// RegionController — the single source of truth for the current user's region
// ---------------------------------------------------------------------------

/// State machine for the user's region.
enum RegionStatus {
  /// Initial — nothing loaded yet.
  initial,

  /// Loading: GPS + geocoding in progress.
  loading,

  /// Region successfully resolved and persisted.
  loaded,

  /// Could not determine region (permission denied, GPS off, unknown area).
  unavailable,
}

class RegionState {
  const RegionState({
    this.region,
    this.status = RegionStatus.initial,
    this.errorMessage,
  });

  final UzRegion? region;
  final RegionStatus status;

  /// Human-readable message for snackbar / settings UI (null when no error).
  final String? errorMessage;

  RegionState copyWith({
    UzRegion? region,
    RegionStatus? status,
    String? errorMessage,
  }) =>
      RegionState(
        region: region ?? this.region,
        status: status ?? this.status,
        errorMessage: errorMessage,
      );
}

// ---------------------------------------------------------------------------

/// Manages the current user's region: reads from Firestore, detects via GPS,
/// and writes back. All heavy work is async so the UI is never blocked.
///
/// Uses Riverpod v3 [Notifier] pattern (not the deprecated StateNotifier).
class RegionController extends Notifier<RegionState> {
  static const _regionField = 'region';

  FirebaseFirestore get _db => ref.read(firestoreProvider);

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  RegionState build() {
    // Kick off async init without blocking the synchronous build.
    Future.microtask(_init);
    return const RegionState();
  }

  // ---------------------------------------------------------------------------
  // Init: load from Firestore cache
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      final snap = await _userDoc(uid).get();
      final key = snap.data()?[_regionField] as String?;
      final saved = UzRegion.fromFirestoreKey(key);

      if (saved != null) {
        state = RegionState(region: saved, status: RegionStatus.loaded);
        debugPrint('[RegionController] Loaded from Firestore: ${saved.displayName}');
        return;
      }
    } catch (_) {
      // Firestore unavailable — continue to GPS detection
    }

    // No saved region → attempt GPS detection automatically on first run.
    await detectAndSave();
  }

  // ---------------------------------------------------------------------------
  // GPS detection
  // ---------------------------------------------------------------------------

  /// Detects the user's region via GPS and saves it. Safe to call from UI.
  Future<void> detectAndSave() async {
    final uid = _currentUid;
    if (uid == null) return;

    state = state.copyWith(status: RegionStatus.loading);

    final result = await ref.read(locationServiceProvider).detectRegion();

    switch (result) {
      case RegionDetected(:final region):
        await _persist(uid, region);
        state = RegionState(region: region, status: RegionStatus.loaded);

      case RegionPermissionDenied():
        state = state.copyWith(
          status: RegionStatus.unavailable,
          errorMessage: 'Joylashuv ruxsati berilmadi.',
        );

      case RegionLocationDisabled():
        state = state.copyWith(
          status: RegionStatus.unavailable,
          errorMessage: 'GPS o\'chirilgan.',
        );

      case RegionNotRecognised(:final adminArea):
        state = state.copyWith(
          status: RegionStatus.unavailable,
          errorMessage: adminArea != null
              ? '"$adminArea" O\'zbekiston viloyatlariga mos kelmadi.'
              : 'Viloyat aniqlanmadi.',
        );

      case RegionError(:final message):
        state = state.copyWith(
          status: RegionStatus.unavailable,
          errorMessage: 'Xato: $message',
        );
    }
  }

  /// Manually sets a region (when user picks from the dropdown fallback).
  Future<void> setManually(UzRegion region) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _persist(uid, region);
    state = RegionState(region: region, status: RegionStatus.loaded);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? get _currentUid =>
      ref.read(authStateProvider).asData?.value?.uid;

  Future<void> _persist(String uid, UzRegion region) async {
    try {
      await _db.collection('users').doc(uid).set(
        {_regionField: region.firestoreKey},
        SetOptions(merge: true),
      );
      debugPrint('[RegionController] Saved region=${region.firestoreKey}');
    } catch (e) {
      debugPrint('[RegionController] Failed to persist region: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final regionControllerProvider =
    NotifierProvider<RegionController, RegionState>(RegionController.new);

/// Convenience: the resolved region, or null.
final currentRegionProvider = Provider<UzRegion?>((ref) {
  return ref.watch(regionControllerProvider).region;
});
