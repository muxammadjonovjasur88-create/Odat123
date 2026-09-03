import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/avatar_circle.dart';
import '../../data/running_repository.dart';
import '../../domain/models/defense_structure.dart';
import '../../domain/models/territory_battle.dart';
import '../../domain/models/territory_polygon.dart';
import '../../domain/services/territory_geometry_service.dart';
import '../providers/running_provider.dart';

const List<Color> _kDistinctPalettes = [
  Color(0xFF4AADDC), // Cyber Cyan
  Color(0xFFFFB703), // Gold Amber
  Color(0xFFFF0055), // Crimson Rose
  Color(0xFF3A7FCC), // Neon Green
  Color(0xFFBF00FF), // Cyber Purple
  Color(0xFFFF5400), // Lava Orange
  Color(0xFF0088FF), // Deep Azure
  Color(0xFF3A7FCC), // Spring Mint
  Color(0xFFFF00AA), // Neon Magenta
  Color(0xFFE5E4E2), // Platinum White
  Color(0xFFFFD700), // Pure Gold
  Color(0xFF7000FF), // Indigo
];

Color _getTerritoryBorderColor(TerritoryPolygon poly, bool isMine) {
  if (isMine) return const Color(0xFF4AADDC);
  if (poly.status == 'under_attack' || poly.status == 'contested') return const Color(0xFFFF0055);
  final hash = poly.ownerId.hashCode.abs();
  return _kDistinctPalettes[hash % _kDistinctPalettes.length];
}

Color _getTerritoryFillColor(TerritoryPolygon poly, bool isMine) {
  final border = _getTerritoryBorderColor(poly, isMine);
  return border.withValues(alpha: 0.28);
}

final activeRunnersStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, myUid) {
  return ref.watch(runningRepositoryProvider).watchActiveRunners(myUid);
});

class RunningScreen extends ConsumerStatefulWidget {
  const RunningScreen({
    super.key,
    this.isWalking = false,
    this.targetKm = 3.0,
  });

  final bool isWalking;
  final double targetKm;

  @override
  ConsumerState<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends ConsumerState<RunningScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _autoFollow = true;
  late final AnimationController _pulseController;
  DefenseTowerTier? _placingTowerTier;
  TerritoryPolygon? _selectedTerritoryForPlacement;

  // 🎁 Geo-Caching Mystery Loot Boxes
  List<Map<String, dynamic>> _mysteryBoxes = [];
  final Set<String> _claimedBoxIds = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    Future.microtask(() {
      final notifier = ref.read(runningNotifierProvider.notifier);
      notifier.initGps();
    });
  }

  void _spawnMysteryBoxes(LatLng center) {
    if (_mysteryBoxes.isNotEmpty) return;
    final offsets = [
      [0.0018, 0.0015, '+50 Coins', 50, 0, '🪙'],
      [-0.0015, 0.0020, '+100 PTS', 0, 100, '⭐'],
      [0.0022, -0.0018, '+100 Coins', 100, 0, '💎'],
      [-0.0025, -0.0012, '+150 PTS', 0, 150, '🔥'],
      [0.0030, 0.0028, '+200 Coins', 200, 0, '👑'],
      [-0.0032, 0.0025, '2x Booster', 50, 200, '🚀'],
    ];

    _mysteryBoxes = List.generate(offsets.length, (i) {
      final off = offsets[i];
      return {
        'id': 'box_$i',
        'lat': center.latitude + (off[0] as double),
        'lng': center.longitude + (off[1] as double),
        'title': off[2] as String,
        'coins': off[3] as int,
        'pts': off[4] as int,
        'emoji': off[5] as String,
      };
    });
  }

  void _checkMysteryBoxesProximity(LatLng userPos) {
    for (final box in _mysteryBoxes) {
      final boxId = box['id'] as String;
      if (_claimedBoxIds.contains(boxId)) continue;

      final bLat = box['lat'] as double;
      final bLng = box['lng'] as double;
      final dist = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, bLat, bLng);

      if (dist <= 30.0) {
        _claimedBoxIds.add(boxId);
        HapticFeedback.heavyImpact();
        _claimMysteryBox(box);
        break;
      }
    }
  }

  void _claimMysteryBox(Map<String, dynamic> box) async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      final coins = box['coins'] as int;
      final pts = box['pts'] as int;
      if (coins > 0) await ref.read(userRepositoryProvider).addFenixCoins(user.uid, coins);
      if (pts > 0) await ref.read(userRepositoryProvider).awardPoints(user.uid, pts);
    }

    if (!mounted) return;
    _showMysteryBoxModal(box);
  }

  void _showMysteryBoxModal(Map<String, dynamic> box) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFB703), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66FFB703), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎁', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text(
                'SIRLI QUTI OCHILDI! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFB703),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Siz xaritadagi qutiga yetib keldingiz va mukofotni qo‘lga kiritdingiz!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFB703)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _questBoxIcon(box['id'] as String? ?? ''),
                      color: const Color(0xFFFFB703),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      box['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB703),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('QABUL QILISH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _recenterMap() {
    setState(() => _autoFollow = true);
    final state = ref.read(runningNotifierProvider);
    if (state.currentPos != null) {
      _mapController.move(
        LatLng(state.currentPos!.latitude, state.currentPos!.longitude),
        16.5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(runningNotifierProvider);
    final notifier = ref.read(runningNotifierProvider.notifier);
    final user = ref.watch(userProfileProvider).asData?.value;
    final myUid = user?.uid ?? '';
    final otherRunners = ref.watch(activeRunnersStreamProvider(myUid)).asData?.value ?? [];

    final currentCenter = state.currentPos != null
        ? LatLng(state.currentPos!.latitude, state.currentPos!.longitude)
        : const LatLng(41.2995, 69.2401);

    if (state.currentPos != null) {
      _spawnMysteryBoxes(currentCenter);
    }

    // Auto-center map when GPS updates if _autoFollow is enabled (throttled for 60fps smoothness)
    ref.listen(runningNotifierProvider, (prev, next) {
      if (next.currentPos != null) {
        final pos = LatLng(next.currentPos!.latitude, next.currentPos!.longitude);

        if (prev?.currentPos == null ||
            prev!.currentPos!.latitude != next.currentPos!.latitude ||
            prev.currentPos!.longitude != next.currentPos!.longitude) {
          _checkMysteryBoxesProximity(pos);
        }

        if (_autoFollow) {
          final center = _mapController.camera.center;
          final distMeters = Geolocator.distanceBetween(
            center.latitude,
            center.longitude,
            pos.latitude,
            pos.longitude,
          );
          if (distMeters > 8.0) {
            final zoom = _mapController.camera.zoom < 14.0 ? 16.5 : _mapController.camera.zoom;
            _mapController.move(pos, zoom);
          }
        }
      }
      // Show battle dialog if battle occurred
      if (next.pendingBattleResult != null && prev?.pendingBattleResult == null) {
        _showBattleResultModal(context, next.pendingBattleResult!, next.pendingTargetTerritory);
      }
    });

    // Apply map filter
    final visibleTerritories = state.territories.where((t) {
      if (state.activeMapFilter == 'my_territories') return t.ownerId == myUid;
      if (state.activeMapFilter == 'under_attack') return t.status == 'under_attack' || t.status == 'contested';
      if (state.activeMapFilter == 'my_defenses') return t.ownerId == myUid && t.defenseStructures.isNotEmpty;
      return true;
    }).toList();

    return PopScope(
      canPop: state.workoutState == WorkoutState.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showExitConfirmationDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF04050D),
        body: Stack(
          children: [
            // ==========================================
            // 1. FULLSCREEN MAP
            // ==========================================
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentCenter,
                initialZoom: 16.5,
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture && _autoFollow) {
                    setState(() => _autoFollow = false);
                  }
                },
                onTap: (tapPos, latLng) {
                  // If placing a defense tower
                  if (_placingTowerTier != null && _selectedTerritoryForPlacement != null) {
                    _executeTowerPlacement(latLng);
                  } else if (state.workoutState == WorkoutState.idle) {
                    // Tap to set START point before running
                    notifier.setStartPoint(GpsPoint(
                      latitude: latLng.latitude,
                      longitude: latLng.longitude,
                    ));
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.company.flova',
                ),

                // ── START Point Finish Radius Circle ────────────────────────
                if (state.startPos != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(state.startPos!.latitude, state.startPos!.longitude),
                        radius: state.startFinishRadiusMeters,
                        useRadiusInMeter: true,
                        color: const Color(0x224AADDC),
                        borderColor: const Color(0xFF4AADDC),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),

                // ── Conquered Territory Polygons Layer (Thick border + Transparent Fill) ──
                if (visibleTerritories.isNotEmpty)
                  PolygonLayer(
                    polygons: visibleTerritories.map((poly) {
                      final points = poly.points
                          .map((p) => LatLng(p.latitude, p.longitude))
                          .toList();
                      final isMine = poly.ownerId == myUid;

                      return Polygon(
                        points: points,
                        color: _getTerritoryFillColor(poly, isMine),
                        borderColor: _getTerritoryBorderColor(poly, isMine),
                        borderStrokeWidth: isMine ? 4.0 : 3.0,
                      );
                    }).toList(),
                  ),

                // ── Live Polyline Trails Layer (Outer Glow + Core Neon Line) ──
                if (state.gpsPath.length > 1) ...[
                  PolylineLayer(
                    polylines: [
                      // Outer neon glow
                      Polyline(
                        points: state.gpsPath
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                        color: const Color(0x664AADDC),
                        strokeWidth: 8.0,
                      ),
                      // Core bright neon live route
                      Polyline(
                        points: state.gpsPath
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                        color: const Color(0xFF4AADDC),
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),
                ],

                // ── Other Active Runners' Live Neon Trails Layer ──
                if (otherRunners.isNotEmpty)
                  PolylineLayer(
                    polylines: otherRunners.map((runner) {
                      final runnerUid = runner['uid']?.toString() ?? '';
                      final hash = runnerUid.hashCode.abs();
                      final runnerColor = _kDistinctPalettes[hash % _kDistinctPalettes.length];
                      final rawTrail = runner['trail'] as List<dynamic>? ?? [];
                      final trailPoints = rawTrail
                          .map((pt) {
                            if (pt is Map) {
                              final lat = (pt['lat'] as num?)?.toDouble();
                              final lng = (pt['lng'] as num?)?.toDouble();
                              if (lat != null && lng != null) return LatLng(lat, lng);
                            }
                            return null;
                          })
                          .whereType<LatLng>()
                          .toList();

                      if (trailPoints.length < 2) {
                        final lat = (runner['lat'] as num?)?.toDouble();
                        final lng = (runner['lng'] as num?)?.toDouble();
                        if (lat != null && lng != null) {
                          trailPoints.add(LatLng(lat, lng));
                        }
                      }

                      return Polyline(
                        points: trailPoints,
                        color: runnerColor.withValues(alpha: 0.7),
                        strokeWidth: 3.5,
                      );
                    }).where((poly) => poly.points.length >= 2).toList(),
                  ),

                // ── 300m Tower Territory Aura Circles Layer ──
                CircleLayer(
                  circles: [
                    ...state.defenseStructures.map((structure) {
                      final isMine = structure.ownerId == myUid;
                      return CircleMarker(
                        point: LatLng(structure.latitude, structure.longitude),
                        radius: 300,
                        useRadiusInMeter: true,
                        color: isMine
                            ? const Color(0xFF4AADDC).withValues(alpha: 0.16)
                            : const Color(0xFFFF0055).withValues(alpha: 0.16),
                        borderColor: isMine ? const Color(0xFF4AADDC) : const Color(0xFFFF0055),
                        borderStrokeWidth: 2.0,
                      );
                    }),
                  ],
                ),

                // ── Markers Layer (START point, Centroid Logo, Defense Towers, Runner) ──
                MarkerLayer(
                  markers: [
                    // 1. 🟢 START Marker
                    if (state.startPos != null)
                      Marker(
                        point: LatLng(state.startPos!.latitude, state.startPos!.longitude),
                        width: 70,
                        height: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4AADDC),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [BoxShadow(color: Color(0xAA4AADDC), blurRadius: 8)],
                              ),
                              child: const Text(
                                'START',
                                style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const Icon(Icons.location_pin, color: Color(0xFF4AADDC), size: 32),
                          ],
                        ),
                      ),

                    // 2. 👑 Territory Centroid Owner Logos
                    ...visibleTerritories.map((poly) {
                      final centroid = poly.actualCentroid;
                      final isMine = poly.ownerId == myUid;
                      return Marker(
                        point: LatLng(centroid.latitude, centroid.longitude),
                        width: 90,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _showTerritoryDetailModal(context, poly, isMine),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isMine ? const Color(0xFF090B18) : const Color(0xFF220C18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isMine ? const Color(0xFF4AADDC) : const Color(0xFFFF0055),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isMine ? const Color(0x884AADDC) : const Color(0x88FF0055),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isMine ? Icons.shield_rounded : Icons.military_tech_rounded,
                                  color: isMine ? const Color(0xFF4AADDC) : const Color(0xFFFF0055),
                                  size: 18,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xEE07090E),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  poly.ownerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // 3. 🛡️ Placed 3D Isometric Defense Towers
                    ...state.defenseStructures.map((structure) {
                      final tier = DefenseShopConfig.getTier(structure.level);
                      return Marker(
                        point: LatLng(structure.latitude, structure.longitude),
                        width: 56,
                        height: 72,
                        alignment: Alignment.bottomCenter,
                        child: _Isometric3DTowerMarker(structure: structure, tier: tier),
                      );
                    }),

                    // 3.5. 🎁 Geo-Caching Mystery Loot Boxes (Interactive Geo-Spawns)
                    ..._mysteryBoxes.where((b) => !_claimedBoxIds.contains(b['id'])).map((box) {
                      final bLat = box['lat'] as double;
                      final bLng = box['lng'] as double;
                      return Marker(
                        point: LatLng(bLat, bLng),
                        width: 50,
                        height: 50,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.9 + (_pulseController.value * 0.2),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xEE07090E),
                                  border: Border.all(color: const Color(0xFFFFB703), width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x88FFB703), blurRadius: 12, spreadRadius: 2),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFB703), size: 20),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),

                    // 4. 🏃 Current Runner Position Marker with Avatar Logo & Radar
                    if (state.currentPos != null)
                      Marker(
                        point: LatLng(state.currentPos!.latitude, state.currentPos!.longitude),
                        width: 56,
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulsing radar ripple
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 32 + (_pulseController.value * 22),
                                  height: 32 + (_pulseController.value * 22),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF4AADDC).withValues(
                                      alpha: 0.35 * (1.0 - _pulseController.value),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF4AADDC), width: 2.5),
                                boxShadow: const [BoxShadow(color: Color(0xFF4AADDC), blurRadius: 10, spreadRadius: 2)],
                              ),
                              child: AvatarCircle(
                                avatarKey: user?.avatar ?? 'shield',
                                photoUrl: user?.photoUrl,
                                photoBase64: user?.photoBase64,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 5. 🏃‍♂️ Live Multi-Runner Broadcast (1000+ active players with Mini Logos)
                    ...otherRunners.map((runner) {
                      final lat = (runner['lat'] as num?)?.toDouble() ?? 0.0;
                      final lng = (runner['lng'] as num?)?.toDouble() ?? 0.0;
                      final name = runner['userName']?.toString() ?? 'Yuguruvchi';
                      final tag = runner['clanTag']?.toString() ?? '';
                      final speed = (runner['speedKmh'] as num?)?.toDouble() ?? 0.0;
                      final avatar = runner['avatar']?.toString() ?? 'shield';
                      final photoUrl = runner['photoUrl']?.toString();
                      final photoBase64 = runner['photoBase64']?.toString();
                      final runnerUid = runner['uid']?.toString() ?? '';
                      final hash = runnerUid.hashCode.abs();
                      final runnerColor = _kDistinctPalettes[hash % _kDistinctPalettes.length];

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 76,
                        height: 64,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: runnerColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: runnerColor.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: AvatarCircle(
                                avatarKey: avatar,
                                photoUrl: photoUrl,
                                photoBase64: photoBase64,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xEE07090E),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: runnerColor.withValues(alpha: 0.7)),
                              ),
                              child: Text(
                                tag.isNotEmpty && tag != 'SOLO' ? '[$tag] $name\n${speed.toStringAsFixed(1)} km/soat' : '$name\n${speed.toStringAsFixed(1)} km/soat',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: runnerColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

            // ==========================================
            // 2. TOP FLOATING HUD & FILTERS
            // ==========================================
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFloatingTopBar(context, state),
                      const SizedBox(height: 8),

                      // Map Filter Pills
                      _buildMapFilterBar(state, notifier),
                      const SizedBox(height: 8),

                      // Active Telemetry HUD (Distance, Pace, Speed, Calories)
                      _buildTelemetryOverlay(state),

                      // Return to Start Indicator
                      if (state.workoutState == WorkoutState.running && state.distanceToStartMeters != null) ...[
                        const SizedBox(height: 6),
                        _buildReturnToStartBanner(state),
                      ],

                      // Error & Notification Toasts
                      if (state.gpsError != null) ...[
                        const SizedBox(height: 6),
                        _buildToast(state.gpsError!, const Color(0xFFFF3366), Icons.location_off_rounded),
                      ],
                      if (state.antiCheatWarning != null) ...[
                        const SizedBox(height: 6),
                        _buildToast(state.antiCheatWarning!, const Color(0xFFFFB703), Icons.speed_rounded),
                      ],
                      if (state.closedLoopNotification != null) ...[
                        const SizedBox(height: 6),
                        _buildToast(state.closedLoopNotification!, const Color(0xFF4AADDC), Icons.track_changes_rounded),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // 3. TOWER PLACEMENT MODE BANNER
            // ==========================================
            if (_placingTowerTier != null)
              Positioned(
                top: 180,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xEE101726),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF3A7FCC), width: 1.5),
                    boxShadow: const [BoxShadow(color: Color(0x444AADDC), blurRadius: 16)],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _towerVectorIcon(_placingTowerTier!.level),
                        color: const Color(0xFF3A7FCC),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'running.place_tower_title'.tr(args: [_placingTowerTier!.name]),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'running.place_tower_hint'.tr(),
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _placingTowerTier = null;
                          _selectedTerritoryForPlacement = null;
                        }),
                        icon: const Icon(Icons.close_rounded, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ),

            // ==========================================
            // 4. BOTTOM FLOATING CONTROLS
            // ==========================================
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Territory Status Chip & Defense Shop & Recenter FAB
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Territory Badge
                          _buildTerritoryBadge(state),

                          Row(
                            children: [
                              // Defense Shop Button
                              FloatingActionButton.small(
                                heroTag: 'defense_shop_btn',
                                onPressed: () => _showDefenseShopModal(context),
                                backgroundColor: const Color(0xFF090B18),
                                foregroundColor: const Color(0xFF3A7FCC),
                                elevation: 6,
                                child: const Icon(Icons.shield_rounded, size: 20),
                              ),
                              const SizedBox(width: 8),

                              // Recenter FAB
                              FloatingActionButton.small(
                                heroTag: 'recenter_btn',
                                onPressed: _recenterMap,
                                backgroundColor: _autoFollow ? const Color(0xFF4AADDC) : const Color(0xFF090B18),
                                foregroundColor: _autoFollow ? Colors.black : const Color(0xFF4AADDC),
                                elevation: 6,
                                child: Icon(
                                  _autoFollow ? Icons.my_location_rounded : Icons.location_searching_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Primary Action Buttons (Start, Pause, Finish, Set Start Point)
                      _buildBottomControls(context, state, notifier),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MAP FILTER BAR ────────────────────────────────────────────────────────
  Widget _buildMapFilterBar(RunningState state, RunningNotifier notifier) {
    final filters = [
      {'id': 'all', 'label': 'Barchasi', 'icon': Icons.public_rounded},
      {'id': 'my_territories', 'label': 'Mening Hududlarim', 'icon': Icons.shield_rounded},
      {'id': 'under_attack', 'label': '⚔️ Janglar', 'icon': Icons.flash_on_rounded},
      {'id': 'my_defenses', 'label': '🏰 Minoralar', 'icon': Icons.fort_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = state.activeMapFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => notifier.setMapFilter(f['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4AADDC) : const Color(0xDD101726),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4AADDC) : const Color(0x33FFFFFF),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f['icon'] as IconData, size: 13, color: isSelected ? Colors.black : Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── RETURN TO START INDICATOR ─────────────────────────────────────────────
  Widget _buildReturnToStartBanner(RunningState state) {
    final dist = state.distanceToStartMeters ?? 0.0;
    final isInside = state.isInsideStartRadius;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isInside ? const Color(0xEE39FF14) : const Color(0xDD101726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isInside ? Colors.white : const Color(0xFF4AADDC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInside ? Icons.check_circle_rounded : Icons.near_me_rounded,
            color: isInside ? Colors.black : const Color(0xFF4AADDC),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isInside
                ? '🎯 START RADIUSIDA! Loop yopildi va hudud tekshirilmoqda!'
                : 'STARTgacha: ${dist.round()} metr — Yopiq loop uchun STARTga qayting',
            style: TextStyle(
              color: isInside ? Colors.black : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTopBar(BuildContext context, RunningState state) {
    final user = ref.watch(userProfileProvider).asData?.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xDD0C101A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x334AADDC)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2335),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                    ),
                    child: Image.asset('assets/icon/flowa_icon.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isWalking ? 'ODAT GPS WALKING' : 'ODAT TERRITORY RUN',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      Text(
                        '⚡ ${user?.totalPoints ?? 0} PTS | 🔥 ${user?.streak ?? 0} kun',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => context.push(AppRoutes.audiobooks),
                tooltip: 'Walk & Learn Podkastlar 🎙️',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0x334AADDC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF4AADDC)),
                  ),
                  child: const Icon(Icons.podcasts_rounded, color: Color(0xFF4AADDC), size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryOverlay(RunningState state) {
    final isRunning = state.workoutState == WorkoutState.running;
    final isPaused = state.workoutState == WorkoutState.paused;

    final displaySpeed = state.currentSpeedKmh > 0.1
        ? state.currentSpeedKmh
        : (state.avgSpeedKmh > 0.1 ? state.avgSpeedKmh : 0.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xDD0C101A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRunning
                  ? const Color(0xFF3A7FCC)
                  : (isPaused ? const Color(0xFFFFB703) : const Color(0x334AADDC)),
              width: isRunning ? 1.5 : 1.0,
            ),
            boxShadow: isRunning
                ? [
                    BoxShadow(
                      color: const Color(0xFF3A7FCC).withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTelemetryItem(
                'MASOFA',
                '${state.distanceKm.toStringAsFixed(2)} km',
                Icons.straighten_rounded,
                accentColor: const Color(0xFF3A7FCC),
              ),
              _buildTelemetryItem(
                'TEZLIK',
                '${displaySpeed.toStringAsFixed(1)} km/soat',
                Icons.speed_rounded,
                accentColor: const Color(0xFF4AADDC),
              ),
              _buildTelemetryItem(
                'VAQT',
                _formatDuration(state.elapsedSeconds),
                Icons.timer_outlined,
                accentColor: isRunning ? const Color(0xFFFFB703) : const Color(0xFF4AADDC),
              ),
              _buildTelemetryItem(
                'KALORIYA',
                '${state.calories} kcal',
                Icons.local_fire_department_rounded,
                accentColor: const Color(0xFFFF0055),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryItem(
    String label,
    String value,
    IconData icon, {
    Color accentColor = const Color(0xFF4AADDC),
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildToast(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE101726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerritoryBadge(RunningState state) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final myUid = user?.uid ?? '';
    final myTerritoriesCount = state.territories.where((t) => t.ownerId == myUid).length;
    final totalCount = myTerritoriesCount + state.capturedLoopCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xDD0C101A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x664AADDC), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, color: Color(0xFF3A7FCC), size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$totalCount ta egallangan hudud',
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
              if (state.totalAreaSqMeters > 0)
                Text(
                  'Maydon: ${state.formattedTotalArea}',
                  style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 10, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, RunningState state, RunningNotifier notifier) {
    if (state.workoutState == WorkoutState.idle) {
      return Row(
        children: [
          // Set Start Point FAB
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (state.currentPos != null) {
                  notifier.setStartPoint(state.currentPos!);
                }
                notifier.startRun(isWalking: widget.isWalking, targetKm: widget.targetKm);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4AADDC),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 8,
              ),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
              label: const Text(
                'YUGURISHNI BOSHLASH 🚀',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      );
    }

    if (state.workoutState == WorkoutState.running) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => notifier.pauseRun(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.pause_rounded, size: 24),
              label: Text('running.pause'.tr(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _confirmFinishRun(notifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.stop_rounded, size: 24),
              label: Text('running.finish'.tr(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      );
    }

    if (state.workoutState == WorkoutState.paused) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => notifier.resumeRun(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A7FCC),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text('running.resume'.tr(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _confirmFinishRun(notifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.stop_rounded, size: 24),
              label: Text('running.finish'.tr(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── DEFENSE SHOP BOTTOM SHEET ─────────────────────────────────────────────
  void _showDefenseShopModal(BuildContext context) {
    final state = ref.read(runningNotifierProvider);
    final user = ref.read(userProfileProvider).asData?.value;
    final myUid = user?.uid ?? '';
    final myTerritories = state.territories.where((t) => t.ownerId == myUid).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF04050D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🛡️ MUDOFAA DO‘KONI (DEFENSE)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  Text(
                    '${user?.totalPoints ?? 0} PTS',
                    style: const TextStyle(color: Color(0xFF4AADDC), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Minoralarni sotib olib, o‘zingizning zabt etgan hududingiz ichiga joylashtiring.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: DefenseShopConfig.tiers.length,
                  itemBuilder: (context, idx) {
                    final tier = DefenseShopConfig.tiers[idx];
                    final canAfford = (user?.totalPoints ?? 0) >= tier.costPoints;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090B18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x334AADDC)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF3A7FCC).withValues(alpha: 0.15),
                              border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.5)),
                            ),
                            child: Icon(_towerVectorIcon(tier.level), color: const Color(0xFF3A7FCC), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tier.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  'HP: ${tier.hp} | Hujum: ${tier.attackPower} | Himoya: ${tier.defensePower}',
                                  style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: canAfford && myTerritories.isNotEmpty
                                ? () {
                                    Navigator.pop(ctx);
                                    _startPlacingTower(tier, myTerritories.first);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4AADDC),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              '${tier.costPoints} PTS',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startPlacingTower(DefenseTowerTier tier, TerritoryPolygon territory) {
    setState(() {
      _placingTowerTier = tier;
      _selectedTerritoryForPlacement = territory;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tier.name} uchun hududingiz ichidagi nuqtaga bosing!'),
        backgroundColor: const Color(0xFF04050D),
      ),
    );
  }

  Future<void> _executeTowerPlacement(LatLng latLng) async {
    final tier = _placingTowerTier!;
    final territory = _selectedTerritoryForPlacement!;
    final notifier = ref.read(runningNotifierProvider.notifier);

    final error = await notifier.placeDefenseStructure(
      territory: territory,
      level: tier.level,
      location: GpsPoint(latitude: latLng.latitude, longitude: latLng.longitude),
    );

    setState(() {
      _placingTowerTier = null;
      _selectedTerritoryForPlacement = null;
    });

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $error'), backgroundColor: Colors.red),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${tier.name} muvaffaqiyatli o‘rnatildi! 🏰'), backgroundColor: const Color(0xFF3A7FCC)),
        );
      }
    }
  }

  // ── TERRITORY DETAIL MODAL ────────────────────────────────────────────────
  void _showTerritoryDetailModal(BuildContext context, TerritoryPolygon territory, bool isMine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF04050D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isMine ? Icons.shield_rounded : Icons.military_tech_rounded,
                    color: isMine ? const Color(0xFF4AADDC) : const Color(0xFFFF0055),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMine ? 'Sizning Hududingiz' : '${territory.ownerName} Hududi',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          'Maydon: ${TerritoryGeometryService.calculatePolygonAreaSqMeters(territory.points).round()} m²',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Defense stats
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF090B18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Minoralar', '${territory.defenseStructures.length} / ${territory.defenseCapacity} ta'),
                    _buildStatCol('Mudofaa Kuchi', '${territory.totalDefensePower} DEF'),
                    _buildStatCol('Eng Yuqori Minora', 'Lv.${territory.highestDefenseLevel}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (isMine) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDefenseShopModal(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4AADDC),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('running.place_new_tower'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                const Text(
                  '💡 Ushbu dushman hududini egallash uchun yangi STARTdan boshlab uning ustidan yopiq loop yuguring!',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
      ],
    );
  }

  // ── BATTLE RESULT MODAL ───────────────────────────────────────────────────
  void _showBattleResultModal(BuildContext context, BattleResult result, TerritoryPolygon? target) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF04050D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: result.isAttackerWinner ? const Color(0xFF3A7FCC) : const Color(0xFFFF0055),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.isAttackerWinner ? '🏆 G‘ALABA! HUDUD ZABT ETILDI!' : '🛡️ HUJUM QAYTARILDI!',
                  style: TextStyle(
                    color: result.isAttackerWinner ? const Color(0xFF3A7FCC) : const Color(0xFFFF0055),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // VS Power Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090B18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('running.your_power'.tr(), style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                          const SizedBox(height: 4),
                          Text('${result.attackerTotalPower} ATK', style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const Text('VS', style: TextStyle(color: Colors.white30, fontWeight: FontWeight.w900, fontSize: 16)),
                      Column(
                        children: [
                          Text('running.defense_power'.tr(), style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                          const SizedBox(height: 4),
                          Text('${result.defenderTotalPower} DEF', style: const TextStyle(color: Color(0xFFFF0055), fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  result.summaryMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: result.isAttackerWinner ? const Color(0xFF3A7FCC) : const Color(0xFF4AADDC),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('running.resume'.tr(), style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmFinishRun(RunningNotifier notifier) async {
    final session = await notifier.finishRun();
    if (!mounted) return;
    context.push(AppRoutes.runningSummary, extra: session);
  }

  void _showExitConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF04050D),
        title: Text('running.stop_running_title'.tr(), style: TextStyle(color: Colors.white)),
        content: Text('running.stop_running_desc'.tr(), style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3366)),
            child: Text('common.exit'.tr(), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 3D Isometric Cyber Defense Tower Marker
class _Isometric3DTowerMarker extends StatelessWidget {
  const _Isometric3DTowerMarker({
    required this.structure,
    required this.tier,
  });

  final dynamic structure;
  final dynamic tier;

  @override
  Widget build(BuildContext context) {
    final lvl = (structure.level as num?)?.toInt() ?? 1;
    final Color towerColor = lvl >= 5
        ? const Color(0xFFFF0055)
        : lvl >= 3
            ? const Color(0xFFFFB703)
            : const Color(0xFF4AADDC);

    return SizedBox(
      width: 56,
      height: 72,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // 1. Isometric Shadow & Base Ring
          Positioned(
            bottom: 0,
            child: Container(
              width: 38,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(38, 18)),
                gradient: RadialGradient(
                  colors: [
                    towerColor.withValues(alpha: 0.6),
                    towerColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: towerColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // 2. 3D Isometric Stepped Platform Base
          Positioned(
            bottom: 6,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX(0.4),
              child: Container(
                width: 32,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF202C45),
                      const Color(0xFF04050D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: towerColor, width: 1.2),
                ),
              ),
            ),
          ),

          // 3. 3D Tower Citadel Spire & Glowing Core
          Positioned(
            bottom: 16,
            child: Container(
              width: 24,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    towerColor,
                    const Color(0xFF0C1424),
                    towerColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border.all(color: Colors.white70, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: towerColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _towerVectorIcon(tier.level),
                    color: Colors.white,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),

          // 4. Level Badge on Top
          Positioned(
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF04050D),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: towerColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: towerColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                'Lv.$lvl',
                style: TextStyle(
                  color: towerColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _towerVectorIcon(int level) {
  switch (level) {
    case 1:
      return Icons.shield_rounded;
    case 2:
      return Icons.bolt_rounded;
    case 3:
      return Icons.fort_rounded;
    case 4:
      return Icons.radar_rounded;
    case 5:
      return Icons.military_tech_rounded;
    default:
      return Icons.shield_rounded;
  }
}

IconData _questBoxIcon(String id) {
  if (id.contains('gold') || id.contains('legendary')) {
    return Icons.military_tech_rounded;
  } else if (id.contains('diamond') || id.contains('rare')) {
    return Icons.diamond_rounded;
  }
  return Icons.card_giftcard_rounded;
}
