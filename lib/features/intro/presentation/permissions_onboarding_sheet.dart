import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/locale_store.dart';

/// Shows the all-in-one permissions request sheet if not all essential permissions are granted.
Future<void> showStartupPermissionsSheet(BuildContext context) async {
  // Check if already prompted recently
  final hasPrompted = LocaleStore.hasGrantedStartupPermissions();
  if (hasPrompted) return;

  await showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _PermissionsSheetContent(),
  );
}

class _PermissionsSheetContent extends StatefulWidget {
  const _PermissionsSheetContent();

  @override
  State<_PermissionsSheetContent> createState() => _PermissionsSheetContentState();
}

class _PermissionsSheetContentState extends State<_PermissionsSheetContent> {
  bool _isRequesting = false;

  final Map<String, bool> _status = {
    'camera': false,
    'mic': false,
    'location': false,
    'notifications': false,
  };

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final camera = await Permission.camera.isGranted;
    final mic = await Permission.microphone.isGranted;
    final loc = await Permission.locationWhenInUse.isGranted;
    final notif = await Permission.notification.isGranted;

    if (mounted) {
      setState(() {
        _status['camera'] = camera;
        _status['mic'] = mic;
        _status['location'] = loc;
        _status['notifications'] = notif;
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequesting = true);
    HapticFeedback.mediumImpact();

    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
        Permission.locationWhenInUse,
        Permission.notification,
        Permission.activityRecognition,
      ].request();

      _status['camera'] = statuses[Permission.camera]?.isGranted ?? false;
      _status['mic'] = statuses[Permission.microphone]?.isGranted ?? false;
      _status['location'] = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      _status['notifications'] = statuses[Permission.notification]?.isGranted ?? false;
    } catch (e) {
      debugPrint('⚠️ Error requesting permissions: $e');
    }

    await LocaleStore.setGrantedStartupPermissions();

    if (mounted) {
      setState(() => _isRequesting = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF090B18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(
            top: BorderSide(color: Color(0xFF4AADDC), width: 2),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x334AADDC),
              blurRadius: 30,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),

            // Cyber Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.security_rounded, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RUXSATNOMALAR',
                        style: TextStyle(
                          color: Color(0xFF4AADDC),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Ilova Imkoniyatlarini Yoqish',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text(
              'ODAT to‘liq va aniq ishlashi uchun quyidagi funksiyalarga ruxsat berishingiz so‘raladi:',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Permission Items
            _permissionTile(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF4AADDC),
              title: 'Kamera & Vision AI',
              subtitle: 'Mashqlarni sanash va sport harakatlarini kuzatish',
              isGranted: _status['camera'] ?? false,
            ),
            const SizedBox(height: 10),

            _permissionTile(
              icon: Icons.mic_rounded,
              color: const Color(0xFFFF0055),
              title: 'Mikrofon & Ovozli AI',
              subtitle: 'Gemini AI bilan ovozli muloqot va buyruqlar',
              isGranted: _status['mic'] ?? false,
            ),
            const SizedBox(height: 10),

            _permissionTile(
              icon: Icons.location_on_rounded,
              color: const Color(0xFF3A7FCC),
              title: 'GPS & Hududlar (Viloyat)',
              subtitle: 'Yugurish masofasini o‘lchash va hudud zabt etish',
              isGranted: _status['location'] ?? false,
            ),
            const SizedBox(height: 10),

            _permissionTile(
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFFFFB703),
              title: 'Bildirishnomalar & Budilnik',
              subtitle: 'Kunlik reja eslatmalari va duel xabarlari',
              isGranted: _status['notifications'] ?? false,
            ),
            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isRequesting ? null : _requestAllPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4AADDC),
                  foregroundColor: Colors.black,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isRequesting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Barcha Ruxsatlarni Berish',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isGranted ? color.withValues(alpha: 0.6) : Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isGranted ? const Color(0xFF3A7FCC) : Colors.white24,
            size: 20,
          ),
        ],
      ),
    );
  }
}
