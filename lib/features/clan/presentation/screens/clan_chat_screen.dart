import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/avatar_circle.dart';
import '../../domain/models/clan.dart';

/// Real-time Clan Group Chat Screen for all members of the Clan.
class ClanChatScreen extends ConsumerStatefulWidget {
  const ClanChatScreen({
    super.key,
    required this.clan,
  });

  final Clan clan;

  @override
  ConsumerState<ClanChatScreen> createState() => _ClanChatScreenState();
}

class _ClanChatScreenState extends ConsumerState<ClanChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendPhoto(
    ImageSource source,
    String uid,
    String name,
    String avatar,
  ) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isSending = true);
      HapticFeedback.lightImpact();

      final bytes = await File(picked.path).readAsBytes();
      final base64Img = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final clanChatCol = FirebaseFirestore.instance
          .collection('clan_chats')
          .doc(widget.clan.id)
          .collection('messages');

      await clanChatCol.add({
        'senderUid': uid,
        'senderName': name,
        'senderAvatar': avatar,
        'text': '📷 Rasm',
        'imageBase64': base64Img,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage(String uid, String name, String avatar) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();
    HapticFeedback.lightImpact();

    try {
      final clanChatCol = FirebaseFirestore.instance
          .collection('clan_chats')
          .doc(widget.clan.id)
          .collection('messages');

      await clanChatCol.add({
        'senderUid': uid,
        'senderName': name,
        'senderAvatar': avatar,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final myUid = user?.uid ?? '';
    final myName = user?.displayName ?? user?.name ?? 'Foydalanuvchi';
    final myAvatar = user?.avatar ?? 'cat';

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1220),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0x225BC8FA),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF5BC8FA)),
              ),
              alignment: Alignment.center,
              child: Text(widget.clan.emblem,
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[${widget.clan.tag}] ${widget.clan.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.clan.membersCount} a‘zolar guruhi',
                    style: const TextStyle(
                        color: Color(0xFF5BC8FA), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Notice banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0x155BC8FA),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, size: 14, color: Color(0xFF5BC8FA)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Klaningiz a’zolari bilan strategiya va yutuqlarni muhokama qiling!',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Message Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('clan_chats')
                  .doc(widget.clan.id)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5BC8FA)),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 12),
                        Text(
                          '[${widget.clan.tag}] Klan Chatiga xush kelibsiz!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Birinchi bo‘lib xabar yozing!',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderUid = data['senderUid']?.toString() ?? '';
                    final senderName =
                        data['senderName']?.toString() ?? 'A’zo';
                    final senderAvatar =
                        data['senderAvatar']?.toString() ?? 'cat';
                    final text = data['text']?.toString() ?? '';
                    final isMe = senderUid == myUid;
                    final isLeader = senderUid == widget.clan.leaderId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            AvatarCircle(
                              avatarKey: senderAvatar,
                              size: 32,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF005577)
                                    : const Color(0xFF131929),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                border: Border.all(
                                  color: isMe
                                      ? const Color(0xFF5BC8FA)
                                      : (isLeader
                                          ? const Color(0xFFFFB703)
                                          : Colors.white12),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            senderName,
                                            style: TextStyle(
                                              color: isLeader
                                                  ? const Color(0xFFFFB703)
                                                  : const Color(0xFF5BC8FA),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (isLeader) ...[
                                            const SizedBox(width: 4),
                                            const Text('👑',
                                                style: TextStyle(fontSize: 10)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  if (data['imageBase64'] != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        base64Decode((data['imageBase64'] as String)
                                            .replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '')),
                                        fit: BoxFit.cover,
                                        width: 200,
                                        height: 200,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  if (text.isNotEmpty && text != '📷 Rasm')
                                    Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (isMe) const SizedBox(width: 6),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Text Input Bar with Camera/Photo support
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: const Color(0xFF0D1220),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_rounded,
                        color: Color(0xFF5BC8FA), size: 24),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFF0E1526),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (ctx) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF5BC8FA)),
                                title: Text('clan.take_photo'.tr(), style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickAndSendPhoto(ImageSource.camera, myUid, myName, myAvatar);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFFFB703)),
                                title: Text('clan.choose_gallery'.tr(), style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickAndSendPhoto(ImageSource.gallery, myUid, myName, myAvatar);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Xabaringizni yozing...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF131929),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) =>
                          _sendMessage(myUid, myName, myAvatar),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF5BC8FA),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.black, size: 20),
                      onPressed: () =>
                          _sendMessage(myUid, myName, myAvatar),
                    ),
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
