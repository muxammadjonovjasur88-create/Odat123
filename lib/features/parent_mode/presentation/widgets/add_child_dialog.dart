import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/family_repository.dart';
import '../providers/family_providers.dart';

class AddChildDialog extends ConsumerStatefulWidget {
  const AddChildDialog({super.key});

  @override
  ConsumerState<AddChildDialog> createState() => _AddChildDialogState();
}

class _AddChildDialogState extends ConsumerState<AddChildDialog> {
  final TextEditingController _idController = TextEditingController();
  bool _isSearching = false;
  bool _isSent = false;
  String? _foundChildName;
  String? _errorMessage;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  void _searchAndSend() async {
    final query = _idController.text.trim();
    if (query.isEmpty) return;

    final user = ref.read(userProfileProvider).asData?.value;
    final parentUid = user?.uid;
    final parentName = user?.displayName ?? user?.name ?? 'Ota-ona';

    if (parentUid == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    final res = await ref.read(familyRepositoryProvider).linkChild(
          parentUid: parentUid,
          parentName: parentName,
          queryId: query,
        );

    if (!mounted) return;

    if (res != null) {
      ref.invalidate(childLiveStatusProvider);
      if (mounted) {
        Navigator.pop(context);
        context.push(AppRoutes.familyAgreement);
      }
    } else {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Bunday ID li foydalanuvchi topilmadi. Farzandingizning profilidagi 7 xonali ID kodini kiriting.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF090B18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x224AADDC)),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF3A7FCC), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'family.add_child_title'.tr(),
                      style: AppTextStyles.h3.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (!_isSent) ...[
              Text(
                'family.add_child_subtitle'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF141F32),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF4AADDC).withValues(alpha: 0.3)),
                ),
                child: TextField(
                  controller: _idController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'family.odat_id_placeholder'.tr(),
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13, letterSpacing: 0),
                    border: InputBorder.none,
                    icon: const Icon(Icons.badge_rounded, color: Color(0xFF4AADDC), size: 20),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x33FF0055),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF0055).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFF8888), fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchAndSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7FCC),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF04050D)),
                        )
                      : Text(
                          'family.send_request_btn'.tr(),
                          style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x1A00FF88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'family.request_sent_title'.tr(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_foundChildName ?? "Farzand"}ga ulanish so‘rovi yuborildi. Holat: Kutilmoqda (Pending).',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2D4A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'family.done_btn'.tr(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
