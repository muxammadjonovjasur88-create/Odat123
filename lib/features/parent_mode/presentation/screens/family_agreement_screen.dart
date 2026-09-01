import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';

class FamilyAgreementScreen extends StatefulWidget {
  const FamilyAgreementScreen({super.key});

  @override
  State<FamilyAgreementScreen> createState() => _FamilyAgreementScreenState();
}

class _FamilyAgreementScreenState extends State<FamilyAgreementScreen> {
  bool _agreeSafety = true;
  bool _agreeDiscipline = true;
  bool _agreeLearning = true;
  bool _saving = false;

  bool get _allAgreed => _agreeSafety && _agreeDiscipline && _agreeLearning;

  Future<void> _acceptAndContinue() async {
    if (!_allAgreed || _saving) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final parentDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final childUid = (parentDoc.data()?['childUid'] as String?) ?? '';
        final agreementId = 'agr_${DateTime.now().millisecondsSinceEpoch}';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('family_agreement')
            .doc('current')
            .set({
          'id': agreementId,
          'parentUid': uid,
          'childUid': childUid,
          'shareLocation': _agreeSafety,
          'shareBattery': _agreeSafety,
          'shareScreenTime': _agreeDiscipline,
          'shareStudyProgress': _agreeLearning,
          'shareAiInterests': _agreeLearning,
          'isAcceptedByParent': true,
          'isAcceptedByChild': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _saving = false);
    context.go(AppRoutes.parentHome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'family.agreement_title'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Header Hero
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1220), Color(0xFF0D1627)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3B9BFF).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x2200FF88),
                  ),
                  child: const Icon(Icons.handshake_rounded, color: Color(0xFF3B9BFF), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'family.agreement_heading'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'family.agreement_sub'.tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pillar 1: SAFETY
          _buildPillarSection(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF3B9BFF),
            title: 'family.pillar_safety'.tr(),
            items: [
              'family.safety_item_1'.tr(),
              'family.safety_item_2'.tr(),
              'family.safety_item_3'.tr(),
            ],
            value: _agreeSafety,
            onChanged: (v) => setState(() => _agreeSafety = v),
          ),
          const SizedBox(height: 14),

          // Pillar 2: DIGITAL DISCIPLINE
          _buildPillarSection(
            icon: Icons.timer_rounded,
            iconColor: const Color(0xFF5BC8FA),
            title: 'family.pillar_discipline'.tr(),
            items: [
              'family.discipline_item_1'.tr(),
              'family.discipline_item_2'.tr(),
              'family.discipline_item_3'.tr(),
            ],
            value: _agreeDiscipline,
            onChanged: (v) => setState(() => _agreeDiscipline = v),
          ),
          const SizedBox(height: 14),

          // Pillar 3: LEARNING & AI
          _buildPillarSection(
            icon: Icons.school_rounded,
            iconColor: const Color(0xFFFFB703),
            title: 'family.pillar_learning'.tr(),
            items: [
              'family.learning_item_1'.tr(),
              'family.learning_item_2'.tr(),
              'family.learning_item_3'.tr(),
            ],
            value: _agreeLearning,
            onChanged: (v) => setState(() => _agreeLearning = v),
          ),
          const SizedBox(height: 14),

          // Pillar 4: PRIVACY (Always Protected)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1220),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x3300FF88)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: Color(0xFF3B9BFF), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'family.pillar_privacy'.tr(),
                      style: const TextStyle(color: Color(0xFF3B9BFF), fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x2200FF88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'family.protected_badge'.tr(),
                        style: const TextStyle(color: Color(0xFF3B9BFF), fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '• ${'family.privacy_item_1'.tr()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '• ${'family.privacy_item_2'.tr()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '• ${'family.privacy_item_3'.tr()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Confirm & Accept Button
          ElevatedButton(
            onPressed: _allAgreed && !_saving
                ? () {
                    HapticFeedback.heavyImpact();
                    _acceptAndContinue();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _allAgreed ? const Color(0xFF3B9BFF) : Colors.white12,
              disabledBackgroundColor: Colors.white12,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: _allAgreed ? 4 : 0,
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _allAgreed
                        ? 'family.agree_continue_btn'.tr()
                        : 'family.agree_all_required'.tr(),
                    style: TextStyle(
                      color: _allAgreed ? const Color(0xFF080B14) : Colors.white38,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPillarSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: value ? iconColor.withValues(alpha: 0.4) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: iconColor,
                activeTrackColor: iconColor.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Text('• $item', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
