import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/user_repository.dart';

/// Shows the Daily Lucky Wheel Modal Bottom Sheet
Future<void> showLuckyWheelModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _LuckyWheelSheet(),
  );
}

class _LuckyWheelSheet extends ConsumerStatefulWidget {
  const _LuckyWheelSheet();

  @override
  ConsumerState<_LuckyWheelSheet> createState() => _LuckyWheelSheetState();
}

class _WheelPrize {
  final String label;
  final String icon;
  final Color color;
  final int points;
  final int coins;
  final int freezes;

  const _WheelPrize({
    required this.label,
    required this.icon,
    required this.color,
    this.points = 0,
    this.coins = 0,
    this.freezes = 0,
  });
}

class _LuckyWheelSheetState extends ConsumerState<_LuckyWheelSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  double _currentAngle = 0;
  bool _isSpinning = false;
  bool _hasSpunToday = false;
  _WheelPrize? _wonPrize;

  static const List<_WheelPrize> _prizes = [
    _WheelPrize(label: '+100 PTS', icon: '⚡', color: Color(0xFF4AADDC), points: 100),
    _WheelPrize(label: 'Muzlatgich', icon: '❄️', color: Color(0xFF3A7FCC), freezes: 1),
    _WheelPrize(label: '+250 PTS', icon: '⚡', color: Color(0xFF3A7FCC), points: 250),
    _WheelPrize(label: '2x Buster', icon: '🚀', color: Color(0xFFFF0055), points: 150),
    _WheelPrize(label: '+500 PTS', icon: '💎', color: Color(0xFFBF00FF), points: 500),
    _WheelPrize(label: '+50 PTS', icon: '⚡', color: Color(0xFF4AADDC), points: 50),
    _WheelPrize(label: '10 Coin', icon: '🪙', color: Color(0xFFFF9E00), coins: 10),
    _WheelPrize(label: '100 Coin 🔥', icon: '👑', color: Color(0xFFFFB703), coins: 100),
  ];

  Duration _remainingDuration = Duration.zero;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _checkDailyLimit();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _checkDailyLimit();
    });
  }

  Future<void> _checkDailyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final highestSeen = prefs.getInt('highest_seen_epoch') ?? 0;
    int lastSpin = prefs.getInt('last_wheel_spin_epoch') ?? 0;

    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final cloudLastSpin = doc.data()?['lastWheelSpinEpoch'] as int?;
        if (cloudLastSpin != null && cloudLastSpin > lastSpin) {
          lastSpin = cloudLastSpin;
          await prefs.setInt('last_wheel_spin_epoch', cloudLastSpin);
        }
      } catch (_) {}
    }

    if (nowMs < highestSeen) {
      // User turned back phone clock
      if (mounted) {
        setState(() {
          _hasSpunToday = true;
          _remainingDuration = const Duration(hours: 24);
        });
      }
      return;
    }
    await prefs.setInt('highest_seen_epoch', nowMs);

    // 24-hour strict cooldown (86400000 ms)
    final diff = nowMs - lastSpin;
    final isWithinCooldown = diff < (24 * 3600 * 1000);
    if (mounted) {
      setState(() {
        _hasSpunToday = isWithinCooldown;
        if (isWithinCooldown) {
          final leftMs = (24 * 3600 * 1000) - diff;
          _remainingDuration = Duration(milliseconds: leftMs.clamp(0, 24 * 3600 * 1000));
        } else {
          _remainingDuration = Duration.zero;
        }
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  String _formatRemaining(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _spin() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _wonPrize = null;
    });

    final random = Random();

    // Weighted probabilities requested:
    // 1000 Coin: 0.01% (0.0001)
    // 100 Coin: 0.01% (0.0001)
    final roll = random.nextDouble(); // 0.0 to 1.0
    int targetIndex;

    if (roll < 0.0001) {
      // 0.01% -> 100 Coin 🔥 (Index 7)
      targetIndex = 7;
    } else if (roll < 0.0001 + 0.01) {
      // 1.0% -> 10 Coin (Index 6)
      targetIndex = 6;
    } else if (roll < 0.0101 + 0.04) {
      // 4.0% -> +500 PTS (Index 4)
      targetIndex = 4;
    } else if (roll < 0.0501 + 0.10) {
      // 10.0% -> Muzlatgich (Index 1)
      targetIndex = 1;
    } else if (roll < 0.1501 + 0.15) {
      // 15.0% -> 2x Buster (Index 3)
      targetIndex = 3;
    } else if (roll < 0.3001 + 0.20) {
      // 20.0% -> +250 PTS (Index 2)
      targetIndex = 2;
    } else if (roll < 0.5001 + 0.25) {
      // 25.0% -> +100 PTS (Index 0)
      targetIndex = 0;
    } else {
      // ~24.99% -> +50 PTS (Index 5)
      targetIndex = 5;
    }

    final sliceAngle = 2 * pi / _prizes.length;
    final targetCenterAngle = (targetIndex * sliceAngle) + (sliceAngle / 2);
    const pointerAngle = 3 * pi / 2; // Top needle is at 270 degrees

    var rotationOffset = (pointerAngle - targetCenterAngle) % (2 * pi);
    if (rotationOffset < 0) rotationOffset += 2 * pi;

    final startAngle = _currentAngle;
    final startMod = startAngle % (2 * pi);
    var delta = (rotationOffset - startMod) % (2 * pi);
    if (delta < 0) delta += 2 * pi;

    final fullRotations = (6 + random.nextInt(3)) * 2 * pi;
    final endAngle = startAngle + fullRotations + delta;

    _spinAnimation = Tween<double>(
      begin: startAngle,
      end: endAngle,
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutCubic,
    ));

    _spinController.reset();
    _spinController.forward().then((_) async {
      _currentAngle = endAngle;
      final selectedPrize = _prizes[targetIndex];

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final repo = ref.read(userRepositoryProvider);
        if (selectedPrize.points > 0) {
          await repo.awardPoints(uid, selectedPrize.points);
        }
        if (selectedPrize.coins > 0) {
          await repo.addFenixCoins(uid, selectedPrize.coins);
        }
        if (selectedPrize.freezes > 0) {
          await repo.addFreezes(uid, selectedPrize.freezes);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('last_wheel_spin_epoch', nowMs);
      await prefs.setInt('highest_seen_epoch', nowMs);

      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set(
            {'lastWheelSpinEpoch': nowMs},
            SetOptions(merge: true),
          );
        } catch (_) {}
      }

      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _isSpinning = false;
          _hasSpunToday = true;
          _wonPrize = selectedPrize;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF04050D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFFFFB703), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFB703),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x66FFB703)),
                    ),
                    child: const Icon(Icons.casino_rounded, color: Color(0xFFFFB703), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KUNLIK OMAD G‘ILDIRAGI',
                        style: TextStyle(
                          color: Color(0xFFFFB703),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Aylantir va Sovg‘a Yut! 🎰',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // The Lucky Wheel
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Ring
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB703).withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  // Animated Rotating Wheel
                  AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      final angle = _isSpinning ? _spinAnimation.value : _currentAngle;
                      return Transform.rotate(
                        angle: angle,
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: _WheelPainter(prizes: _prizes),
                        ),
                      );
                    },
                  ),

                  // Center Pin Indicator (Top Pointer)
                  Positioned(
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black45, blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Color(0xFFFF0055),
                        size: 28,
                      ),
                    ),
                  ),

                  // Center Hub
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFB703), Color(0xFFFF5400)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'ODAT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_wonPrize != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x224AADDC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3A7FCC)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_wonPrize!.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    'TABRIKLAYMIZ: ${_wonPrize!.label}! 🎉',
                    style: const TextStyle(
                      color: Color(0xFF3A7FCC),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Spin Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSpinning
                  ? null
                  : _hasSpunToday
                      ? null
                      : _spin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: Colors.black,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSpinning
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        ),
                        const SizedBox(width: 10),
                        Text('gamification.spinning'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    )
                  : Text(
                      _hasSpunToday ? 'KEYINGI AYLANTIRISH: ${_formatRemaining(_remainingDuration)} ⏳' : 'AYLANTIRISH (BEPUL) 🎰',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<_WheelPrize> prizes;
  const _WheelPainter({required this.prizes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final arcAngle = 2 * pi / prizes.length;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < prizes.length; i++) {
      paint.color = prizes[i].color.withValues(alpha: i % 2 == 0 ? 0.9 : 0.7);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * arcAngle,
        arcAngle,
        true,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * arcAngle,
        arcAngle,
        true,
        borderPaint,
      );

      // Draw Icon & Text
      final textAngle = i * arcAngle + (arcAngle / 2);
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      final textSpan = TextSpan(
        text: '${prizes[i].icon}\n${prizes[i].label}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
