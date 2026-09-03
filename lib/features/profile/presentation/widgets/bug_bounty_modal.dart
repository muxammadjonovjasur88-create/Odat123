import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/widgets.dart';

void showBugBountyModal(BuildContext context) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const BugBountyModal(),
  );
}

class BugBountyModal extends ConsumerStatefulWidget {
  const BugBountyModal({super.key});

  @override
  ConsumerState<BugBountyModal> createState() => _BugBountyModalState();
}

class _BugBountyModalState extends ConsumerState<BugBountyModal> {
  final _descController = TextEditingController();
  bool _isSubmitting = false;
  bool _showMyReports = false;

  static const _botToken = '8855349705:AAGMa9cMyo62Fh8gThoC1xtuRyQwnwu6N4U';
  static const _adminChatId = 658069248;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _sendTelegramAlert({
    required String reportId,
    required String uid,
    required String userName,
    required String description,
    required String deviceInfo,
  }) async {
    try {
      final text = '🐞 *YANGI BUG BOUNTY HISOBOTI!*\n\n'
          '👤 *Foydalanuvchi:* $userName (`$uid`)\n'
          '📄 *Tavsif:* $description\n'
          '📱 *Qurilma:* $deviceInfo\n'
          '💰 *Mukofot:* 4,000 PTS\n\n'
          'Tasdiqlash uchun quyidagi tugmani bosing:';

      await http.post(
        Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _adminChatId,
          'text': text,
          'parse_mode': 'Markdown',
          'reply_markup': {
            'inline_keyboard': [
              [
                {'text': '✅ Tasdiqlash (+4000 PTS)', 'callback_data': 'approve_bug:$reportId:$uid'},
                {'text': '❌ Rad etish', 'callback_data': 'reject_bug:$reportId'},
              ],
            ],
          },
        }),
      );
    } catch (e) {
      debugPrint('⚠️ Direct Telegram notification error: $e');
    }
  }

  Future<void> _submitReport(UserProfile profile) async {
    final desc = _descController.text.trim();

    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF0055),
          content: Text('profile.bug_empty_err'.tr()),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final docRef = FirebaseFirestore.instance.collection('bug_reports').doc();
      final deviceInfo = kIsWeb ? 'Web Browser' : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      final userName = profile.displayName ?? (profile.name.isEmpty ? 'Foydalanuvchi' : profile.name);

      await docRef.set({
        'id': docRef.id,
        'uid': profile.uid,
        'userName': userName,
        'userEmail': profile.email ?? '',
        'description': desc,
        'deviceInfo': deviceInfo,
        'rewardPoints': 4000,
        'status': 'pending', // pending, approved, rejected
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send instant alert to Super Admin via Telegram
      await _sendTelegramAlert(
        reportId: docRef.id,
        uid: profile.uid,
        userName: userName,
        description: desc,
        deviceInfo: deviceInfo,
      );

      if (mounted) {
        _descController.clear();
        setState(() {
          _isSubmitting = false;
          _showMyReports = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A7FCC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF090B18), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Xatolik hisoboti qabul qilindi va adminga yuborildi! Tasdiqlangach +4,000 PTS beriladi',
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
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('Xatolik: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x33FFB703),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pest_control_rounded, color: Color(0xFFFFB703), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BUG BOUNTY DASTURI',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                    Text(
                      'Xatolik toping va +4,000 PTS mukofot oling!',
                      style: TextStyle(color: Color(0xFFFFB703), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showMyReports = !_showMyReports),
                child: Text(
                  _showMyReports ? 'Yangi yozish' : 'Tarix',
                  style: const TextStyle(color: Color(0xFF4AADDC), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_showMyReports)
            Expanded(child: _buildReportsHistory(profile?.uid ?? ''))
          else
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reward Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0x22FFB703), Color(0x115BC8FA)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x44FFB703)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [Color(0xFFFFB703), Color(0xFFFF8C00)]),
                            ),
                            child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF090B18), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Dasturda topgan xatoligingizni yozing. Admin tekshirib tasdiqlashi bilan hisobingizga 4000 PTS qo‘shiladi.',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description Input (Single clean text area)
                    const Text(
                      'Xatolik haqida yozing:',
                      style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090B18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x334AADDC)),
                      ),
                      child: TextField(
                        controller: _descController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText: 'Xatolik qayerda sodir bo‘ldi? Nima ishlamadi? Batafsil yozing...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12.5),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || profile == null ? null : () => _submitReport(profile),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB703),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : Text('profile.send_bug_report'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
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

  Widget _buildReportsHistory(String uid) {
    if (uid.isEmpty) return Center(child: Text('profile.user_not_found'.tr(), style: const TextStyle(color: Colors.white)));

    final reportsStream = FirebaseFirestore.instance
        .collection('bug_reports')
        .where('uid', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: reportsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: FlowaLoading());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📝', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text('profile.no_bugs_yet'.tr(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final desc = data['description'] ?? 'Hisobot';
            final status = data['status'] ?? 'pending';
            final points = data['rewardPoints'] ?? 4000;

            Color statusColor = const Color(0xFFFFB703);
            String statusText = 'Kutilmoqda (Tekshiruvda)';
            if (status == 'approved') {
              statusColor = const Color(0xFF3A7FCC);
              statusText = 'Tasdiqlandi (+$points PTS berildi! ✅)';
            } else if (status == 'rejected') {
              statusColor = const Color(0xFFFF0055);
              statusText = 'Rad etildi ❌';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF090B18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          desc,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '+$points PTS',
                        style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
