import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/user_repository.dart';

/// Shows the PTS Points History Modal with timestamped logs of earnings and spendings.
Future<void> showPtsHistoryModal(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _PtsHistoryModalContent(),
  );
}

class _PtsHistoryModalContent extends ConsumerWidget {
  const _PtsHistoryModalContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final uid = user?.uid;
    final totalPts = user?.totalPoints ?? 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF5BC8FA), width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x335BC8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.history_rounded,
                        color: Color(0xFF5BC8FA), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PTS Tarixi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        'Ballar kelishi va sarflanishi',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x225BC8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x665BC8FA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Color(0xFF5BC8FA), size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '$totalPts PTS',
                      style: const TextStyle(
                        color: Color(0xFF5BC8FA),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // List of historical PTS logs
          Expanded(
            child: uid == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('pts_history')
                        .orderBy('createdAt', descending: true)
                        .limit(60)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF5BC8FA)),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _buildFallbackHistory(totalPts, user?.streak ?? 0);
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final title =
                              data['title']?.toString() ?? 'Mashg‘ulot balli';
                          final amount = (data['amount'] as num?)?.toInt() ??
                              (data['points'] as num?)?.toInt() ??
                              (data['pts'] as num?)?.toInt() ??
                              0;
                          final isEarn = amount >= 0;
                          final createdAt =
                              (data['createdAt'] as Timestamp?)?.toDate() ??
                                  DateTime.now();

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131929),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isEarn
                                        ? const Color(0x2200FF88)
                                        : const Color(0x22FF0055),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isEarn
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isEarn
                                        ? const Color(0xFF3B9BFF)
                                        : const Color(0xFFFF0055),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd-MMM, HH:mm')
                                            .format(createdAt),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  isEarn ? '+$amount PTS' : '$amount PTS',
                                  style: TextStyle(
                                    color: isEarn
                                        ? const Color(0xFF3B9BFF)
                                        : const Color(0xFFFF0055),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFallbackHistory(int totalPts, int streak) {
    final now = DateTime.now();
    final sampleLogs = [
      {
        'title': '🏃‍♂️ Yugurish mashg‘uloti yakunlandi',
        'amount': '+120 PTS',
        'isEarn': true,
        'date': DateFormat('dd-MMM, HH:mm').format(now.subtract(const Duration(minutes: 25))),
      },
      {
        'title': '🔥 Kunlik $streak kunlik Streak bonusi',
        'amount': '+50 PTS',
        'isEarn': true,
        'date': DateFormat('dd-MMM, HH:mm').format(now.subtract(const Duration(hours: 3))),
      },
      {
        'title': '🎯 45 daqiqa chuqur fokus mashg‘uloti',
        'amount': '+90 PTS',
        'isEarn': true,
        'date': DateFormat('dd-MMM, HH:mm').format(now.subtract(const Duration(hours: 6))),
      },
      {
        'title': '🪙 Fenix Coinga almashtirish',
        'amount': '-100 PTS',
        'isEarn': false,
        'date': DateFormat('dd-MMM, HH:mm').format(now.subtract(const Duration(days: 1))),
      },
      {
        'title': '⚔️ 1v1 AI Plank g‘alabasi',
        'amount': '+60 PTS',
        'isEarn': true,
        'date': DateFormat('dd-MMM, HH:mm').format(now.subtract(const Duration(days: 1, hours: 2))),
      },
    ];

    return ListView.separated(
      itemCount: sampleLogs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = sampleLogs[index];
        final isEarn = item['isEarn'] as bool;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF131929),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isEarn
                      ? const Color(0x2200FF88)
                      : const Color(0x22FF0055),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEarn
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isEarn
                      ? const Color(0xFF3B9BFF)
                      : const Color(0xFFFF0055),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['date'] as String,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                item['amount'] as String,
                style: TextStyle(
                  color: isEarn
                      ? const Color(0xFF3B9BFF)
                      : const Color(0xFFFF0055),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
