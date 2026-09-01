import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  VideoPlayerController? _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _initialized = false;
  bool _navigated = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Hide status bar & navigation bar for edge-to-edge video playback
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } catch (_) {}
    }

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

    // Safety fallback: if video asset fails to load after 6s, navigate forward
    _fallbackTimer = Timer(const Duration(seconds: 6), () {
      if (!_initialized && !_navigated && mounted) {
        debugPrint('IntroVideoScreen fallback timer triggered');
        _navigateToNext();
      }
    });

    _initVideo();
  }

  void _initVideo() {
    _controller = VideoPlayerController.asset('assets/intro/intro.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller?.play();
      }).catchError((error, stackTrace) {
        debugPrint('IntroVideoScreen Error initializing VideoPlayer: $error');
        _navigateToNext();
      });
    _controller?.addListener(_onVideoEnd);
  }

  void _onVideoEnd() {
    final c = _controller;
    if (c != null &&
        c.value.isInitialized &&
        c.value.position >= c.value.duration &&
        c.value.duration > Duration.zero) {
      _navigateToNext();
    }
  }

  void _navigateToNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fallbackTimer?.cancel();
    LocaleStore.setHasSeenIntro();
    if (!kIsWeb) {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (_) {}
    }
    context.go(AppRoutes.languageSelect);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    if (!kIsWeb) {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (_) {}
    }
    _pulseController.dispose();
    _controller?.removeListener(_onVideoEnd);
    _controller?.dispose();
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
            child: _initialized && _controller != null && _controller!.value.isInitialized
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width > 0
                            ? _controller!.value.size.width
                            : 1,
                        height: _controller!.value.size.height > 0
                            ? _controller!.value.size.height
                            : 1,
                        child: VideoPlayer(_controller!),
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
                          color: Color(0xFF5BC8FA),
                          size: 72,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
