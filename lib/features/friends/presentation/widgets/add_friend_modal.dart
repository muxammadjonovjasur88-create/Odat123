import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/user_repository.dart';
import '../../data/friends_repository.dart';

/// Shows the Add Friend / Search Users Modal Bottom Sheet
Future<void> showAddFriendModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddFriendSheet(),
  );
}

class _AddFriendSheet extends ConsumerStatefulWidget {
  const _AddFriendSheet();

  @override
  ConsumerState<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<_AddFriendSheet> {
  final _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  final Set<String> _addedUids = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await ref.read(friendsRepositoryProvider).searchUsers(query);
      final myUid = ref.read(userProfileProvider).asData?.value?.uid;
      if (mounted) {
        setState(() {
          _searchResults = results.where((u) => u.uid != myUid).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addFriend(UserProfile friend) async {
    final myUid = ref.read(userProfileProvider).asData?.value?.uid;
    if (myUid == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _addedUids.add(friend.uid));

    try {
      await ref.read(friendsRepositoryProvider).addFriend(myUid, friend.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A7FCC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text(
              'friends.added_success'.tr(namedArgs: {'name': friend.displayName ?? friend.name}),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addedUids.remove(friend.uid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF0055),
            behavior: SnackBarBehavior.floating,
            content: Text('Xatolik: $e'),
          ),
        );
      }
    }
  }

  void _shareInvite() {
    HapticFeedback.lightImpact();
    final user = ref.read(userProfileProvider).asData?.value;
    final code = user?.uid.substring(0, 6).toUpperCase() ?? 'ODAT';
    Share.share(
      'profile.share_referral_text'.tr(namedArgs: {'code': code}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF090B18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Color(0x664AADDC), width: 1.5),
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
                    color: const Color(0x224AADDC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x444AADDC)),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFF3A7FCC),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'friends.add_title'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF3A7FCC),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'friends.add_sub'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // My ID Card (7-digit number)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF090B18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x444AADDC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, color: Color(0xFF4AADDC), size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ODAT ID',
                          style: TextStyle(
                            color: Color(0xFF4AADDC),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ref.watch(userProfileProvider).asData?.value?.numericId ?? '7429183',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final numId = ref.read(userProfileProvider).asData?.value?.numericId ?? '';
                      Clipboard.setData(ClipboardData(text: numId));
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('profile.id_copied'.tr(namedArgs: {'id': numId})),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF4AADDC),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0x334AADDC),
                      foregroundColor: const Color(0xFF4AADDC),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: Text('profile.id_copied'.tr().contains('📋') ? 'profile.friends_share'.tr() : 'Nusxalash', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Invite Banner
            GestureDetector(
              onTap: _shareInvite,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x224AADDC), Color(0x224AADDC)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x444AADDC)),
                ),
                child: Row(
                  children: [
                    const Text('🚀', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'friends.invite_share_title'.tr(),
                            style: const TextStyle(
                              color: Color(0xFF3A7FCC),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'friends.invite_share_sub'.tr(),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.share_rounded, color: Color(0xFF3A7FCC), size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Pending Friend Requests (if any)
            Builder(
              builder: (context) {
                final requests = ref.watch(friendRequestsProvider).asData?.value ?? [];
                if (requests.isEmpty) return const SizedBox.shrink();

                final myUid = ref.watch(userProfileProvider).asData?.value?.uid ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141F33),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB703), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mark_email_unread_rounded, color: Color(0xFFFFB703), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'friend_requests.title'.tr(),
                            style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...requests.map((req) {
                        final fromUid = req['fromUid'] as String? ?? '';
                        final fromName = req['fromName'] as String? ?? 'Foydalanuvchi';

                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090B18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: Color(0x334AADDC),
                                child: Icon(Icons.person, color: Color(0xFF4AADDC), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  fromName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  await ref.read(friendsRepositoryProvider).acceptFriendRequest(
                                    currentUid: myUid,
                                    fromUid: fromUid,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3A7FCC),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('friend_requests.accept_btn'.tr(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  await ref.read(friendsRepositoryProvider).rejectFriendRequest(
                                    currentUid: myUid,
                                    fromUid: fromUid,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('friend_requests.reject_btn'.tr(), style: const TextStyle(fontSize: 10)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: _performSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'friends.search_hint'.tr(),
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3A7FCC), size: 20),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3A7FCC)),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF090B18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0x22FFFFFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3A7FCC)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Results List
            Flexible(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0x1A4AADDC),
                              ),
                              child: const Icon(Icons.person_search_rounded, color: Color(0xFF4AADDC), size: 28),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'friends.search_hint'.tr()
                                  : 'friends.search_empty'.tr(),
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final friend = _searchResults[index];
                        final isAdded = _addedUids.contains(friend.uid);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090B18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x22FFFFFF)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0x224AADDC),
                                child: Text(
                                  (friend.displayName ?? friend.name).isNotEmpty
                                      ? (friend.displayName ?? friend.name)[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Color(0xFF3A7FCC),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.displayName ?? friend.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '⚡ ${friend.totalPoints} PTS · 🔥 ${friend.streak} ${'profile.days_unit'.tr()}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: isAdded ? null : () => _addFriend(friend),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAdded
                                      ? Colors.white12
                                      : const Color(0xFF3A7FCC),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  isAdded ? 'badges.claimed_done'.tr() : 'profile.friends_add'.tr(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: isAdded ? Colors.white54 : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
