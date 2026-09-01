import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/run_session.dart';
import '../../domain/services/running_telemetry_calculator.dart';

class RunSummaryScreen extends StatelessWidget {
  const RunSummaryScreen({
    super.key,
    required this.session,
  });

  final RunSession session;

  @override
  Widget build(BuildContext context) {
    final hasPath = session.gpsPath.isNotEmpty;
    final initialCenter = hasPath
        ? LatLng(session.gpsPath.first.latitude, session.gpsPath.first.longitude)
        : const LatLng(41.2995, 69.2401);

    final durationText =
        RunningTelemetryCalculator.formatDuration(session.durationSeconds);

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B14),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.military_tech_rounded, color: Color(0xFF3B9BFF), size: 24),
            SizedBox(width: 8),
            Text(
              'Mashg\'ulot Natijasi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CELEBRATION / SUMMARY HEADER CARD ---
              Builder(
                builder: (context) {
                  final isCompleted = session.distanceKm >= 3.0;
                  final hasStarted = session.distanceKm >= 0.05 || session.pointsEarned > 0;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? const [Color(0xFF5BC8FA), Color(0xFF0077FF)]
                            : const [Color(0xFF1C2540), Color(0xFF0D1220)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: isCompleted
                          ? null
                          : Border.all(color: const Color(0x335BC8FA)),
                      boxShadow: [
                        BoxShadow(
                          color: isCompleted
                              ? const Color(0x665BC8FA)
                              : Colors.black45,
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isCompleted
                              ? Icons.stars_rounded
                              : Icons.directions_run_rounded,
                          color: isCompleted ? Colors.black : const Color(0xFF5BC8FA),
                          size: 44,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isCompleted
                              ? '🎉 OFARIN! KVEST BAJARILDI!'
                              : (hasStarted ? '🏃 MASHG\'ULOT YAKUNLANDI' : '🏃 MASHG\'ULOT BEKOR QILINDI'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isCompleted ? Colors.black : Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isCompleted
                              ? '+${session.pointsEarned} OCHKO QO‘SHILDI'
                              : 'Maqsad: 3.0 km (${session.distanceKm.toStringAsFixed(2)} km bajarildi)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isCompleted ? Colors.black87 : Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // --- COMPLETED ROUTE MAP THUMBNAIL ---
              Container(
                height: 200,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x335BC8FA)),
                ),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.flowa.flowa',
                    ),
                    if (session.territoriesGained.isNotEmpty)
                      PolygonLayer(
                        polygons: session.territoriesGained.map((poly) {
                          final points = poly.points
                              .map((p) => LatLng(p.latitude, p.longitude))
                              .toList();
                          return Polygon(
                            points: points,
                            color: const Color(0x665BC8FA),
                            borderColor: const Color(0xFF5BC8FA),
                            borderStrokeWidth: 3.0,
                          );
                        }).toList(),
                      ),
                    if (session.gpsPath.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: session.gpsPath
                                .map((p) => LatLng(p.latitude, p.longitude))
                                .toList(),
                            strokeWidth: 4.0,
                            color: const Color(0xFF3B9BFF),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Statistika va Telemetriya',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // --- STATS GRID ---
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  _buildSummaryTile(
                    'MASOFA',
                    '${session.distanceKm.toStringAsFixed(2)} km',
                    Icons.straighten_rounded,
                    const Color(0xFF5BC8FA),
                  ),
                  _buildSummaryTile(
                    'VAQT',
                    durationText,
                    Icons.timer_rounded,
                    Colors.white,
                  ),
                  _buildSummaryTile(
                    'PACE',
                    session.avgPaceMinKm,
                    Icons.speed_rounded,
                    const Color(0xFFFFB703),
                  ),
                  _buildSummaryTile(
                    'KALORIYA',
                    '${session.caloriesBurned} kcal',
                    Icons.local_fire_department_rounded,
                    const Color(0xFFFF4D6D),
                  ),
                  _buildSummaryTile(
                    'OʻRTACHA TEZLIK',
                    '${session.avgSpeedKmh} km/h',
                    Icons.bolt_rounded,
                    AppColors.cyanAccent,
                  ),
                  _buildSummaryTile(
                    'EGALLANGAN HUDUD',
                    '${session.territoriesGained.length} ta polygon',
                    Icons.map_rounded,
                    const Color(0xFF3B9BFF),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // --- FINISH BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/daily');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B9BFF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                  ),
                  child: const Text(
                    'ASOSIY EKRANGA QAYTISH',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTile(
      String title, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262D40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 15),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8B9BB4),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
