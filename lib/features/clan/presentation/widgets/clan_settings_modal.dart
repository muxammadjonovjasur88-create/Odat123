import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/user_repository.dart';
import '../../data/clan_repository.dart';
import '../../domain/models/clan.dart';

/// Shows Clan Settings bottom sheet for Clan Leader
Future<void> showClanSettingsModal(BuildContext context, Clan clan) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ClanSettingsSheet(clan: clan),
  );
}

class _ClanSettingsSheet extends ConsumerStatefulWidget {
  const _ClanSettingsSheet({required this.clan});

  final Clan clan;

  @override
  ConsumerState<_ClanSettingsSheet> createState() => _ClanSettingsSheetState();
}

class _ClanSettingsSheetState extends ConsumerState<_ClanSettingsSheet> {
  late bool _isPublic;
  late TextEditingController _descController;
  late String _selectedRegion;
  bool _isSaving = false;

  final List<String> _regions = [
    'Navoiy',
    'Toshkent',
    'Samarqand',
    'Buxoro',
    'Farg‘ona',
    'Andijon',
    'Namangan',
    'Qashqadaryo',
    'Surxondaryo',
    'Xorazm',
    'Jizzax',
    'Sirdaryo',
    'Qoraqalpog‘iston',
  ];

  @override
  void initState() {
    super.initState();
    _isPublic = widget.clan.isPublic;
    _descController = TextEditingController(text: widget.clan.description);
    _selectedRegion = widget.clan.region.isNotEmpty ? widget.clan.region : 'Navoiy';
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final leader = ref.read(userProfileProvider).asData?.value;
    if (leader == null || leader.uid != widget.clan.leaderId) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(clanRepositoryProvider).updateClanSettings(
            clanId: widget.clan.id,
            isPublic: _isPublic,
            description: _descController.text.trim(),
            region: _selectedRegion,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF3B9BFF),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Klan sozlamalari muvaffaqiyatli saqlandi! ✨',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF0055),
            content: Text('Xatolik: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Color(0x555BC8FA), width: 1.5)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x225BC8FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x445BC8FA)),
                        ),
                        child: const Icon(Icons.settings_rounded, color: Color(0xFF5BC8FA), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Klan Sozlamalari',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Klan Sardori boshqaruv paneli',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    widget.clan.emblem,
                    style: const TextStyle(fontSize: 28),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Public / Private Switch Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF131929),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPublic ? const Color(0x4400FF88) : const Color(0x44FF0055),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isPublic ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                          color: _isPublic ? const Color(0xFF3B9BFF) : const Color(0xFFFF0055),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPublic ? 'Klan Holati: Ochiq 🟢' : 'Klan Holati: Yopiq 🔒',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _isPublic
                                  ? 'Har kim 2000 PTS bilan qo‘shila oladi'
                                  : 'Faqat taklif yoki sardor ruxsati bilan',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isPublic,
                      activeThumbColor: const Color(0xFF3B9BFF),
                      activeTrackColor: const Color(0x4400FF88),
                      inactiveThumbColor: const Color(0xFFFF0055),
                      inactiveTrackColor: const Color(0x44FF0055),
                      onChanged: (val) => setState(() => _isPublic = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description Input
              Text('clan.desc_label'.tr(), style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Klan maqsadi va intizom qoidalari...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF131929),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF5BC8FA))),
                ),
              ),
              const SizedBox(height: 16),

              // Region Dropdown
              Text('clan.region_label'.tr(), style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF131929),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRegion,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF131929),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRegion = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('common.cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5BC8FA),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 6,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text('clan.save_changes'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
