import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/user_repository.dart';

/// Shows the Player Inventory & Active Boosters Modal
Future<void> showInventoryModal(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _InventoryModalSheet(),
  );
}

class _InventoryModalSheet extends ConsumerStatefulWidget {
  const _InventoryModalSheet();

  @override
  ConsumerState<_InventoryModalSheet> createState() => _InventoryModalSheetState();
}

class _InventoryModalSheetState extends ConsumerState<_InventoryModalSheet> {
  Timer? _timer;
  int _activeMultiplier = 1;
  int _remainingBoosterSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkActiveBooster();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _checkActiveBooster());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkActiveBooster() async {
    final prefs = await SharedPreferences.getInstance();
    final expireMs = prefs.getInt('active_booster_expire_ms') ?? 0;
    final mult = prefs.getDouble('active_booster_multiplier') ?? 1.0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (mounted) {
      setState(() {
        if (expireMs > nowMs) {
          _activeMultiplier = mult.round();
          _remainingBoosterSeconds = ((expireMs - nowMs) / 1000).ceil();
        } else {
          _activeMultiplier = 1;
          _remainingBoosterSeconds = 0;
        }
      });
    }
  }

  String _formatTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '$h soat $m daq';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _activateBooster({
    required String boosterId,
    required double multiplier,
    required int durationMinutes,
    required String title,
  }) async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expireMs = nowMs + (durationMinutes * 60 * 1000);

    await prefs.setInt('active_booster_expire_ms', expireMs);
    await prefs.setDouble('active_booster_multiplier', multiplier);

    // Deduct 1 item from inventory in Firestore
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'inventory.$boosterId': FieldValue.increment(-1),
        'inventory': {
          boosterId: FieldValue.increment(-1),
        },
      }, SetOptions(merge: true));
    } catch (_) {}

    HapticFeedback.heavyImpact();
    _checkActiveBooster();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3B9BFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
          content: Text(
            '$title muvaffaqiyatli faollashtirildi! ($multiplier x PTS) 🚀',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
          ),
        ),
      );
    }
  }

  Future<void> _useNameChangeToken(BuildContext context, String uid) async {
    final controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1220),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('profile.change_name'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Yangi ismingizni kiriting...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF131929),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr(), style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B9BFF),
              foregroundColor: Colors.black,
            ),
            child: Text('profile.change'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': newName,
        'displayName': newName,
        'inventory.name_change_token': FieldValue.increment(-1),
        'inventory': {
          'name_change_token': FieldValue.increment(-1),
        },
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B9BFF),
            duration: const Duration(seconds: 2),
            content: Text('Ismingiz muvaffaqiyatli "$newName" ga o‘zgartirildi! ✨', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).asData?.value;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final rawInventory = data['inventory'] as Map<String, dynamic>? ?? {};
        final inventory = Map<String, dynamic>.from(rawInventory);

        for (final entry in data.entries) {
          if (entry.key.startsWith('inventory.')) {
            final key = entry.key.substring(10);
            inventory[key] = ((inventory[key] as num?)?.toInt() ?? 0) + ((entry.value as num?)?.toInt() ?? 0);
          }
        }

        final freezes = (data['freezes'] as num?)?.toInt() ?? user.freezes;
        final nameTokens = (inventory['name_change_token'] as num?)?.toInt() ?? 0;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF080B14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: Color(0xFF5BC8FA), width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x225BC8FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF5BC8FA)),
                ),
                child: const Icon(Icons.backpack_rounded, color: Color(0xFF5BC8FA), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHAXSIY ANJOM VA BUSTERLAR',
                      style: TextStyle(
                        color: Color(0xFF5BC8FA),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'O‘yinchi Inventari',
                      style: TextStyle(
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

          // Active Booster Banner
          if (_remainingBoosterSeconds > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF002228)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3B9BFF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF3B9BFF), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚡ $_activeMultiplier.0x PTS BUSTER FAOLLASHTIRILGAN',
                          style: const TextStyle(
                            color: Color(0xFF3B9BFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qolgan vaqt: ${_formatTime(_remainingBoosterSeconds)}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Builder(
              builder: (context) {
                final List<Widget> items = [];

                // 1. Streak Muzlatgich
                if (freezes > 0) {
                  items.add(_buildInventoryItem(
                    title: 'Streak Muzlatgich (Freeze)',
                    subtitle: 'Streakingizni uzilishdan avtomatik himoyalaydi',
                    count: freezes,
                    icon: Icons.ac_unit_rounded,
                    color: const Color(0xFF5BC8FA),
                    actionText: 'Himoyada 🛡️',
                    isUsable: false,
                    onUse: () {},
                  ));
                  items.add(const SizedBox(height: 12));
                }

                // 2. Nom o'zgartirish ruxsatnomasi
                if (nameTokens > 0) {
                  items.add(_buildInventoryItem(
                    title: 'Nom O‘zgartirish Ruxsatnomasi',
                    subtitle: 'Profil nomini istalgan nomga almashtirish vaucheri',
                    count: nameTokens,
                    icon: Icons.badge_rounded,
                    color: const Color(0xFFFFB703),
                    actionText: 'Ishlatish ✏️',
                    isUsable: true,
                    onUse: () => _useNameChangeToken(context, user.uid),
                  ));
                  items.add(const SizedBox(height: 12));
                }

                // 3. Dynamic Boosters from inventory
                final boosterConfigs = {
                  'booster_125': {'title': '1.25x Kichik Buster (30 daqiqa)', 'sub': '30 daqiqa +25% PTS beradi', 'mul': 1.25, 'min': 30, 'col': const Color(0xFF3B9BFF), 'icon': Icons.bolt_rounded},
                  'booster_15': {'title': '1.5x Standart Buster (30 daqiqa)', 'sub': '30 daqiqa +50% PTS beradi', 'mul': 1.5, 'min': 30, 'col': const Color(0xFF5BC8FA), 'icon': Icons.bolt_rounded},
                  'booster_2x': {'title': '2.0x Oltin Buster (1 soat)', 'sub': '1 soat davomida +100% PTS beradi', 'mul': 2.0, 'min': 60, 'col': const Color(0xFFFFB703), 'icon': Icons.electric_bolt_rounded},
                  'booster_25': {'title': '2.5x Mega Buster (45 daqiqa)', 'sub': '45 daqiqa davomida +150% PTS beradi', 'mul': 2.5, 'min': 45, 'col': const Color(0xFFFF7700), 'icon': Icons.flash_on_rounded},
                  'booster_3x': {'title': '3.0x Titan Buster (1 soat)', 'sub': '1 soat davomida 3 barobar maksimal PTS!', 'mul': 3.0, 'min': 60, 'col': const Color(0xFFFF0055), 'icon': Icons.military_tech_rounded},
                };

                for (final entry in boosterConfigs.entries) {
                  final bId = entry.key;
                  final count = (inventory[bId] as num?)?.toInt() ?? 0;
                  if (count > 0) {
                    final cfg = entry.value;
                    items.add(_buildInventoryItem(
                      title: cfg['title'] as String,
                      subtitle: cfg['sub'] as String,
                      count: count,
                      icon: cfg['icon'] as IconData,
                      color: cfg['col'] as Color,
                      actionText: 'Faollashtirish ⚡',
                      isUsable: true,
                      onUse: () => _activateBooster(
                        boosterId: bId,
                        multiplier: (cfg['mul'] as num).toDouble(),
                        durationMinutes: cfg['min'] as int,
                        title: cfg['title'] as String,
                      ),
                    ));
                    items.add(const SizedBox(height: 12));
                  }
                }

                // 4. Any other custom items, coupons, or gifts in inventory
                final handledKeys = {'name_change_token', 'freeze', ...boosterConfigs.keys};
                for (final entry in inventory.entries) {
                  if (handledKeys.contains(entry.key)) continue;
                  final count = (entry.value as num?)?.toInt() ?? 0;
                  if (count > 0) {
                    final rawKey = entry.key;
                    final title = rawKey.replaceAll('_', ' ').toUpperCase();
                    items.add(_buildInventoryItem(
                      title: title,
                      subtitle: 'Do‘kondan xarid qilingan buyum / kupon',
                      count: count,
                      icon: Icons.card_giftcard_rounded,
                      color: const Color(0xFF3B9BFF),
                      actionText: 'Mavjud ✅',
                      isUsable: false,
                      onUse: () {},
                    ));
                    items.add(const SizedBox(height: 12));
                  }
                }

                // If nothing in inventory
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0x155BC8FA),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x335BC8FA)),
                            ),
                            child: const Icon(Icons.backpack_outlined, color: Color(0xFF5BC8FA), size: 42),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Inventaringiz hozircha bo‘sh 🎒',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Do‘kondan busterlar, muzlatgich yoki nom o‘zgartirish vaucherini xarid qilsangiz, ular shu yerda saqlanadi',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  children: items,
                );
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildInventoryItem({
    required String title,
    required String subtitle,
    required int count,
    required IconData icon,
    required Color color,
    required String actionText,
    required bool isUsable,
    required VoidCallback onUse,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mavjud: $count ta',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isUsable ? onUse : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              actionText,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
