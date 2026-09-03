import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/user_repository.dart';
import '../../data/clan_repository.dart';
import 'clan_emblem_view.dart';

/// Shows the Create Clan Modal Bottom Sheet
Future<void> showCreateClanModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _CreateClanSheet(),
  );
}

class _CreateClanSheet extends ConsumerStatefulWidget {
  const _CreateClanSheet();

  @override
  ConsumerState<_CreateClanSheet> createState() => _CreateClanSheetState();
}

class _CreateClanSheetState extends ConsumerState<_CreateClanSheet> {
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedEmblem = '🦅';
  String _selectedRegion = 'Navoiy';
  bool _isCreating = false;

  final List<String> _emblems = [
    '🦅', '🐺', '🦁', '🐉', '⚡', '🔥', '👑', '⚔️', '🛡️', '💎', '🚀', '🌟'
  ];

  final List<String> _regions = [
    'Navoiy', 'Toshkent', 'Samarqand', 'Buxoro', 'Andijon', 'Farg‘ona',
    'Namangan', 'Qashqadaryo', 'Surxondaryo', 'Xorazm', 'Jizzax', 'Sirdaryo', 'Qoraqalpog‘iston'
  ];

  Future<void> _pickCustomEmblem() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final b64 = base64Encode(bytes);
        setState(() {
          _selectedEmblem = b64;
          if (!_emblems.contains(b64)) {
            _emblems.insert(0, b64);
          }
        });
      }
    } catch (e) {
      debugPrint('Emblem pick error: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    final tag = _tagController.text.trim().toUpperCase();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      _showToast('clan.name_hint'.tr());
      return;
    }
    if (tag.isEmpty || tag.length < 2 || tag.length > 5) {
      _showToast('clan.tag_label'.tr());
      return;
    }

    UserProfile? user = ref.read(userProfileProvider).asData?.value;
    if (user == null) {
      final authUser = ref.read(authStateProvider).asData?.value;
      if (authUser != null) {
        user = UserProfile(
          uid: authUser.uid,
          name: authUser.displayName ?? 'Jangchi',
          email: authUser.email,
          avatar: 'leaf',
          focusType: 'pomodoro',
        );
      }
    }
    if (user == null) {
      _showToast('profile.not_found'.tr());
      return;
    }

    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(clanRepositoryProvider).createClan(
            name: name,
            tag: tag,
            emblem: _selectedEmblem,
            description: desc.isEmpty ? 'ODAT jangchilari klani' : desc,
            leader: user,
            region: _selectedRegion,
          );

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A7FCC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                Text(_selectedEmblem, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'clan.create_success'.tr(namedArgs: {'tag': tag, 'name': name}),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast('Xatolik: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFFF0055),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF090B18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Color(0x664AADDC), width: 1.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x224AADDC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x444AADDC)),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFF4AADDC),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'clan.create_title'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF4AADDC),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'clan.create_sub'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Emblem Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'clan.emblem_label'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  InkWell(
                    onTap: _pickCustomEmblem,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: const [
                          Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF38BDF8), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Rasm yuklash',
                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emblems.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return GestureDetector(
                        onTap: _pickCustomEmblem,
                        child: Container(
                          width: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2335),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                          ),
                          child: const Center(
                            child: Icon(Icons.add_a_photo_rounded, color: Color(0xFF38BDF8), size: 20),
                          ),
                        ),
                      );
                    }
                    final e = _emblems[index - 1];
                    final isSelected = _selectedEmblem == e;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedEmblem = e);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0x3338BDF8)
                              : const Color(0xFF121826),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF1E283D),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: ClanEmblemView(emblem: e, size: 26),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Clan Name Input
              Text(
                'clan.name_label'.tr(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'clan.name_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF090B18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0x22FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF4AADDC)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Clan Tag Input
              Text(
                'clan.tag_label'.tr(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _tagController,
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Color(0xFF4AADDC),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'clan.tag_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixText: '[ ',
                  suffixText: ' ]',
                  prefixStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                  suffixStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: const Color(0xFF090B18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0x22FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF4AADDC)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Clan Description Input
              Text(
                'clan.desc_label'.tr(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'clan.desc_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF090B18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0x22FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF4AADDC)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Region Dropdown
              Text(
                'clan.region_label'.tr(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF090B18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRegion,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF090B18),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    items: _regions.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text('📍 $r'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRegion = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4AADDC),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0x884AADDC),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'clan.create_btn'.tr(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
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
