import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/uzbekistan_regions.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Result of a region-detection attempt, capturing both success and every
/// failure mode so the UI can show appropriate messages.
sealed class RegionResult {
  const RegionResult();
}

/// Region successfully detected.
final class RegionDetected extends RegionResult {
  const RegionDetected(this.region);
  final UzRegion region;
}

/// User denied location permission.
final class RegionPermissionDenied extends RegionResult {
  const RegionPermissionDenied();
}

/// Location service is off or permanently denied.
final class RegionLocationDisabled extends RegionResult {
  const RegionLocationDisabled();
}

/// Device returned a position but geocoding could not identify a known Uzbek
/// region (e.g. user is abroad or geocoding API failed).
final class RegionNotRecognised extends RegionResult {
  const RegionNotRecognised(this.adminArea);

  /// The raw administrative-area string (may be null) from the geocoder.
  final String? adminArea;
}

/// Network or geocoding error.
final class RegionError extends RegionResult {
  const RegionError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// LocationService
// ---------------------------------------------------------------------------

/// Handles GPS permission + reverse geocoding, then normalises to [UzRegion].
///
/// Design decisions:
/// - Does NOT throw — always returns a [RegionResult] so callers need no
///   try/catch.
/// - Coarse accuracy is sufficient for region-level detection; uses
///   [LocationAccuracy.low] to minimise battery impact.
/// - geocoding v5 uses instance-based API: [Geocoding().placemarkFromCoordinates].
class LocationService {
  const LocationService();

  /// Attempts to detect the user's Uzbek region.
  ///
  /// Call this when the user explicitly requests location detection (e.g.
  /// leaderboard screen first open, or "Joylashuvni yangilash" tap in
  /// Settings). Do NOT call on every frame.
  Future<RegionResult> detectRegion() async {
    try {
      // ── 1. Check if location services are enabled ─────────────────────────
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services disabled.');
        return const RegionLocationDisabled();
      }

      // ── 2. Check / request permission ────────────────────────────────────
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Permission denied.');
          return const RegionPermissionDenied();
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Permission denied forever.');
        return const RegionLocationDisabled();
      }

      // ── 3. Get position (coarse accuracy — battery friendly) ──────────────
      debugPrint('[LocationService] Fetching position...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      debugPrint(
        '[LocationService] Position: ${position.latitude}, ${position.longitude}',
      );

      // ── 4. Reverse geocode (geocoding v5 instance-based API) ──────────────
      final geo = Geocoding();
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        debugPrint('[LocationService] Geocoding returned no placemarks.');
        return const RegionNotRecognised(null);
      }

      final place = placemarks.first;
      // Android returns administrativeArea; iOS may also return
      // subAdministrativeArea. Try all available fields for best coverage.
      final adminArea =
          place.administrativeArea ?? place.subAdministrativeArea;
      debugPrint(
        '[LocationService] adminArea=$adminArea, locality=${place.locality}',
      );

      // ── 5. Normalise to UzRegion ──────────────────────────────────────────
      final region = UzRegion.fromGeocodingString(adminArea) ??
          UzRegion.fromGeocodingString(place.subAdministrativeArea) ??
          UzRegion.fromGeocodingString(place.locality);

      if (region == null) {
        debugPrint(
          '[LocationService] Could not map adminArea="$adminArea" to a known region.',
        );
        return RegionNotRecognised(adminArea);
      }

      debugPrint('[LocationService] Detected region: ${region.displayName}');
      return RegionDetected(region);
    } on LocationServiceDisabledException {
      return const RegionLocationDisabled();
    } catch (e) {
      debugPrint('[LocationService] Error: $e');
      return RegionError(e.toString());
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final locationServiceProvider = Provider<LocationService>(
  (_) => const LocationService(),
);
