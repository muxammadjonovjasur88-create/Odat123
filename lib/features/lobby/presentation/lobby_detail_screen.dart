import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../premium/domain/premium.dart';
import '../../premium/presentation/premium_badge.dart';
import '../data/lobby_repository.dart';
import '../domain/lobby.dart';

/// A single lobby: its weekly member leaderboard, the join code, the last
/// week's winner, and a leave action.
class LobbyDetailScreen extends ConsumerStatefulWidget {
  const LobbyDetailScreen({super.key, required this.lobbyId});

  final String lobbyId;

  @override
  ConsumerState<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends ConsumerState<LobbyDetailScreen> {
  bool _rolled = false;
  bool _leaving = false;

  String? get _uid => ref.read(authStateProvider).asData?.value?.uid;

  Future<void> _copy(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(toast)));
    }
  }

  Future<void> _leave(Lobby lobby) async {
    final uid = _uid;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('lobby.detail_leave_title'.tr()),
        content: Text(
          'lobby.detail_leave_body'.tr(namedArgs: {'name': lobby.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('lobby.detail_leave_action'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _leaving = true);
    await ref
        .read(lobbyRepositoryProvider)
        .leaveLobby(uid: uid, lobbyId: lobby.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lobbyAsync = ref.watch(lobbyProvider(widget.lobbyId));
    final membersAsync = ref.watch(lobbyMembersProvider(widget.lobbyId));
    final members = membersAsync.asData?.value ?? const <UserProfile>[];

    // React to member data arriving — roll the week once, OUTSIDE build (the
    // ref.listen callback runs after the frame, never during it).
    ref.listen(lobbyMembersProvider(widget.lobbyId), (_, next) {
      if (_rolled || !mounted) return;
      final loaded = next.asData?.value ?? const <UserProfile>[];
      final lobby = ref.read(lobbyProvider(widget.lobbyId)).asData?.value;
      if (lobby != null && loaded.isNotEmpty) {
        _rolled = true;
        ref.read(lobbyRepositoryProvider).rollWeekIfNeeded(lobby, loaded);
      }
    });

    final lobby = lobbyAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(lobby?.name ?? 'lobby.detail_fallback_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (lobby != null)
            IconButton(
              tooltip: 'lobby.detail_leave_tooltip'.tr(),
              icon: const Icon(Icons.logout_rounded),
              onPressed: _leaving ? null : () => _leave(lobby),
            ),
        ],
      ),
      body: SafeArea(
        child: lobbyAsync.when(
          loading: () => const Center(child: FlowaLoading()),
          error: (e, _) => AppErrorView(
            message: 'lobby.detail_open_error'.tr(),
            onRetry: () => ref.invalidate(lobbyProvider(widget.lobbyId)),
          ),
          data: (lobby) {
            if (lobby == null) {
              return AppEmptyState(
                icon: Icons.groups_2_outlined,
                title: 'lobby.detail_unavailable_title'.tr(),
                message: 'lobby.detail_unavailable_message'.tr(),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _CodeCard(lobby: lobby, onCopy: _copy),
                if (lobby.lastWinner != null) ...[
                  const SizedBox(height: 14),
                  _WinnerBanner(winner: lobby.lastWinner!),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text(
                      'lobby.detail_this_week'.tr(),
                      style: AppTextStyles.overline.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${lobby.memberCount}/$kLobbyMemberLimit',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Leaderboard(members: members, currentUid: _uid),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.lobby, required this.onCopy});

  final Lobby lobby;
  final Future<void> Function(String text, String toast) onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.tintSage,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'lobby.detail_invite_code'.tr(),
            style: AppTextStyles.overline.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  lobby.code,
                  style: AppTextStyles.h2.copyWith(
                    color: colors.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _RoundAction(
                icon: Icons.copy_rounded,
                onTap: () => onCopy(lobby.code, 'lobby.detail_code_copied'.tr()),
              ),
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.ios_share_rounded,
                onTap: () => onCopy(
                  lobby.inviteText,
                  'lobby.detail_invite_copied'.tr(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'lobby.detail_share_hint'.tr(),
            style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: colors.primary),
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.winner});

  final LobbyWinner winner;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.tintBlue,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'lobby.detail_last_winner'.tr(),
                  style: AppTextStyles.overline.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'lobby.detail_winner_line'.tr(
                    namedArgs: {
                      'name': winner.name,
                      'points': '${winner.points}',
                    },
                  ),
                  style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'lobby.detail_fresh_week'.tr(),
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.members, required this.currentUid});

  final List<UserProfile> members;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'lobby.detail_no_members'.tr(),
            style: AppTextStyles.body.copyWith(color: colors.textTertiary),
          ),
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < members.length; i++)
            FadeSlideIn(
              delay: FadeSlideIn.stagger(i),
              child: _MemberRow(
                rank: i + 1,
                user: members[i],
                isMe: members[i].uid == currentUid,
                showDivider: i != members.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.rank,
    required this.user,
    required this.isMe,
    required this.showDivider,
  });

  final int rank;
  final UserProfile user;
  final bool isMe;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final leading = rank == 1;
    return Material(
      color: isMe ? colors.tintSage : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          final targetPath = isMe
              ? AppRoutes.profile
              : '${AppRoutes.profile}/${user.uid}';
          context.push(targetPath);
        },
        borderRadius: BorderRadius.circular(14),
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: leading
                      ? const Icon(
                          Icons.emoji_events_rounded,
                          size: 20,
                          color: Color(0xFFE3B23C),
                        )
                      : Text(
                          '$rank',
                          style: AppTextStyles.label.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                AvatarCircle(avatarKey: user.avatar, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe
                              ? 'lobby.detail_name_you'.tr(
                                  namedArgs: {'name': user.name},
                                )
                              : user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (kPremiumEnabled && user.isPremium) ...[
                        const SizedBox(width: 6),
                        const PremiumBadge(),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${user.weeklyPoints} ${'common.pts'.tr()}',
                  style: AppTextStyles.label.copyWith(
                    color: leading ? AppColors.forest : colors.primary,
                  ),
                ),
              ],
            ),
          ),
            if (showDivider)
              Divider(height: 1, color: colors.border, indent: 12, endIndent: 12),
          ],
        ),
      ),
    );
  }
}
