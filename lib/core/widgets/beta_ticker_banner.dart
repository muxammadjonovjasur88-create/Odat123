import 'package:flutter/material.dart';

/// Lightweight, non-blocking Animated Ticker banner for Beta Testing mode.
/// Completely isolated from main thread loops, never blocks gestures or UI rendering.
class BetaTickerBanner extends StatefulWidget {
  const BetaTickerBanner({super.key});

  @override
  State<BetaTickerBanner> createState() => _BetaTickerBannerState();
}

class _BetaTickerBannerState extends State<BetaTickerBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  static const String _message =
      '⚡ DIQQAT: ODAT ilovasi hozirda BETA sinov rejimida ishlamoqda • Barcha funksiyalar faol! • 🧪 ODAT BETA TEST';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: double.infinity,
        height: 24,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF9100).withValues(alpha: 0.18),
              const Color(0xFF5BC8FA).withValues(alpha: 0.12),
              const Color(0xFFFF9100).withValues(alpha: 0.18),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFFFF9100).withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            // Static left badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: const Color(0xFFFF9100),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science_rounded, size: 12, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'BETA',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Smooth Animated Text Marquee
            Expanded(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return FractionalTranslation(
                      translation: Offset(1.0 - (_animController.value * 2.0), 0.0),
                      child: child,
                    );
                  },
                  child: const Text(
                    _message,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
