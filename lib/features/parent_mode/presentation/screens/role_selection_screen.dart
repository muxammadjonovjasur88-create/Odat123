import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/auth_repository.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bouncy_scale.dart';

/// Post-registration role selection screen.
/// Shown ONCE after profile setup, saves appRole + familyRole to Firestore.
/// 1. Shaxsiy Rejim (Personal Mode) → dailyPlan
/// 2. Ota-ona Rejimi (Parent Mode) → parentHome
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  bool _saving = false;

  Future<void> _saveRole({required String appRole, String? familyRole}) async {
    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'appRole': appRole,
        'familyRole': familyRole,
        'roleSelected': true,
      }, SetOptions(merge: true));

      if (!mounted) return;

      if (appRole == 'personal') {
        context.go(AppRoutes.dailyPlan);
      } else if (appRole == 'family' && familyRole == 'parent') {
        context.go(AppRoutes.parentHome);
      } else {
        context.go(AppRoutes.dailyPlan);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik yuz berdi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF3B9BFF), Color(0xFF5BC8FA)]),
                ),
                child: const Icon(Icons.hub_rounded, color: Color(0xFF080B14), size: 24),
              ),
              const SizedBox(height: 24),
              Text(
                'family.role_heading'.tr(),
                style: AppTextStyles.h1.copyWith(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'family.role_sub'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 36),

              // OPTION 1: Personal Mode
              _RoleCard(
                icon: Icons.person_rounded,
                iconColor: const Color(0xFF5BC8FA),
                gradient: const [Color(0xFF0D2533), Color(0xFF091520)],
                borderColor: const Color(0xFF5BC8FA),
                tag: 'family.personal_tag'.tr(),
                title: 'family.personal_title'.tr(),
                desc: 'family.personal_desc'.tr(),
                loading: _saving,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _saveRole(appRole: 'personal');
                },
              ),

              const SizedBox(height: 16),

              // OPTION 2: Parent Mode (Ota-ona rejimi)
              _RoleCard(
                icon: Icons.supervisor_account_rounded,
                iconColor: const Color(0xFF3B9BFF),
                gradient: const [Color(0xFF0B291A), Color(0xFF081910)],
                borderColor: const Color(0xFF3B9BFF),
                tag: 'family.parent_tag'.tr(),
                title: 'family.parent_title'.tr(),
                desc: 'family.parent_desc'.tr(),
                loading: _saving,
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _saveRole(appRole: 'family', familyRole: 'parent');
                },
              ),
              const Spacer(),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF3B9BFF), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'family.trust_footer'.tr(),
                      style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.borderColor,
    required this.tag,
    required this.title,
    required this.desc,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final Color borderColor;
  final String tag;
  final String title;
  final String desc;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyScale(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
                  )
                : Icon(Icons.arrow_forward_ios_rounded, color: iconColor, size: 16),
          ],
        ),
      ),
    );
  }
}


