import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../providers/family_places_provider.dart';

class AddFamilyPlaceDialog extends ConsumerStatefulWidget {
  const AddFamilyPlaceDialog({super.key});

  @override
  ConsumerState<AddFamilyPlaceDialog> createState() => _AddFamilyPlaceDialogState();
}

class _AddFamilyPlaceDialogState extends ConsumerState<AddFamilyPlaceDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  double _radiusMeters = 200;
  String _selectedIcon = 'school';
  bool _notifyArrival = true;
  bool _notifyDeparture = true;

  final List<Map<String, dynamic>> _quickPresets = [
    {'name': 'Maktab', 'icon': 'school', 'iconData': Icons.school_rounded, 'radius': 250.0},
    {'name': 'Uy', 'icon': 'home', 'iconData': Icons.home_rounded, 'radius': 150.0},
    {'name': 'Kurs / O\'quv markazi', 'icon': 'menu_book', 'iconData': Icons.menu_book_rounded, 'radius': 200.0},
    {'name': 'Sport zal', 'icon': 'fitness_center', 'iconData': Icons.fitness_center_rounded, 'radius': 200.0},
    {'name': 'Buvijonining uyi', 'icon': 'favorite', 'iconData': Icons.favorite_rounded, 'radius': 150.0},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1420),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF3B9BFF).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B9BFF).withValues(alpha: 0.12),
              blurRadius: 28,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B9BFF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF3B9BFF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'family.add_place_title'.tr(),
                    style: AppTextStyles.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Presets Selector
              Text(
                'family.quick_preset'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPresets.map((preset) {
                    final isSelected = _nameController.text == preset['name'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(preset['iconData'] as IconData, size: 16, color: isSelected ? const Color(0xFF080B14) : const Color(0xFF3B9BFF)),
                        label: Text(preset['name'] as String),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _nameController.text = preset['name'] as String;
                              _selectedIcon = preset['icon'] as String;
                              _radiusMeters = preset['radius'] as double;
                              if (_addressController.text.isEmpty) {
                                _addressController.text = 'Toshkent shahri';
                              }
                            });
                          }
                        },
                        selectedColor: const Color(0xFF3B9BFF),
                        backgroundColor: const Color(0xFF162032),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF080B14) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Place Name Field
              Text(
                'family.place_name'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Masalan: 178-Maktab yoki Robototexnika',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF131929),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Address Field
              Text(
                'family.address'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _addressController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Manzil (ko\'cha, tuman)',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF131929),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Radius Selector (100m, 200m, 300m, 500m)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'family.radius_label'.tr(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_radiusMeters.round()} metr',
                    style: const TextStyle(color: Color(0xFF3B9BFF), fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Slider(
                value: _radiusMeters,
                min: 50,
                max: 1000,
                divisions: 19,
                activeColor: const Color(0xFF3B9BFF),
                inactiveColor: Colors.white12,
                onChanged: (val) => setState(() => _radiusMeters = val),
              ),
              const SizedBox(height: 12),

              // Notification Toggles Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131929),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('family.notify_arrival'.tr(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text('family.notify_arrival_sub'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      value: _notifyArrival,
                      activeThumbColor: const Color(0xFF3B9BFF),
                      onChanged: (val) => setState(() => _notifyArrival = val),
                    ),
                    const Divider(color: Colors.white10, height: 8),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('family.notify_departure'.tr(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text('family.notify_departure_sub'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      value: _notifyDeparture,
                      activeThumbColor: const Color(0xFF3B9BFF),
                      onChanged: (val) => setState(() => _notifyDeparture = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Submit Button
              BouncyScale(
                onTap: () {
                  final name = _nameController.text.trim().isEmpty ? 'Xavfsiz Hudud' : _nameController.text.trim();
                  final address = _addressController.text.trim().isEmpty ? 'Toshkent' : _addressController.text.trim();

                  HapticFeedback.heavyImpact();
                  ref.read(familyPlacesProvider.notifier).addPlace(
                        name: name,
                        iconName: _selectedIcon,
                        latitude: 41.3110,
                        longitude: 69.2790,
                        radiusMeters: _radiusMeters,
                        address: address,
                        notifyOnArrival: _notifyArrival,
                        notifyOnDeparture: _notifyDeparture,
                      );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('family.place_saved_toast'.tr()),
                      backgroundColor: const Color(0xFF0F3822),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B9BFF), Color(0xFF00C853)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B9BFF).withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'family.save_place'.tr(),
                      style: const TextStyle(color: Color(0xFF080B14), fontWeight: FontWeight.w900, fontSize: 15),
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
}
