import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/proof_repository.dart';
import '../domain/proof_session.dart';

/// Bosqich B — Do'stlarning bugungi isbot holatlari.
///
/// BeReal uslubida:
///  - completed: katta rear rasm + kichik doira ichida front rasm (yuqori chap)
///  - missed:    xira fon + "o'tkazib yubordi 😅" matni
///  - pending / notified: kutilmoqda holati
class FriendsProofsScreen extends ConsumerWidget {
  const FriendsProofsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final myProfile = ref.watch(userProfileProvider).asData?.value;
    final friendUids = myProfile?.sharedWith ?? [];

    return Scaffold(
      appBar: FlowaAppBar(
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Do\'st qo\'shish',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showAddFriendSheet(context, ref),
          ),
        ],
      ),
      body: friendUids.isEmpty
          ? _EmptyState(colors: colors)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                Text(
                  'Bugungi isbot holatlari',
                  style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Faqat siz bilan ulashgan do\'stlar ko\'rinadi.',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                for (final uid in friendUids)
                  _FriendProofCard(friendUid: uid),
              ],
            ),
    );
  }

  void _showAddFriendSheet(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final controller = TextEditingController();
    final myUid = ref.read(authStateProvider).asData?.value?.uid ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do\'st qo\'shish',
              style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Do\'stingizning Odat foydalanuvchi ID sini kiriting. '
              'U ID ni o\'z Sozlamalar → Profil sahifasida ko\'ra oladi.',
              style:
                  AppTextStyles.caption.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Foydalanuvchi ID',
                hintText: 'uid123...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Qo\'shish',
              onPressed: () async {
                final friendUid = controller.text.trim();
                if (friendUid.isEmpty || friendUid == myUid) return;
                try {
                  await ref
                      .read(userRepositoryProvider)
                      .addFriend(myUid, friendUid);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Do\'st qo\'shildi!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Xatolik: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Bir do'stning bugungi ProofSession kartasi.
class _FriendProofCard extends ConsumerWidget {
  const _FriendProofCard({required this.friendUid});

  final String friendUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    // Do'st profilini o'qish
    final profileAsync = ref.watch(
      StreamProvider<UserProfile?>((r) =>
          r.watch(userRepositoryProvider).watchProfile(friendUid)),
    );

    final sessionsAsync = ref.watch(
      friendProofSessionsProvider(friendUid),
    );

    final friendName = profileAsync.asData?.value?.name ?? '...';
    final sessions = sessionsAsync.asData?.value ?? [];

    // Eng so'nggi sessiyani topamiz
    final ProofSession? session = sessions.isEmpty
        ? null
        : sessions.reduce(
            (a, b) => a.scheduledTime.isAfter(b.scheduledTime) ? a : b,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sarlavha — ism + holat chip
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Text(
                    friendName,
                    style: AppTextStyles.h3.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (session != null) _StatusChip(session.status),
                ],
              ),
            ),

            // Rasm qismi
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: session == null
                  ? _PendingPlaceholder(colors: colors)
                  : switch (session.status) {
                      ProofStatus.completed =>
                        _MoodProofDisplay(
                          name: friendName,
                          session: session,
                          colors: colors,
                        ),
                      ProofStatus.missed =>
                        _MissedPlaceholder(name: friendName, colors: colors),
                      ProofStatus.pending ||
                      ProofStatus.notified =>
                        _WaitingPlaceholder(
                          status: session.status,
                          colors: colors,
                        ),
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kayfiyat Check-in isboti
// ---------------------------------------------------------------------------

class _MoodProofDisplay extends StatelessWidget {
  const _MoodProofDisplay({
    required this.name,
    required this.session,
    required this.colors,
  });

  final String name;
  final ProofSession session;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final mood = session.moodResponse ?? 'great';
    final (emoji, label, color) = switch (mood) {
      'great' => ('😊', 'bugungi vazifasini ajoyib bajardi! 🚀', const Color(0xFF22C55E)),
      'hard' => ('😐', 'bugungi vazifasini qiyinchilik bilan bajardi! ⚡', const Color(0xFFEAB308)),
      'missed' => ('😔', 'bugungi vazifada chalg\'idi. 😅', const Color(0xFFEF4444)),
      _ => ('😊', 'bugungi vazifasini belgiladi!', const Color(0xFF22C55E)),
    };

    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large emoji with a subtle glowing circle behind
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.body.copyWith(color: colors.textPrimary),
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: label,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Holat widget lari
// ---------------------------------------------------------------------------

class _MissedPlaceholder extends StatelessWidget {
  const _MissedPlaceholder({required this.name, required this.colors});

  final String name;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      color: colors.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_photography_outlined, color: colors.textTertiary, size: 36),
          const SizedBox(height: 10),
          Text(
            '$name bugungi isbotni o\'tkazib yubordi',
            style:
                AppTextStyles.body.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WaitingPlaceholder extends StatelessWidget {
  const _WaitingPlaceholder({
    required this.status,
    required this.colors,
  });

  final ProofStatus status;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final isNotified = status == ProofStatus.notified;
    return Container(
      width: double.infinity,
      height: 140,
      color: colors.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNotified
                ? Icons.access_time_filled_rounded
                : Icons.hourglass_empty_rounded,
            color: colors.textTertiary,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            isNotified
                ? 'Hozir isbot kutilmoqda ⏳'
                : 'Hali navbati kelmadi',
            style:
                AppTextStyles.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PendingPlaceholder extends StatelessWidget {
  const _PendingPlaceholder({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      color: colors.surfaceMuted,
      child: Center(
        child: Text(
          'Bugun uchun isbot rejalashtirilmagan',
          style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🤝', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Do\'st qo\'shilmagan',
              style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Yuqori o\'ng burchakdagi + tugmasini bosib do\'stingizning '
              'foydalanuvchi ID sini kiriting.',
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final ProofStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ProofStatus.completed => ('✅ Yuborildi', const Color(0xFF22C55E)),
      ProofStatus.missed => ('😅 O\'tkazib yuborildi', const Color(0xFFF97316)),
      ProofStatus.notified => ('⏳ Kutilmoqda', const Color(0xFF3B82F6)),
      ProofStatus.pending => ('🕐 Hali emas', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
