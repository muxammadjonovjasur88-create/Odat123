import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/user_repository.dart';
import '../../../../core/utils/formatting.dart';
import '../../data/clan_repository.dart';
import '../../domain/models/clan.dart';
import '../widgets/clan_settings_modal.dart';
import 'clan_chat_screen.dart';

/// Screen displaying Clan Details, statistics, and member list (up to 25 members)
class ClanDetailScreen extends ConsumerStatefulWidget {
  const ClanDetailScreen({super.key, required this.clan});

  final Clan clan;

  @override
  ConsumerState<ClanDetailScreen> createState() => _ClanDetailScreenState();
}

class _ClanDetailScreenState extends ConsumerState<ClanDetailScreen> {
  bool _isLeaving = false;
  bool _isJoining = false;

  Future<void> _handleJoin(Clan clan) async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null) return;

    setState(() => _isJoining = true);
    HapticFeedback.heavyImpact();

    try {
      await ref.read(clanRepositoryProvider).joinClan(clanId: clan.id, user: user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B9BFF),
            content: Text('clan.joined_success'.tr(args: [clan.tag, clan.name])),
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
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _handleLeave(Clan clan) async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null) return;

    if (clan.membersCount <= 1) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D1220),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('clan.attention'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Siz klandagi yagona a’zosiz. Klandan chiqish mumkin emas (Klan sardori sifatida avval boshqa a’zoni lider qiling yoki klanni tarqating).',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5BC8FA), foregroundColor: Colors.black),
              child: Text('clan.understood'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1220),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Klandan chiqish',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Haqiqatdan ham [${clan.tag}] ${clan.name} klanidan chiqmoqchimisiz?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055)),
            child: Text('clan.leave_clan_action'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLeaving = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(clanRepositoryProvider).leaveClan(clanId: clan.id, user: user);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF0055),
            content: Text('clan.leave_clan_success'.tr()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clanStream = ref.watch(clanRepositoryProvider).watchClan(widget.clan.id, fallback: widget.clan);
    final user = ref.watch(userProfileProvider).asData?.value;

    return StreamBuilder<Clan?>(
      stream: clanStream,
      initialData: widget.clan,
      builder: (context, snapshot) {
        final clan = snapshot.data ?? widget.clan;
        final isMember = user != null &&
            (user.clanId == clan.id || clan.memberUids.contains(user.uid) || clan.leaderId == user.uid);

        return Scaffold(
          backgroundColor: const Color(0xFF080B14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF080B14),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Text(
              '[${clan.tag}] ${clan.name}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              if (isMember) ...[
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF5BC8FA)),
                  tooltip: 'Klan Chati',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClanChatScreen(clan: clan),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF4D4D)),
                  tooltip: 'clan.leave_clan_title'.tr(),
                  onPressed: _isLeaving ? null : () => _handleLeave(clan),
                ),
              ],
            ],
          ),
          bottomNavigationBar: !isMember
              ? Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF0D1220),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isJoining ? null : () => _handleJoin(clan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5BC8FA),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: _isJoining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.group_add_rounded, size: 20),
                        label: Text(
                          _isJoining ? 'Qo‘shilmoqda...' : 'Klanga Qo‘shilish',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
          body: Builder(
            builder: (context) {
              final allUids = {clan.leaderId, ...clan.memberUids}.where((id) => id.isNotEmpty).toList();
              return FutureBuilder<List<DocumentSnapshot>>(
                future: Future.wait(
                  allUids.map((uid) => FirebaseFirestore.instance.collection('users').doc(uid).get()),
                ),
                builder: (context, membersSnap) {
                  final docs = membersSnap.data ?? [];

                  int sumTotalPoints = 0;
                  int sumWeeklyPoints = 0;

                  final membersList = docs.map((d) {
                    final data = d.data() as Map<String, dynamic>? ?? {};
                    final uid = d.id;
                    final isLeader = uid == clan.leaderId;
                    final name = data['displayName']?.toString() ??
                        data['name']?.toString() ??
                        (isLeader ? clan.leaderName : 'Klan A‘zosi');
                    final pts = (data['totalPoints'] as num?)?.toInt() ?? 0;
                    final wpts = (data['weeklyPoints'] as num?)?.toInt() ?? 0;

                    sumTotalPoints += pts;
                    sumWeeklyPoints += wpts;

                    return {
                      'uid': uid,
                      'name': name,
                      'points': pts,
                      'isLeader': isLeader,
                      'isMe': user?.uid == uid,
                    };
                  }).toList();

                  // Sort: Leader first, then highest points
                  membersList.sort((a, b) {
                    if (a['isLeader'] == true) return -1;
                    if (b['isLeader'] == true) return 1;
                    return (b['points'] as int).compareTo(a['points'] as int);
                  });

                  if (docs.isEmpty) {
                    sumTotalPoints = clan.totalPoints;
                    sumWeeklyPoints = clan.weeklyPoints;
                  } else {
                    final needsUpdate = sumTotalPoints != clan.totalPoints || sumWeeklyPoints != clan.weeklyPoints;
                    if (needsUpdate) {
                      FirebaseFirestore.instance.collection('clans').doc(clan.id).update({
                        'totalPoints': sumTotalPoints,
                        'weeklyPoints': sumWeeklyPoints,
                      }).catchError((_) {});
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // ── CLAN HERO CARD ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF131929), Color(0xFF0A0F1A)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF5BC8FA).withValues(alpha: 0.3), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x225BC8FA),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5BC8FA).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF5BC8FA), width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(clan.emblem, style: const TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5BC8FA).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF5BC8FA)),
                                      ),
                                      child: Text(
                                        clan.tag,
                                        style: const TextStyle(
                                          color: Color(0xFF5BC8FA),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: clan.isPublic ? const Color(0x3300FF88) : const Color(0x33FF0055),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: clan.isPublic ? const Color(0xFF3B9BFF) : const Color(0xFFFF0055)),
                                      ),
                                      child: Text(
                                        clan.isPublic ? 'clan.status_open'.tr() : 'clan.status_closed'.tr(),
                                        style: TextStyle(
                                          color: clan.isPublic ? const Color(0xFF3B9BFF) : const Color(0xFFFF0055),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  clan.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        clan.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      if (user?.uid == clan.leaderId) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              showClanSettingsModal(context, clan);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5BC8FA),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                            label: Text('clan.clan_settings_mgmt'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Stats Row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0F1A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              label: 'clan.stats_total_points'.tr(),
                              value: '${formatCompactNumber(sumTotalPoints)} PTS',
                              color: const Color(0xFF5BC8FA),
                            ),
                            Container(width: 1, height: 28, color: Colors.white12),
                            _StatItem(
                              label: 'clan.stats_weekly'.tr(),
                              value: '+${formatCompactNumber(sumWeeklyPoints)} PTS',
                              color: const Color(0xFF3B9BFF),
                            ),
                            Container(width: 1, height: 28, color: Colors.white12),
                            _StatItem(
                              label: 'clan.stats_capacity'.tr(),
                              value: '${clan.membersCount}/${clan.maxMembers}',
                              color: const Color(0xFFFFB703),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── MEMBERS SECTION (MAX 25) ─────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'clan.members_section_title'.tr(namedArgs: {
                        'count': '${clan.membersCount}',
                        'max': '${clan.maxMembers}',
                      }),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: clan.isFull ? const Color(0x33FF0055) : const Color(0x3300FF88),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: clan.isFull ? const Color(0xFFFF0055) : const Color(0xFF3B9BFF),
                        ),
                      ),
                      child: Text(
                        clan.isFull
                            ? 'clan.clan_full'.tr()
                            : 'clan.clan_open_slots'.tr(namedArgs: {'count': '${clan.maxMembers - clan.membersCount}'}),
                        style: TextStyle(
                          color: clan.isFull ? const Color(0xFFFF0055) : const Color(0xFF3B9BFF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // All clan members list (Leader + all members)
                Column(
                  children: membersList.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MemberCard(
                      name: m['name'] as String,
                      role: (m['isLeader'] as bool) ? 'clan.role_leader'.tr() : 'clan.role_member'.tr(),
                      points: m['points'] as int,
                      isLeader: m['isLeader'] as bool,
                      isMe: m['isMe'] as bool,
                    ),
                  )).toList(),
                ),
              ],
            ),
          );
        },
      );
    },
  ),
);
},
);
}
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.name,
    required this.role,
    required this.points,
    required this.isLeader,
    required this.isMe,
  });

  final String name;
  final String role;
  final int points;
  final bool isLeader;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF132238) : const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? const Color(0xFF5BC8FA)
              : (isLeader ? const Color(0xFFFFB703).withValues(alpha: 0.5) : Colors.white10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLeader
                  ? const Color(0xFFFFB703).withValues(alpha: 0.15)
                  : const Color(0xFF1C2540),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(isLeader ? '👑' : '🛡️', style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5BC8FA).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('common.you'.tr(), style: const TextStyle(color: Color(0xFF5BC8FA), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(role, style: TextStyle(color: isLeader ? const Color(0xFFFFB703) : Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '$points PTS',
            style: const TextStyle(color: Color(0xFF5BC8FA), fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
