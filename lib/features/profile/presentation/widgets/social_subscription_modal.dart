import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/user_repository.dart';

/// Shows the Social Subscription Modal for +1,500 PTS rewards
Future<void> showSocialSubscriptionModal(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _SocialSubscriptionSheet(),
  );
}

class _SocialSubscriptionSheet extends ConsumerStatefulWidget {
  const _SocialSubscriptionSheet();

  @override
  ConsumerState<_SocialSubscriptionSheet> createState() => _SocialSubscriptionSheetState();
}

class _SocialSubscriptionSheetState extends ConsumerState<_SocialSubscriptionSheet> {
  bool _isClaimingTg = false;
  bool _isClaimingIg = false;

  Future<void> _handleSubscription({
    required String channelType, // 'tg' or 'ig'
    required String url,
    required String badgeKey,
    required String title,
  }) async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null) return;

    if (user.claimedBadges.contains(badgeKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile.social_reward_claimed'.tr()),
          backgroundColor: Color(0xFF131929),
        ),
      );
      return;
    }

    setState(() {
      if (channelType == 'tg') _isClaimingTg = true;
      if (channelType == 'ig') _isClaimingIg = true;
    });

    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // Award 1500 PTS
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.awardPoints(user.uid, 1500);

      // Record badge to prevent duplicate claims
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'claimedBadges': FieldValue.arrayUnion([badgeKey]),
      }, SetOptions(merge: true));

      // Log PTS History
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pts_history')
          .add({
        'title': title,
        'category': 'Ijtimoiy tarmoq',
        'amount': 1500,
        'type': 'earn',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B9BFF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF3B9BFF), Color(0xFF5BC8FA)]),
                  ),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF0D1220), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tabriklaymiz! +1,500 PTS balansingizga qo‘shildi!',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClaimingTg = false;
          _isClaimingIg = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final claimedBadges = user?.claimedBadges ?? [];
    final hasClaimedTg = claimedBadges.contains('social_sub_tg');
    final hasClaimedIg = claimedBadges.contains('social_sub_ig');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF080B14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFF5BC8FA), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x225BC8FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF5BC8FA)),
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFF5BC8FA), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BEPUL PTS MUKOFOTI 🎁',
                      style: TextStyle(
                        color: Color(0xFF5BC8FA),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Ijtimoiy Tarmoqlarga Obuna',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Rasmiy sahifalarimizga obuna bo‘ling va har bir tarmoq uchun +1,500 PTS dan jami 3,000 PTS oling:',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),

          // 1. Telegram Card
          _buildSocialCard(
            title: 'Telegram Guruh',
            handle: '@odat_fenix',
            reward: '+1,500 PTS',
            icon: Icons.send_rounded,
            color: const Color(0xFF0088CC),
            isClaimed: hasClaimedTg,
            isLoading: _isClaimingTg,
            onTap: () => _handleSubscription(
              channelType: 'tg',
              url: 'https://t.me/odat_fenix',
              badgeKey: 'social_sub_tg',
              title: 'Telegram (@odat_fenix) obunasi',
            ),
          ),
          const SizedBox(height: 12),

          // 2. Instagram Card
          _buildSocialCard(
            title: 'Instagram Sahifa',
            handle: '@fenix_it_group',
            reward: '+1,500 PTS',
            icon: Icons.camera_alt_rounded,
            color: const Color(0xFFE1306C),
            isClaimed: hasClaimedIg,
            isLoading: _isClaimingIg,
            onTap: () => _handleSubscription(
              channelType: 'ig',
              url: 'https://instagram.com/fenix_it_group',
              badgeKey: 'social_sub_ig',
              title: 'Instagram (@fenix_it_group) obunasi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard({
    required String title,
    required String handle,
    required String reward,
    required IconData icon,
    required Color color,
    required bool isClaimed,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClaimed ? const Color(0x3300FF88) : color.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  handle,
                  style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isClaimed || isLoading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isClaimed ? const Color(0x2200FF88) : color,
              foregroundColor: isClaimed ? const Color(0xFF3B9BFF) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isClaimed ? 'Olingan ✅' : '$reward 🚀',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                  ),
          ),
        ],
      ),
    );
  }
}
