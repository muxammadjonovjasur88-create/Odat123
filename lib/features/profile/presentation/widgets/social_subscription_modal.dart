import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
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
  final Set<String> _loadingKeys = {};

  String _tgChannelUrl = 'https://t.me/odat_fenix';
  String _tgBotUrl = 'https://t.me/odat_fenix_bot';
  String _igUrl = 'https://instagram.com/odat_fenix';
  String _ytUrl = 'https://youtube.com/@odat_app';

  @override
  void initState() {
    super.initState();
    _fetchRemoteLinks();
  }

  Future<void> _fetchRemoteLinks() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('social_links')
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _tgChannelUrl = (data?['telegram_channel'] as String?) ?? _tgChannelUrl;
          _tgBotUrl = (data?['telegram_bot'] as String?) ?? _tgBotUrl;
          _igUrl = (data?['instagram'] as String?) ?? _igUrl;
          _ytUrl = (data?['youtube'] as String?) ?? _ytUrl;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSubscription({
    required String channelKey,
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
          backgroundColor: const Color(0xFF090B18),
        ),
      );
      return;
    }

    setState(() => _loadingKeys.add(channelKey));

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // Award 1500 PTS
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.awardPoints(user.uid, 1500);

      // Record badge to prevent duplicate claims
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'claimedBadges': FieldValue.arrayUnion([badgeKey]),
      }, SetOptions(merge: true));

      // Refresh user profile so PTS badge updates instantly
      ref.invalidate(userProfileProvider);

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
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF10B981)]),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tabriklaymiz! +1,500 PTS balansingizga qo‘shildi! ⚡',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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
        setState(() => _loadingKeys.remove(channelKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final claimed = user?.claimedBadges ?? [];

    final hasClaimedTg = claimed.contains('social_sub_tg');
    final hasClaimedTgBot = claimed.contains('social_sub_tg_bot');
    final hasClaimedIg = claimed.contains('social_sub_ig');
    final hasClaimedYt = claimed.contains('social_sub_yt');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1420),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0xFF1E283D), width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'IJTIMOIY TARMOQLAR',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Obuna bo‘ling & PTS yuting',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Rasmiy sahifalarimizga obuna bo‘ling va har bir tarmoq uchun +1,500 PTS dan bonuslarga ega bo‘ling:',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),

          // 1. Telegram Channel Card
          _buildSocialCard(
            title: 'Telegram Kanal',
            handle: '@odat_fenix',
            reward: '+1,500 PTS',
            icon: Icons.send_rounded,
            color: const Color(0xFF0088CC),
            isClaimed: hasClaimedTg,
            isLoading: _loadingKeys.contains('tg'),
            onTap: () => _handleSubscription(
              channelKey: 'tg',
              url: _tgChannelUrl,
              badgeKey: 'social_sub_tg',
              title: 'Telegram (@odat_fenix) obunasi',
            ),
          ),
          const SizedBox(height: 10),

          // 2. Telegram Bot Card
          _buildSocialCard(
            title: 'Telegram Bot & Hamjamiyat',
            handle: '@odat_fenix_bot',
            reward: '+1,500 PTS',
            icon: Icons.smart_toy_rounded,
            color: const Color(0xFF29B6F6),
            isClaimed: hasClaimedTgBot,
            isLoading: _loadingKeys.contains('tg_bot'),
            onTap: () => _handleSubscription(
              channelKey: 'tg_bot',
              url: _tgBotUrl,
              badgeKey: 'social_sub_tg_bot',
              title: 'Telegram Bot (@odat_fenix_bot) ulanishi',
            ),
          ),
          const SizedBox(height: 10),

          // 3. Instagram Card
          _buildSocialCard(
            title: 'Instagram Sahifa',
            handle: '@odat_fenix',
            reward: '+1,500 PTS',
            icon: Icons.camera_alt_rounded,
            color: const Color(0xFFE1306C),
            isClaimed: hasClaimedIg,
            isLoading: _loadingKeys.contains('ig'),
            onTap: () => _handleSubscription(
              channelKey: 'ig',
              url: _igUrl,
              badgeKey: 'social_sub_ig',
              title: 'Instagram (@odat_fenix) obunasi',
            ),
          ),
          const SizedBox(height: 10),

          // 4. YouTube Card
          _buildSocialCard(
            title: 'YouTube Kanal',
            handle: '@odat_app',
            reward: '+1,500 PTS',
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFFFF0000),
            isClaimed: hasClaimedYt,
            isLoading: _loadingKeys.contains('yt'),
            onTap: () => _handleSubscription(
              channelKey: 'yt',
              url: _ytUrl,
              badgeKey: 'social_sub_yt',
              title: 'YouTube (@odat_app) obunasi',
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClaimed ? const Color(0x3310B981) : const Color(0xFF1E283D),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
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
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  handle,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          if (isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'OLINGAN',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      reward,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
