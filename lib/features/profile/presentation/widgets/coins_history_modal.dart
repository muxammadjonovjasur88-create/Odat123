import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/user_repository.dart';

/// Shows the Interactive Neon Fenix Coins Transaction History Modal Bottom Sheet
Future<void> showCoinsHistoryModal(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _CoinsHistorySheet(),
  );
}

class _CoinsHistorySheet extends ConsumerWidget {
  const _CoinsHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final currentCoins = user?.fenixCoins ?? 0;
    final uid = user?.uid ?? '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF04050D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFFFFB703), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x22FFB703),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB703)),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Color(0xFFFFB703), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FENIX COIN BALANSI VA TARIXI',
                      style: TextStyle(
                        color: Color(0xFFFFB703),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '$currentCoins Fenix Coin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF090B18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: Color(0xFFFFB703), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hisob to‘ldirish, kuponlar, omad g‘ildiragi va barcha tangalar harakati:',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stream list of Coins History
          Expanded(
            child: uid.isEmpty
                ? Center(child: Text('profile.user_not_found'.tr(), style: TextStyle(color: Colors.white54)))
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('coins_history')
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];

                      // If no recorded transactions yet, show clean empty state
                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0x15FFB703),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0x33FFB703)),
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFFFB703), size: 36),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Hozircha tangalar tarixi mavjud emas',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Hisobingiz to‘ldirilganda, kupon ishlatilganda yoki xarid qilinganda operatsiyalar bu yerda saqlanadi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final title = data['title']?.toString() ?? 'Fenix Coin amaliyoti';
                          final category = data['category']?.toString() ?? 'Tanga amali';
                          final amount = (data['amount'] as num?)?.toInt() ?? 0;
                          final type = data['type']?.toString() ?? 'earn';
                          final isEarn = type == 'earn' || amount > 0;
                          final ts = data['createdAt'] as Timestamp?;
                          final dateStr = ts != null
                              ? DateFormat('dd.MM.yyyy HH:mm').format(ts.toDate())
                              : 'Yaqinda';

                          IconData icon = Icons.local_fire_department_rounded;
                          Color color = const Color(0xFFFFB703);

                          if (title.contains('To‘ldirish') || title.contains('Karta') || title.contains('Payme')) {
                            icon = Icons.credit_card_rounded;
                            color = const Color(0xFFFF5400);
                          } else if (title.contains('Kupon') || title.contains('Promokod')) {
                            icon = Icons.card_giftcard_rounded;
                            color = const Color(0xFF4AADDC);
                          } else if (title.contains('G‘ildirak') || title.contains('Wheel')) {
                            icon = Icons.casino_rounded;
                            color = const Color(0xFF3A7FCC);
                          } else if (!isEarn) {
                            icon = Icons.shopping_bag_rounded;
                            color = const Color(0xFFFF0055);
                          }

                          return _buildCoinCard(_CoinHistoryItem(
                            title: title,
                            category: category,
                            amount: amount.abs(),
                            isEarn: isEarn,
                            dateStr: dateStr,
                            icon: icon,
                            color: color,
                          ));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinCard(_CoinHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.category,
                      style: TextStyle(
                        color: item.color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.dateStr,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.isEarn
                  ? const Color(0x224AADDC)
                  : const Color(0x22FF0055),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.isEarn ? '+${item.amount} Coin' : '-${item.amount} Coin',
              style: TextStyle(
                color: item.isEarn ? const Color(0xFF3A7FCC) : const Color(0xFFFF0055),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinHistoryItem {
  final String title;
  final String category;
  final int amount;
  final bool isEarn;
  final String dateStr;
  final IconData icon;
  final Color color;

  const _CoinHistoryItem({
    required this.title,
    required this.category,
    required this.amount,
    required this.isEarn,
    required this.dateStr,
    required this.icon,
    required this.color,
  });
}
