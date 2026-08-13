import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../providers/running_provider.dart';

class RunningScreen extends ConsumerStatefulWidget {
  const RunningScreen({
    super.key,
    this.targetKm = 3.0,
    this.isWalking = false,
  });

  final double targetKm;
  final bool isWalking;

  @override
  ConsumerState<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends ConsumerState<RunningScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifier = ref.read(runningNotifierProvider.notifier);
      // ONLY initialize GPS for map positioning. DO NOT auto-start workout!
      notifier.initGps();
    });
  }

  void _recenterMap() {
    final state = ref.read(runningNotifierProvider);
    if (state.currentPos != null) {
      _mapController.move(
        LatLng(state.currentPos!.latitude, state.currentPos!.longitude),
        16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(runningNotifierProvider);
    final notifier = ref.read(runningNotifierProvider.notifier);

    // Auto-center map when initial GPS position is fixed
    ref.listen(runningNotifierProvider, (prev, next) {
      if (prev?.currentPos == null && next.currentPos != null) {
        _mapController.move(
          LatLng(next.currentPos!.latitude, next.currentPos!.longitude),
          16.0,
        );
      }
    });

    final currentCenter = state.currentPos != null
        ? LatLng(state.currentPos!.latitude, state.currentPos!.longitude)
        : const LatLng(41.2995, 69.2401);

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP HUD BAR ---
            _buildTopHudBar(context, state),

            // --- GPS ERROR / WARNING TOASTS ---
            if (state.gpsError != null) _buildGpsErrorToast(state.gpsError!),
            if (state.antiCheatWarning != null)
              _buildWarningToast(state.antiCheatWarning!),
            if (state.closedLoopNotification != null)
              _buildNotificationToast(state.closedLoopNotification!),

            // --- MAP CONTAINER ---
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: currentCenter,
                      initialZoom: 16.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.flowa.flowa',
                      ),

                      // Territory Polygons Layer
                      if (state.territories.isNotEmpty)
                        PolygonLayer(
                          polygons: state.territories.map((poly) {
                            final points = poly.points
                                .map((p) => LatLng(p.latitude, p.longitude))
                                .toList();
                            return Polygon(
                              points: points,
                              color: const Color(0x6600F3FF),
                              borderColor: const Color(0xFF00F3FF),
                              borderStrokeWidth: 3.0,
                            );
                          }).toList(),
                        ),

                      // Active Polyline Path
                      if (state.gpsPath.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: state.gpsPath
                                  .map((p) => LatLng(p.latitude, p.longitude))
                                  .toList(),
                              strokeWidth: 5.0,
                              color: const Color(0xFF39FF14),
                            ),
                          ],
                        ),

                      // User Location Marker (Rotates smoothly like Google Maps using hardware compass sensor)
                      if (state.currentPos != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: currentCenter,
                              width: 46,
                              height: 46,
                              child: StreamBuilder<CompassEvent>(
                                stream: FlutterCompass.events,
                                builder: (context, snapshot) {
                                  final heading = snapshot.data?.heading ?? state.heading;
                                  final turns = (heading % 360.0) / 360.0;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00F3FF),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 3),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x9900F3FF),
                                          blurRadius: 12,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: AnimatedRotation(
                                      turns: turns,
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutCubic,
                                      child: const Icon(
                                        Icons.navigation_rounded,
                                        color: Colors.black,
                                        size: 22,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // --- FLOATING STATS OVERLAY ---
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: _buildTelemetryOverlay(state),
                  ),

                  // --- CLOSED LOOPS BADGE ---
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xEE0C101A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xAA39FF14)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              color: Color(0xFF39FF14), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '🎨 ${state.capturedLoopCount} ta egallangan hudud',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- BOTTOM CONTROLS ---
            _buildBottomControls(context, state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHudBar(BuildContext context, RunningState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0C101A),
        border: Border(
          bottom: BorderSide(color: Color(0x3300F3FF), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isWalking
                          ? Icons.directions_walk_rounded
                          : Icons.directions_run_rounded,
                      color: const Color(0xFF39FF14),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.isWalking
                            ? 'WALKING TERRITORY'
                            : 'RUNNING TERRITORY',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF00F3FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Hudud Egallash (${widget.targetKm.toStringAsFixed(1)} km target)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              IconButton(
                onPressed: _recenterMap,
                tooltip: 'Mening Joyim',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x2639FF14),
                  side: const BorderSide(color: Color(0xFF39FF14)),
                ),
                icon: const Icon(Icons.my_location_rounded,
                    color: Color(0xFF39FF14), size: 18),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () {
                  if (state.workoutState == WorkoutState.running) {
                    _showExitConfirmationDialog(context);
                  } else {
                    context.pop();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Bekor qilish', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGpsErrorToast(String errorText) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFB703),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.black, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => ref.read(runningNotifierProvider.notifier).initGps(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Qayta Ulanish', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningToast(String text) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFF0055),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToast(String text) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF39FF14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildTelemetryOverlay(RunningState state) {
    final mStr = (state.elapsedSeconds % 3600) ~/ 60;
    final sStr = state.elapsedSeconds % 60;
    final timeFormatted =
        '${mStr < 10 ? '0$mStr' : mStr}:${sStr < 10 ? '0$sStr' : sStr}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xEE0A0E17),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x4400F3FF)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('MASOFA', state.distanceKm.toStringAsFixed(2), 'km',
              const Color(0xFF00F3FF)),
          _buildStatColumn('VAQT', timeFormatted, '', Colors.white),
          _buildStatColumn('TEZLIK', state.currentSpeedKmh.toStringAsFixed(1), 'km/h',
              const Color(0xFF39FF14)),
          _buildStatColumn('PACE', state.pace, '', const Color(0xFFFFB703)),
          _buildStatColumn('KALORIYA', '${state.calories}', 'kcal',
              const Color(0xFFFF4D6D)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
      String label, String value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B9BB4),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBottomControls(
      BuildContext context, RunningState state, RunningNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0C101A),
      child: state.workoutState == WorkoutState.idle
          ? SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  notifier.startWorkout(
                    isWalking: widget.isWalking,
                    targetKm: widget.targetKm,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF39FF14),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'BOSHLASH',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (state.workoutState == WorkoutState.paused) {
                          notifier.resumeWorkout();
                        } else {
                          notifier.pauseWorkout();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: state.workoutState == WorkoutState.paused
                            ? const Color(0xFF39FF14)
                            : const Color(0xFFFFB703),
                        side: BorderSide(
                          color: state.workoutState == WorkoutState.paused
                              ? const Color(0xFF39FF14)
                              : const Color(0xFFFFB703),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        state.workoutState == WorkoutState.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 22,
                      ),
                      label: Text(
                        state.workoutState == WorkoutState.paused
                            ? 'DAVOM ETTIRISH'
                            : 'TANAFFUS',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final session = await notifier.finishWorkout();
                        if (session != null && context.mounted) {
                          _showSummaryModal(context, session);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F3FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.stop_rounded, size: 22),
                      label: const Text(
                        'YAKUNLASH',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showExitConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151A27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Mashg\'ulotni bekor qilasizmi?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Chiqib ketsangiz, joriy masofa va olingan hududlar saqlanmaydi.',
          style: TextStyle(color: Color(0xFF8B9BB4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Qolish', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(runningNotifierProvider.notifier).reset();
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0055),
              foregroundColor: Colors.white,
            ),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }

  void _showSummaryModal(BuildContext context, session) {
    context.push('/running/summary', extra: session);
  }
}
