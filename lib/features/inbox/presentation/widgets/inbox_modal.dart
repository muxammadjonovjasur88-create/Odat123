import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/user_repository.dart';
import '../../data/inbox_repository.dart';
import '../../domain/models/app_message.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../friends/presentation/widgets/direct_chat_screen.dart';

/// Shows the Inbox & Notifications Modal Bottom Sheet
Future<void> showInboxModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _InboxSheet(),
  );
}

class _InboxSheet extends ConsumerStatefulWidget {
  const _InboxSheet();

  @override
  ConsumerState<_InboxSheet> createState() => _InboxSheetState();
}

class _InboxSheetState extends ConsumerState<_InboxSheet> {
  String _activeFilter = 'all'; // 'all', 'friend', 'admin', 'system'

  @override
  Widget build(BuildContext context) {
    final allMessages = ref.watch(inboxRepositoryProvider);

    final filteredMessages = allMessages.where((msg) {
      if (_activeFilter == 'friend') return msg.type == MessageType.friend;
      if (_activeFilter == 'admin') return msg.type == MessageType.admin;
      if (_activeFilter == 'system') {
        return msg.type == MessageType.system ||
            msg.type == MessageType.reward ||
            msg.type == MessageType.achievement ||
            msg.type == MessageType.clan;
      }
      return true;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0x665BC8FA), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x225BC8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x445BC8FA)),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF5BC8FA),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'XABARLAR & BILDIRISHNOMALAR',
                      style: TextStyle(
                        color: Color(0xFF5BC8FA),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Xabarlar Qutisi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (allMessages.any((m) => !m.isRead))
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(inboxRepositoryProvider.notifier).markAllAsRead();
                  },
                  child: const Text(
                    'Barchasi o‘qildi',
                    style: TextStyle(
                      color: Color(0xFF5BC8FA),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'Barchasi', Icons.inbox_rounded),
                const SizedBox(width: 8),
                _filterChip('friend', 'Do‘stlardan', Icons.people_alt_rounded),
                const SizedBox(width: 8),
                _filterChip('admin', 'Dasturchidan', Icons.code_rounded),
                const SizedBox(width: 8),
                _filterChip('system', 'Tizimdan', Icons.notifications_rounded),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Messages List
          Flexible(
            child: filteredMessages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Bu toifada xabarlar yo‘q',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredMessages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final msg = filteredMessages[index];
                      return _MessageCard(message: msg);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label, IconData icon) {
    final isSelected = _activeFilter == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeFilter = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5BC8FA) : const Color(0xFF131929),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF5BC8FA) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({required this.message});

  final AppMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReward = (message.rewardPoints > 0 || message.rewardCoins > 0) && !message.isClaimed;

    return Dismissible(
      key: Key('inbox_msg_${message.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF0055),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.white, size: 24),
            SizedBox(width: 6),
            Text(
              "O'chirish",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(inboxRepositoryProvider.notifier).deleteMessage(message.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D1220),
            duration: const Duration(seconds: 2),
            content: Text('inbox.message_deleted'.tr()),
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          if (!message.isRead) {
            ref.read(inboxRepositoryProvider.notifier).markAsRead(message.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: message.isRead ? const Color(0xFF0D1220) : const Color(0xFF142036),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: message.isRead ? const Color(0x15FFFFFF) : message.accentColor.withValues(alpha: 0.5),
              width: message.isRead ? 1 : 1.5,
            ),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: message.isRead ? FontWeight.w700 : FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (!message.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: message.accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.body,
                        style: TextStyle(
                          color: message.isRead ? Colors.white60 : Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (message.senderUid != null) ...[
              Builder(
                builder: (context) {
                  final isFriendRequest = message.id.startsWith('freq_') ||
                      (message.title.toLowerCase().contains('taklif') && !message.isFriendAccepted);

                  if (isFriendRequest) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final myUid = ref.read(userProfileProvider).asData?.value?.uid;
                                if (myUid == null || message.senderUid == null) return;
                                HapticFeedback.heavyImpact();
                                try {
                                  await ref.read(friendsRepositoryProvider).acceptFriendRequest(
                                    currentUid: myUid,
                                    fromUid: message.senderUid!,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF3B9BFF),
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                          "Do'stlik taklifi qabul qilindi! 🎉",
                                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                        ),
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B9BFF),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_rounded, size: 16),
                              label: const Text(
                                'Qabul qilish',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final myUid = ref.read(userProfileProvider).asData?.value?.uid;
                              if (myUid == null || message.senderUid == null) return;
                              HapticFeedback.lightImpact();
                              await ref.read(friendsRepositoryProvider).rejectFriendRequest(
                                currentUid: myUid,
                                fromUid: message.senderUid!,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF0055),
                              side: const BorderSide(color: Color(0xFFFF0055)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text(
                              'Rad etish',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Regular Chat Message Notification -> Open Chat
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final myProfile = ref.read(userProfileProvider).asData?.value;
                          if (myProfile == null) return;
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DirectChatScreen(
                                myUid: myProfile.uid,
                                myName: myProfile.name,
                                myAvatar: myProfile.avatar,
                                friendUid: message.senderUid!,
                                friendName: message.senderName ?? 'Do‘st',
                                friendAvatar: message.senderAvatar ?? 'leaf',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0088CC),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 15),
                        label: Text('Xabarni ochish (${message.senderName ?? "Do‘st"}) 💬', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  );
                },
              ),
            ],
            if (hasReward) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x22FFD700),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x44FFD700)),
                ),
                child: Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mukofot: +${message.rewardPoints} PTS · +${message.rewardCoins} Coins',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        await ref.read(inboxRepositoryProvider.notifier).claimReward(message.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF3B9BFF),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              content: Text(
                                '+${message.rewardPoints} PTS va +${message.rewardCoins} Fenix Coin hisobingizga qo‘shildi! 🎉',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('common.claim'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}
