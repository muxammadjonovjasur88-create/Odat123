import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/avatar_circle.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../../domain/family_models.dart';
import '../../domain/family_place_models.dart';
import '../providers/family_places_provider.dart';
import '../providers/family_providers.dart';
import '../widgets/add_family_place_dialog.dart';

class ParentLocationScreen extends ConsumerStatefulWidget {
  const ParentLocationScreen({super.key});

  @override
  ConsumerState<ParentLocationScreen> createState() => _ParentLocationScreenState();
}

class _ParentLocationScreenState extends ConsumerState<ParentLocationScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Jonli Xarita & Hududlar, 1: Marshrut Tarixi
  final DateTime _selectedDate = DateTime.now();
  final MapController _mapController = MapController();
  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveStatusAsync = ref.watch(childLiveStatusProvider);
    final places = ref.watch(familyPlacesProvider);
    final placeEvents = ref.watch(todayPlaceEventsProvider).value ?? [];
    final routeHistory = ref.watch(routeHistoryProvider(_selectedDate)).value ?? 
        DayRouteHistory(date: _selectedDate, totalDistanceKm: 0, points: [], events: []);

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'family.location_title'.tr(),
              style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              '${liveStatusAsync.value?.name ?? "Farzand"} • Jonli GPS & Xavfsiz Hududlar',
              style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF3A7FCC)),
            tooltip: 'parent_home.btn_add_child'.tr(),
            onPressed: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (_) => const AddFamilyPlaceDialog(),
              );
            },
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // Top Navigation Switch (Jonli Xarita vs Marshrut Tarixi)
          _buildTopSwitch(),
          SizedBox(height: 16),

          if (_selectedTab == 0) ...[
            // 1. Live Location HUD Card
            liveStatusAsync.when(
              data: (child) => child == null
                  ? const SizedBox.shrink()
                  : _buildLiveMapHud(child),
              loading: () => Center(child: CircularProgressIndicator(color: Color(0xFF3A7FCC))),
              error: (e, s) => const SizedBox.shrink(),
            ),
            SizedBox(height: 20),

            // 2. Configured Family Places Section
            _buildPlacesHeader(places.length),
            SizedBox(height: 12),
            ...places.map((place) => _buildPlaceCard(place)),
            SizedBox(height: 20),

            // 3. Today's Events Timeline
            _buildEventsTimeline(placeEvents),
          ] else ...[
            // Route History View
            _buildRouteHistoryView(routeHistory),
          ],

          SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildTopSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 0),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF3A7FCC).withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _selectedTab == 0 ? const Color(0xFF3A7FCC).withValues(alpha: 0.4) : Colors.transparent),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_rounded, size: 16, color: _selectedTab == 0 ? const Color(0xFF3A7FCC) : Colors.white60),
                      SizedBox(width: 6),
                      Text(
                        'family.live_map_tab'.tr(),
                        style: TextStyle(
                          color: _selectedTab == 0 ? const Color(0xFF3A7FCC) : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF4AADDC).withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _selectedTab == 1 ? const Color(0xFF4AADDC).withValues(alpha: 0.4) : Colors.transparent),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.route_rounded, size: 16, color: _selectedTab == 1 ? const Color(0xFF4AADDC) : Colors.white60),
                      SizedBox(width: 6),
                      Text(
                        'family.route_history_tab'.tr(),
                        style: TextStyle(
                          color: _selectedTab == 1 ? const Color(0xFF4AADDC) : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMapHud(ChildLiveStatus child) {
    final liveLocAsync = ref.watch(childLiveLocationStreamProvider);
    final locHistoryAsync = ref.watch(childLocationHistoryStreamProvider);
    final places = ref.watch(familyPlacesProvider);
    final isLowBattery = child.batteryLevel < 20;

    final locData = liveLocAsync.value;
    final historyData = locHistoryAsync.value ?? [];

    final lat = (locData?['lat'] as num?)?.toDouble() ?? 41.311081;
    final lng = (locData?['lng'] as num?)?.toDouble() ?? 69.240562;
    final speedKmh = (locData?['speedKmh'] as num?)?.toDouble() ?? 0.0;
    final isOnline = locData?['isOnline'] == true;
    final childPos = LatLng(lat, lng);

    final historyPoints = historyData.map((e) {
      final hLat = (e['lat'] as num?)?.toDouble() ?? lat;
      final hLng = (e['lng'] as num?)?.toDouble() ?? lng;
      return LatLng(hLat, hLng);
    }).toList();
    if (historyPoints.isNotEmpty && isOnline) {
      historyPoints.add(childPos); // connect to live position
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.4), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x223B9BFF), blurRadius: 20)],
      ),
      child: Column(
        children: [
          // ── Real Interactive Map ─────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: childPos,
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.company.flova',
                      ),
                      // History Polyline
                      if (historyPoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline<Object>(
                              points: historyPoints,
                              color: const Color(0xFF3A7FCC),
                              strokeWidth: 4.5,
                            ),
                          ],
                        ),
                      // Safe Zones Geofence Circles
                      CircleLayer(
                        circles: [
                          ...places.map((place) {
                            return CircleMarker(
                              point: LatLng(place.latitude, place.longitude),
                              radius: place.radiusMeters.toDouble(),
                              useRadiusInMeter: true,
                              color: const Color(0x224AADDC),
                              borderColor: const Color(0xFF4AADDC),
                              borderStrokeWidth: 2,
                            );
                          }),
                          // Accuracy / Radar Pulse around child
                          CircleMarker(
                            point: childPos,
                            radius: 35,
                            useRadiusInMeter: true,
                            color: const Color(0x333A7FCC),
                            borderColor: const Color(0xFF3A7FCC),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                      // Child Live Marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: childPos,
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _radarController,
                                  builder: (context, _) => Container(
                                    width: 44 + (_radarController.value * 28),
                                    height: 44 + (_radarController.value * 28),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF3A7FCC).withValues(
                                        alpha: 0.4 * (1.0 - _radarController.value),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4AADDC).withValues(alpha: 0.6),
                                        blurRadius: 14,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: AvatarCircle(
                                    avatarKey: child.avatar,
                                    size: 38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Floating Top-Right Live Status Pill
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xEE08121E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isOnline ? const Color(0xFF4AADDC) : const Color(0xFF3A7FCC)),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? const Color(0xFF4AADDC) : const Color(0xFF3A7FCC),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            isOnline ? 'parent_location.live_gps'.tr() : child.locationUpdatedAtStr,
                            style: TextStyle(
                              color: isOnline ? const Color(0xFF4AADDC) : const Color(0xFF3A7FCC),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Floating Bottom-Right Map Controls
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Focus Child Button
                        FloatingActionButton.small(
                          heroTag: 'focus_child_btn',
                          backgroundColor: const Color(0xFF101C30),
                          foregroundColor: const Color(0xFF3A7FCC),
                          elevation: 4,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _mapController.move(childPos, 16.5);
                          },
                          child: const Icon(Icons.my_location_rounded, size: 20),
                        ),
                        SizedBox(height: 8),
                        // Open in Google Maps Navigation
                        FloatingActionButton.small(
                          heroTag: 'open_ext_map_btn',
                          backgroundColor: const Color(0xFF101C30),
                          foregroundColor: const Color(0xFF4AADDC),
                          elevation: 4,
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: const Icon(Icons.navigation_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  // Floating Top-Left Speed Pill
                  if (speedKmh > 0.5)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xEE08121E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3A7FCC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.speed_rounded, color: Color(0xFF3A7FCC), size: 14),
                            SizedBox(width: 5),
                            Text(
                              '${speedKmh.toStringAsFixed(1)} km/s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Details & Battery
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFF4AADDC), size: 18),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              child.locationName,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        ('parent_location.coordinates'.tr() + ': ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
                        style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090B18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLowBattery ? const Color(0xFFFF3B30) : const Color(0xFF3A7FCC).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        child.isCharging
                            ? Icons.battery_charging_full_rounded
                            : (isLowBattery ? Icons.battery_alert_rounded : Icons.battery_full_rounded),
                        color: isLowBattery ? const Color(0xFFFF3B30) : const Color(0xFF3A7FCC),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${child.batteryLevel}%',
                        style: TextStyle(
                          color: isLowBattery ? const Color(0xFFFF3B30) : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_rounded, color: Color(0xFF3A7FCC), size: 18),
            SizedBox(width: 8),
            Text(
              'family.safe_places_heading'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x224AADDC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        BouncyScale(
          onTap: () {
            HapticFeedback.lightImpact();
            showDialog(
              context: context,
              builder: (_) => const AddFamilyPlaceDialog(),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF3A7FCC).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_rounded, color: Color(0xFF3A7FCC), size: 14),
                SizedBox(width: 4),
                Text(
                  'family.add_place'.tr(),
                  style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard(FamilyPlace place) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3A7FCC).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_city_rounded, color: Color(0xFF3A7FCC), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  '${place.address} • ${place.radiusMeters.round()}m radius',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // Alert badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (place.notifyOnArrival)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login_rounded, size: 12, color: Color(0xFF3A7FCC)),
                    SizedBox(width: 2),
                    Text('parent_location.arrived_at'.tr(), style: TextStyle(color: Color(0xFF3A7FCC), fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              if (place.notifyOnDeparture)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, size: 12, color: Color(0xFF4AADDC)),
                    SizedBox(width: 2),
                    Text('parent_location.departed_at'.tr(), style: TextStyle(color: Color(0xFF4AADDC), fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTimeline(List<PlaceEvent> events) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'family.today_places_timeline'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const Icon(Icons.history_rounded, color: Color(0xFF3A7FCC), size: 16),
            ],
          ),
          SizedBox(height: 14),
          for (final ev in events) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(ev.timeStr, style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 12, fontWeight: FontWeight.bold)),
                  SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ev.isArrival ? const Color(0x224AADDC) : const Color(0x224AADDC),
                    ),
                    child: Icon(
                      ev.isArrival ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 12,
                      color: ev.isArrival ? const Color(0xFF3A7FCC) : const Color(0xFF4AADDC),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ('${ev.placeName} (' + (ev.isArrival ? 'parent_location.arrived'.tr() : 'parent_location.departed'.tr()) + ')'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Text('${ev.batteryLevel}%', style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteHistoryView(DayRouteHistory history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary & Offline Notice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4AADDC).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'parent_location.today_distance'.tr(),
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${history.totalDistanceKm} km',
                    style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1420),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF3A7FCC), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'parent_location.offline_notice'.tr(),
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),

        // Route Polyline Points List
        Text(
          'family.verified_route_points'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 10),
        ...history.points.map((pt) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF090B18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x224AADDC)),
                  child: const Icon(Icons.circle, color: Color(0xFF4AADDC), size: 8),
                ),
                SizedBox(width: 10),
                Text(pt.timeStr, style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pt.placeName ?? ('parent_location.gps_coordinate'.tr() + ' (${pt.latitude.toStringAsFixed(3)}, ${pt.longitude.toStringAsFixed(3)})'),
                    style: TextStyle(
                      color: pt.placeName != null ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: pt.placeName != null ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                Text('${pt.batteryLevel}%', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
