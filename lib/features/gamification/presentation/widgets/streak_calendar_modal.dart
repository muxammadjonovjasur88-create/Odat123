import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/user_repository.dart';
import '../../domain/streak_reward.dart';

/// Shows the 31-Day Interactive Streak Calendar Modal
Future<void> showStreakCalendarModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _StreakCalendarSheet(),
  );
}

class _StreakCalendarSheet extends ConsumerStatefulWidget {
  const _StreakCalendarSheet();

  @override
  ConsumerState<_StreakCalendarSheet> createState() => _StreakCalendarSheetState();
}

class _StreakCalendarSheetState extends ConsumerState<_StreakCalendarSheet> {
  List<DailyStreakReward> get rewards {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return DailyStreakReward.getAllMonthRewards().take(daysInMonth).toList();
  }

  bool _isClaiming = false;
  Set<int> _claimedDays = {};
  Timer? _cooldownTimer;
  Duration _remainingDuration = Duration.zero;
  int _lastClaimEpoch = 0;

  @override
  void initState() {
    super.initState();
    _loadClaimedState();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _checkCooldown();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _checkCooldown() {
    if (_lastClaimEpoch == 0) {
      if (_remainingDuration != Duration.zero) {
        setState(() => _remainingDuration = Duration.zero);
      }
      return;
    }
    final lastDate = DateTime.fromMillisecondsSinceEpoch(_lastClaimEpoch);
    final now = DateTime.now();
    final isSameCalendarDay = lastDate.year == now.year && lastDate.month == now.month && lastDate.day == now.day;

    if (isSameCalendarDay) {
      final midnight = DateTime(now.year, now.month, now.day + 1);
      final leftMs = midnight.difference(now).inMilliseconds;
      if (mounted) {
        setState(() {
          _remainingDuration = Duration(milliseconds: leftMs.clamp(0, 24 * 3600 * 1000));
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _remainingDuration = Duration.zero;
        });
      }
    }
  }

  String _formatRemaining(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _loadClaimedState() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final monthKey = 'claimed_streak_days_${now.year}_${now.month}';
    final saved = prefs.getStringList(monthKey) ?? [];
    final localSet = saved.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
    _lastClaimEpoch = prefs.getInt('last_streak_claim_epoch') ?? 0;
    _checkCooldown();

    // 48-Hour Inactivity Rule: If user didn't claim or log in for 48h, reset streak to 0
    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      if (_lastClaimEpoch > 0) {
        final lastDate = DateTime.fromMillisecondsSinceEpoch(_lastClaimEpoch);
        final hoursPassed = now.difference(lastDate).inHours;
        if (hoursPassed >= 48) {
          await ref.read(userRepositoryProvider).updateStreak(user.uid, 0);
          await prefs.remove(monthKey);
          if (mounted) {
            setState(() => _claimedDays = {});
          }
          return;
        }
      }

      final cloudDays = await ref.read(userRepositoryProvider).getClaimedStreakDays(user.uid, now.month, now.year);
      final combined = {...localSet, ...cloudDays};
      if (mounted) {
        setState(() => _claimedDays = combined);
      }
      await prefs.setStringList(monthKey, combined.map((e) => e.toString()).toList());
      return;
    }

    if (mounted) {
      setState(() => _claimedDays = localSet);
    }
  }

  Future<void> _claimReward(DailyStreakReward reward, int currentStreak) async {
    if (_claimedDays.contains(reward.day) || _isClaiming) return;

    final nextDayToClaim = _claimedDays.isEmpty
        ? 1
        : (_claimedDays.reduce((a, b) => a > b ? a : b) + 1);

    if (reward.day != nextDayToClaim) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF090B18),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Sovg‘alar ketma-ket ochiladi! Hozirgi navbat: $nextDayToClaim-kun 🎁',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    if (_remainingDuration > Duration.zero) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF090B18),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Keyingi kunlik sovg‘a ochilishiga: ${_formatRemaining(_remainingDuration)} vaqt qoldi ⏳',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() => _isClaiming = true);

    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final nowMs = now.millisecondsSinceEpoch;

      HapticFeedback.heavyImpact();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userRepo = ref.read(userRepositoryProvider);
        // Award points, coins, freezes to user
        if (reward.points > 0) {
          await userRepo.awardPoints(uid, reward.points);
        }
        if (reward.coins > 0) {
          await userRepo.addFenixCoins(uid, reward.coins);
        }
        if (reward.freezes > 0) {
          await userRepo.addFreezes(uid, reward.freezes);
        }
        // Save claimed day and update streak in Firestore
        await userRepo.claimStreakDay(uid, reward.day, now.month, now.year);
      }

      final monthKey = 'claimed_streak_days_${now.year}_${now.month}';
      final updated = {..._claimedDays, reward.day};
      await prefs.setStringList(monthKey, updated.map((e) => e.toString()).toList());
      await prefs.setInt('last_streak_claim_epoch', nowMs);
      _lastClaimEpoch = nowMs;
      _checkCooldown();

      if (mounted) {
        setState(() => _claimedDays = updated);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A7FCC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                Text(reward.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${reward.day}-kunlik sovg‘a olindi: ${reward.title}! 🎉',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final currentStreak = user?.streak ?? 1;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF04050D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0x66FFB703), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
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
                  border: Border.all(color: const Color(0x66FFB703)),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Color(0xFFFFB703), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OYLIK STREAK MARAFONI',
                      style: TextStyle(
                        color: Color(0xFFFFB703),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Joriy Streak: $currentStreak Kun 🔥',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
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
          const SizedBox(height: 14),
          if (_remainingDuration > Duration.zero) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x22FFB703),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x66FFB703)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFFFB703)),
                  const SizedBox(width: 8),
                  Text(
                    'Keyingi sovg‘a: ${_formatRemaining(_remainingDuration)} ⏳',
                    style: const TextStyle(
                      color: Color(0xFFFFB703),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),

          // Grid of 31 Days
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                final r = rewards[index];
                final isClaimed = _claimedDays.contains(r.day);
                final effectiveStreak = (currentStreak <= 0) ? 1 : currentStreak;
                final isAvailable = !isClaimed && r.day <= effectiveStreak;
                final isLocked = !isClaimed && !isAvailable;

                return GestureDetector(
                  onTap: () {
                    if (isClaimed) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF090B18),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          content: Text('${r.day}-kunlik sovg‘a allaqachon olingan! ✅', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    } else {
                      _claimReward(r, currentStreak);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isClaimed
                          ? const LinearGradient(
                              colors: [Color(0x224AADDC), Color(0x114AADDC)],
                            )
                          : isAvailable
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    r.color.withValues(alpha: 0.25),
                                    const Color(0xFF090B18),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF0F1522), Color(0xFF0A0E18)],
                                ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isClaimed
                            ? const Color(0xFF3A7FCC)
                            : isAvailable
                                ? r.color
                                : Colors.white12,
                        width: isAvailable ? 1.5 : 1,
                      ),
                      boxShadow: isAvailable
                          ? [
                              BoxShadow(
                                color: r.color.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${r.day}-kun',
                              style: TextStyle(
                                color: isAvailable ? Colors.white : Colors.white38,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isClaimed)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 14)
                            else if (isLocked)
                              const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 13),
                          ],
                        ),
                        Text(
                          r.icon,
                          style: TextStyle(
                            fontSize: r.day >= 30 ? 32 : 26,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              r.title,
                              style: TextStyle(
                                color: isClaimed
                                    ? const Color(0xFF3A7FCC)
                                    : isAvailable
                                        ? Colors.white
                                        : Colors.white60,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isClaimed
                                    ? const Color(0x224AADDC)
                                    : isAvailable
                                        ? r.color.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isClaimed
                                    ? 'OLINDI'
                                    : isAvailable
                                        ? 'OLISH'
                                        : 'QULFLANGAN',
                                style: TextStyle(
                                  color: isClaimed
                                      ? const Color(0xFF3A7FCC)
                                      : isAvailable
                                          ? r.color
                                          : Colors.white24,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
