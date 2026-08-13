import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/locale_store.dart';

class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _initialized = false;
  bool _navigated = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    // Hide status bar & navigation bar for edge-to-edge video playback
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // If returning user has already seen the intro, skip video immediately to prevent startup waiting
    if (LocaleStore.hasSeenIntro()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToNext();
      });
      return;
    }

    // Safety fallback: if video asset decoding takes > 1.5s, skip directly to welcome
    _fallbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!_initialized && !_navigated && mounted) {
        _navigateToNext();
      }
    });

    _controller = VideoPlayerController.asset('assets/intro/intro.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
      }).catchError((error, stackTrace) {
        debugPrint('IntroVideoScreen Error initializing VideoPlayer: $error');
        _navigateToNext();
      });
    _controller.addListener(_onVideoEnd);
  }

  void _onVideoEnd() {
    if (_controller.value.isInitialized &&
        _controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      _navigateToNext();
    }
  }

  void _navigateToNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fallbackTimer?.cancel();
    LocaleStore.setHasSeenIntro();
    // Restore system UI overlays before navigating away
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    context.go(AppRoutes.welcome);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    // Restore system UI overlays when leaving this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pulseController.dispose();
    _controller.removeListener(_onVideoEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Edge-to-edge video with smooth fade-in transition once initialized
          AnimatedOpacity(
            opacity: _initialized ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeIn,
            child: _initialized && _controller.value.isInitialized
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width > 0
                            ? _controller.value.size.width
                            : 1,
                        height: _controller.value.size.height > 0
                            ? _controller.value.size.height
                            : 1,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),

          // Pulsating brand logo loading state (fades out smoothly as video starts)
          AnimatedOpacity(
            opacity: _initialized ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            child: _initialized
                ? const SizedBox.shrink()
                : Center(
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Image.asset(
                        'assets/branding/flowa_splash.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.access_time_filled_rounded,
                          color: Color(0xFF00F3FF),
                          size: 72,
                        ),
                      ),
                    ),
                  ),
          ),

          // Skip Button overlay
          Positioned(
            top: 48,
            right: 20,
            child: SafeArea(
              child: TextButton.icon(
                onPressed: _navigateToNext,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0x990A0E17),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0x4400F3FF)),
                  ),
                ),
                icon: const Icon(Icons.skip_next_rounded, size: 18, color: Color(0xFF00F3FF)),
                label: const Text(
                  "O'tkazib yuborish",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
