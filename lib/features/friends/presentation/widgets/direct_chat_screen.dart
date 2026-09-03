import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/avatar_circle.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/friends_repository.dart';
import '../../domain/chat_message.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.myUid,
    required this.myName,
    required this.myAvatar,
    required this.friendUid,
    required this.friendName,
    required this.friendAvatar,
  });

  final String myUid;
  final String myName;
  final String myAvatar;
  final String friendUid;
  final String friendName;
  final String friendAvatar;

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? photoBase64}) async {
    final text = _textController.text.trim();
    if ((text.isEmpty && photoBase64 == null) || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();
    HapticFeedback.lightImpact();

    try {
      await ref.read(friendsRepositoryProvider).sendMessage(
            myUid: widget.myUid,
            friendUid: widget.friendUid,
            text: text,
            senderName: widget.myName,
            senderAvatar: widget.myAvatar,
            photoBase64: photoBase64,
          );
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

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      await _sendMessage(photoBase64: base64Str);
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rasm yuklashda xatolik: $e')),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090B18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4AADDC)),
                title: Text('friends.take_photo'.tr(), style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF3A7FCC)),
                title: Text('friends.pick_gallery'.tr(), style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGiftPtsSheet() {
    final profile = ref.read(userProfileProvider).asData?.value;
    final myPts = profile?.totalPoints ?? 0;
    final myCoins = profile?.fenixCoins ?? 0;
    String currency = 'pts'; // 'pts' or 'coins'
    int selectedAmount = 50;
    final customAmountController = TextEditingController(text: '50');
    final noteController = TextEditingController();

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final maxBalance = currency == 'pts' ? myPts : myCoins;
          final symbol = currency == 'pts' ? '⚡ PTS' : '🪙 Coin';

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Color(0xFF090B18),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFFFFB703), width: 1.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFB703),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFB703), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.friendName} ga sovg‘a yuborish',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Mavjud: $myPts ⚡ PTS | $myCoins 🪙 Coins',
                            style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Currency selector
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => currency = 'pts'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: currency == 'pts' ? const Color(0x33FFB703) : const Color(0xFF090B18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: currency == 'pts' ? const Color(0xFFFFB703) : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text('friends.pts_points'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => currency = 'coins'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: currency == 'coins' ? const Color(0x334AADDC) : const Color(0xFF090B18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: currency == 'coins' ? const Color(0xFF4AADDC) : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text('friends.fenix_coins'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text('friends.select_gift_amount'.tr(), style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [10, 25, 50, 100, 250, 500, 1000].map((amt) {
                    final isSel = selectedAmount == amt;
                    return ChoiceChip(
                      selected: isSel,
                      onSelected: (_) {
                        setModalState(() {
                          selectedAmount = amt;
                          customAmountController.text = '$amt';
                        });
                      },
                      label: Text('$amt', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      selectedColor: const Color(0xFFFFB703),
                      backgroundColor: const Color(0xFF090B18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: customAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Yoki boshqa miqdor kiriting ($symbol)',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    prefixIcon: const Icon(Icons.bolt_rounded, color: Color(0xFFFFB703)),
                    filled: true,
                    fillColor: const Color(0xFF090B18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 0;
                    setModalState(() => selectedAmount = parsed);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Izoh (masalan: "Omad, do‘stim!")',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF090B18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: selectedAmount <= 0 || selectedAmount > maxBalance
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            try {
                              if (currency == 'pts') {
                                await ref.read(friendsRepositoryProvider).sendPtsGift(
                                      myUid: widget.myUid,
                                      friendUid: widget.friendUid,
                                      amount: selectedAmount,
                                      senderName: widget.myName,
                                      senderAvatar: widget.myAvatar,
                                      note: noteController.text.trim(),
                                    );
                              } else {
                                await ref.read(friendsRepositoryProvider).sendCoinGift(
                                      myUid: widget.myUid,
                                      friendUid: widget.friendUid,
                                      amount: selectedAmount,
                                      senderName: widget.myName,
                                      senderAvatar: widget.myAvatar,
                                      note: noteController.text.trim(),
                                    );
                              }
                              HapticFeedback.heavyImpact();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF3A7FCC),
                                    content: Text('🎉 $selectedAmount $symbol muvaffaqiyatli sovg‘a qilindi!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('$e')),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB703),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      selectedAmount > maxBalance
                          ? 'Balansingiz yetarli emas (Mavjud: $maxBalance $symbol)'
                          : 'Yuborish ($selectedAmount $symbol) 🎁',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFullImageModal(String base64Str) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.memory(base64Decode(base64Str), fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatStream = ref
        .watch(friendsRepositoryProvider)
        .watchWeeklyChat(widget.myUid, widget.friendUid);

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            AvatarCircle(
              avatarKey: widget.friendAvatar,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friendName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Haftalik xabarlar tarixi saqlanadi',
                    style: TextStyle(color: Color(0xFF4AADDC), fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFB703)),
            tooltip: 'PTS sovg‘a qilish',
            onPressed: _showGiftPtsSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0x155BC8FA),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF4AADDC)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Do‘stlar bilan xabarlar va PTS sovg‘alar xavfsiz almashiladi.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chatStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: FlowaLoading());
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👋', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          '${widget.friendName} bilan suhbatni boshlang!',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Kuningiz qanday o‘tgani va kvestlar haqida yozing.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return RepaintBoundary(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderUid == widget.myUid;
                      final timeStr = DateFormat('HH:mm').format(msg.createdAt);

                      if (msg.isGift) {
                        return _buildGiftMessageCard(msg, isMe, timeStr);
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF0088CC) : const Color(0xFF090B18),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 16),
                            ),
                            border: Border.all(
                              color: isMe ? const Color(0x334AADDC) : const Color(0x22FFFFFF),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (msg.hasPhoto && msg.photoBase64 != null) ...[
                                GestureDetector(
                                  onTap: () => _showFullImageModal(msg.photoBase64!),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 220),
                                      child: Image.memory(
                                        base64Decode(msg.photoBase64!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                if (msg.text.isNotEmpty) const SizedBox(height: 6),
                              ],
                              if (msg.text.isNotEmpty)
                                Text(
                                  msg.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(10, 8, 14, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 24),
            decoration: const BoxDecoration(
              color: Color(0xFF090B18),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFB703), size: 22),
                    tooltip: 'PTS sovg‘a qilish',
                    onPressed: _showGiftPtsSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4AADDC), size: 22),
                    onPressed: _showImageSourceSheet,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090B18),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0x334AADDC)),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Xabar yozing...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0088CC), Color(0xFF4AADDC)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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

  Widget _buildGiftMessageCard(ChatMessage msg, bool isMe, String timeStr) {
    final giftAmt = msg.giftAmount ?? 0;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF261D0C), Color(0xFF090B18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFB703), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x33FFB703), blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFB703), size: 26),
                const SizedBox(width: 8),
                Text(
                  isMe ? 'Siz $giftAmt PTS sovg‘a yubordingiz! 🎁' : '${msg.senderName} $giftAmt PTS sovg‘a qildi! 🎁',
                  style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isMe ? const Color(0x33FF0055) : const Color(0x3300FF88),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isMe ? '-$giftAmt ⚡ PTS' : '+$giftAmt ⚡ PTS',
                style: TextStyle(
                  color: isMe ? const Color(0xFFFF4D6D) : const Color(0xFF3A7FCC),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            if (msg.text.isNotEmpty && !msg.text.startsWith('🎁')) ...[
              const SizedBox(height: 6),
              Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 4),
            Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
          ],
        ),
      ),
    );
  }
}
