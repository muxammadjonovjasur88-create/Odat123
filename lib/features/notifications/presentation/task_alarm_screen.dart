import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/theme/app_text_styles.dart';

class TaskAlarmScreen extends ConsumerStatefulWidget {
  final String taskId;
  final String title;
  final int minutesBefore;
  final int notificationId;

  const TaskAlarmScreen({
    super.key,
    required this.taskId,
    required this.title,
    required this.minutesBefore,
    required this.notificationId,
  });

  @override
  ConsumerState<TaskAlarmScreen> createState() => _TaskAlarmScreenState();
}

class _TaskAlarmScreenState extends ConsumerState<TaskAlarmScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _vibrationTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAlarm();
    _startVibration();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _setupAlarm() async {
    try {
      final box = await Hive.openBox('flowa_settings');
      final rawSoundPath = box.get('task_alarm_sound', defaultValue: 'system_alarm') as String;
      
      final soundPath = rawSoundPath == 'assets/sounds/alarm.wav' 
          ? 'system_alarm' 
          : rawSoundPath;

      if (soundPath == 'system_alarm') {
        await _audioPlayer.setUrl('content://settings/system/alarm_alert');
      } else if (soundPath.startsWith('assets/')) {
        await _audioPlayer.setAsset(soundPath);
      } else if (soundPath.startsWith('file://')) {
        await _audioPlayer.setUrl(soundPath);
      } else {
        await _audioPlayer.setFilePath(soundPath);
      }
      
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
      // Fallback
      try {
        await _audioPlayer.setUrl('content://settings/system/alarm_alert');
        await _audioPlayer.setLoopMode(LoopMode.one);
        await _audioPlayer.play();
      } catch (_) {}
    }
  }

  void _startVibration() {
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      HapticFeedback.vibrate();
    });
  }

  Future<void> _stopAlarm() async {
    try {
      await _audioPlayer.stop();
      _vibrationTimer?.cancel();
      
      final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(id: widget.notificationId);
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }

    if (mounted) {
      context.pop();
    }
  }

  Future<void> _startSession() async {
    _stopAlarm();

    try {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) return;

      final task = await ref.read(taskRepositoryProvider).getTask(uid, widget.taskId);
      if (task == null) return;

      if (!mounted) return;

      final titleLow = task.title.toLowerCase();
      if (titleLow.contains('squat') || titleLow.contains('o\'tirib turish')) {
        context.push('${AppRoutes.exerciseCamera}?mode=squat', extra: task);
      } else if (titleLow.contains('pushup') || titleLow.contains('otjimaniye')) {
        context.push('${AppRoutes.exerciseCamera}?mode=pushup', extra: task);
      } else if (titleLow.contains('plank') || titleLow.contains('planka')) {
        context.push('${AppRoutes.exerciseCamera}?mode=plank', extra: task);
      } else {
        context.push(AppRoutes.activeFocus, extra: task);
      }
    } catch (e) {
      debugPrint('Error starting task from alarm: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _vibrationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Premium dark mode background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              
              // Alarm Bell Header Icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4E4E).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF4E4E).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: Color(0xFFFF4E4E),
                    size: 80,
                  ),
                ),
              ),

              // Title and Description
              Column(
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${widget.minutesBefore} daqiqadan keyin boshlanadi',
                      style: AppTextStyles.body.copyWith(
                        color: const Color(0xFFFFC107),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Start & Stop Buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _startSession,
                    child: Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4AADDC),
                            Color(0xFF3A7FCC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4AADDC).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "BOSHLASH",
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _stopAlarm,
                    child: Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Center(
                        child: Text(
                          "TO'XTATISH",
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
