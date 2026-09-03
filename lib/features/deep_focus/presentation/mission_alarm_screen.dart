import 'dart:async';
import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../exercise_vision/domain/services/exercise_strategy.dart';
import '../../exercise_vision/domain/services/pose_detector_service.dart';
import '../../exercise_vision/domain/services/pushup_strategy.dart';
import '../../exercise_vision/domain/services/squat_strategy.dart';
import '../../exercise_vision/presentation/widgets/skeleton_painter.dart';
import '../../notifications/data/notification_service.dart';

class MissionAlarmScreen extends ConsumerStatefulWidget {
  final bool autoStart;
  const MissionAlarmScreen({super.key, this.autoStart = false});

  @override
  ConsumerState<MissionAlarmScreen> createState() => _MissionAlarmScreenState();
}

class _MissionAlarmScreenState extends ConsumerState<MissionAlarmScreen> {
  // Screen Mode: 'settings' or 'active_mission'
  bool _isActiveMission = false;

  // Alarm Settings State
  TimeOfDay _alarmTime = const TimeOfDay(hour: 6, minute: 30);
  bool _isAlarmEnabled = true;
  final List<bool> _selectedDays = [true, true, true, true, true, true, true]; // Mon-Sun
  int _targetSquats = 20;
  int _targetPushups = 20;

  // Camera & ML Kit
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 1; // Default to front camera
  bool _isCameraInitialized = false;
  late final PoseDetectorService _poseDetectorService;

  // Stages: 1 -> Squat, 2 -> Pushup, 3 -> Completed
  int _currentStage = 1;
  int _squatsDone = 0;
  int _pushupsDone = 0;

  late ExerciseStrategy _squatStrategy;
  late ExerciseStrategy _pushupStrategy;

  List<Pose> _poses = [];
  bool _isProcessingFrame = false;
  int _lastFrameTimeMs = 0;
  static const int _frameIntervalMs = 30;

  // Audio Player for Loud Alarm
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  bool _missionCompleted = false;

  @override
  void initState() {
    super.initState();
    _poseDetectorService = PoseDetectorService();
    _squatStrategy = SquatStrategy();
    _pushupStrategy = PushUpStrategy();
    _loadSavedAlarmSettings();

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startActiveMission();
      });
    }
  }

  Future<void> _loadSavedAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('mission_alarm_hour') ?? 6;
    final minute = prefs.getInt('mission_alarm_minute') ?? 30;
    final enabled = prefs.getBool('mission_alarm_enabled') ?? true;
    if (mounted) {
      setState(() {
        _alarmTime = TimeOfDay(hour: hour, minute: minute);
        _isAlarmEnabled = enabled;
      });
    }
  }

  Future<void> _saveAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mission_alarm_hour', _alarmTime.hour);
    await prefs.setInt('mission_alarm_minute', _alarmTime.minute);
    await prefs.setBool('mission_alarm_enabled', _isAlarmEnabled);

    // Schedule (or cancel) the alarm notification.
    try {
      final svc = ref.read(notificationServiceProvider);
      await svc.scheduleMissionAlarm(
        hour: _alarmTime.hour,
        minute: _alarmTime.minute,
        selectedDays: List<bool>.from(_selectedDays),
        enabled: _isAlarmEnabled,
      );
    } catch (_) {}
  }

  void _startActiveMission() {
    setState(() {
      _isActiveMission = true;
      _currentStage = 1;
      _squatsDone = 0;
      _pushupsDone = 0;
      _missionCompleted = false;
      _isAlarmPlaying = true;
    });
    WakelockPlus.enable();
    _initAlarmAudio();
    _checkPermissionAndInitCamera();
  }

  Future<void> _stopAndExitMission() async {
    _isAlarmPlaying = false;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      _cameraController = null;
    } catch (_) {}
    WakelockPlus.disable();
    if (mounted) {
      setState(() {
        _isActiveMission = false;
        _isCameraInitialized = false;
      });
    }
  }

  Future<void> _initAlarmAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/alarm_loop.mp3');
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (_) {
      _startHapticLoop();
    }
  }

  void _startHapticLoop() {
    Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!_isAlarmPlaying || !mounted) {
        t.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  Future<void> _checkPermissionAndInitCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final frontIdx = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _cameraIndex = frontIdx != -1 ? frontIdx : 0;
        await _initCameraController();
      }
    }
  }

  Future<void> _initCameraController() async {
    final camera = _cameras[_cameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
      _startImageStream();
    } catch (e) {
      debugPrint('⚠️ MissionAlarm Camera init error: $e');
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastFrameTimeMs < _frameIntervalMs || _isProcessingFrame) return;

      _lastFrameTimeMs = now;
      _isProcessingFrame = true;

      try {
        final camera = _cameras[_cameraIndex];
        final poses = await _poseDetectorService.processCameraImage(
          image,
          camera,
          DeviceOrientation.portraitUp,
        );

        if (!mounted) return;
        setState(() => _poses = poses);

        if (poses.isNotEmpty && !_missionCompleted) {
          final pose = poses.first;

          if (_currentStage == 1) {
            final eval = _squatStrategy.evaluateFrame(pose, now);
            if (eval.validRepAdded || _squatStrategy.repCount > _squatsDone) {
              HapticFeedback.heavyImpact();
              setState(() {
                _squatsDone = _squatStrategy.repCount;
              });
              if (_squatsDone >= _targetSquats) {
                HapticFeedback.vibrate();
                setState(() {
                  _currentStage = 2;
                });
              }
            }
          } else if (_currentStage == 2) {
            final eval = _pushupStrategy.evaluateFrame(pose, now);
            if (eval.validRepAdded || _pushupStrategy.repCount > _pushupsDone) {
              HapticFeedback.heavyImpact();
              setState(() {
                _pushupsDone = _pushupStrategy.repCount;
              });
              if (_pushupsDone >= _targetPushups) {
                _completeMission();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Pose processing error: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  Future<void> _completeMission() async {
    if (_missionCompleted) return;
    _missionCompleted = true;
    _isAlarmPlaying = false;

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    HapticFeedback.heavyImpact();

    // Daily cooldown: only award points once per calendar day.
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey =
        'mission_alarm_reward_${today.year}_${today.month}_${today.day}';
    final alreadyRewarded = prefs.getBool(todayKey) ?? false;

    int awardedPts = 0;
    if (!alreadyRewarded) {
      final user = ref.read(userProfileProvider).asData?.value;
      if (user != null) {
        await ref.read(userRepositoryProvider).awardPoints(user.uid, 10);
        awardedPts = 10;
        await prefs.setBool(todayKey, true);
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF090B18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFFFB703), width: 1.5),
          ),
          title: const Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 28)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Missiya Bajarildi!',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            alreadyRewarded
                ? 'Tabriklaymiz! Ertalabki jismoniy mashqlar muvaffaqiyatli topshirildi! ⚡ (Bugungi mukofot allaqachon olindi)'
                : 'Tabriklaymiz! Ertalabki jismoniy mashqlar muvaffaqiyatli topshirildi va hisobingizga +$awardedPts PTS qo‘shildi! ⚡',
            style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _stopAndExitMission();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('AJOYIB 🚀', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _cameraController?.dispose();
    _poseDetectorService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isActiveMission) {
      return _buildActiveMissionView();
    }
    return _buildAlarmSettingsView();
  }

  // ---------------------------------------------------------------------------
  // 1. BUDILNIK SOZLAMALARI VA VAQT TANLASH EKRANI (SETTINGS VIEW)
  // ---------------------------------------------------------------------------
  Widget _buildAlarmSettingsView() {
    final dayNames = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('⏰', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Ertalabki Budilnik',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // TIME PICKER CARD
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1500), Color(0xFF100700)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFB703), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB703).withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Uyg‘onish Vaqti',
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Switch.adaptive(
                      value: _isAlarmEnabled,
                      activeColor: const Color(0xFFFFB703),
                      onChanged: (val) {
                        setState(() => _isAlarmEnabled = val);
                        _saveAlarmSettings();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _alarmTime,
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFFFFB703),
                            surface: Color(0xFF090B18),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() => _alarmTime = picked);
                      _saveAlarmSettings();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_alarmTime.hour.toString().padLeft(2, '0')}:${_alarmTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Color(0xFFFFB703),
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.edit_rounded, color: Color(0xFFFFB703), size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Days of week
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final isSel = _selectedDays[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDays[index] = !_selectedDays[index]);
                        _saveAlarmSettings();
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? const Color(0xFFFFB703) : Colors.white10,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          dayNames[index],
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // MISSION DETAILS CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF090B18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      'Majburiy Uyg‘onish Missiyasi',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Budilnik jiringlaganda kameraga qarab 20 ta Squat va 20 ta Push-up qilmaguncha ovozi to‘xtamaydi. Bu uyquni 1 daqiqada butunlay ochadi!',
                  style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                _buildMissionItem('🦵', '20 ta Squat (O‘tirib-turish)', 'Kamera orqali sun‘iy intellekt hisoblaydi'),
                const SizedBox(height: 10),
                _buildMissionItem('💪', '20 ta Push-up (Otjimaniya)', 'To‘g‘ri texnika bilan tana tushirilishi kerak'),
                const SizedBox(height: 10),
                _buildMissionItem('🎁', '+10 PTS Mukofot (Kuniga 1 marta)', 'Muvaffaqiyatli yakunlanganda balansingizga qo‘shiladi'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMissionItem(String emoji, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. FAOL BUDILNIK VA KAMERA MISSIYA EKRANI (ACTIVE CAMERA VIEW)
  // ---------------------------------------------------------------------------
  Widget _buildActiveMissionView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Stream
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? MediaQuery.of(context).size.width,
                  height: _cameraController!.value.previewSize?.width ?? MediaQuery.of(context).size.height,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB703)),
            ),

          // 2. Pose Skeleton
          if (_isCameraInitialized && _poses.isNotEmpty && _cameras.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: SkeletonPainter(
                  poses: _poses,
                  absoluteImageSize: Size(
                    _cameraController!.value.previewSize?.height ?? 720,
                    _cameraController!.value.previewSize?.width ?? 1280,
                  ),
                  rotation: InputImageRotation.rotation0deg,
                  isFrontCamera: _cameras[_cameraIndex].lensDirection == CameraLensDirection.front,
                ),
              ),
            ),

          // 3. Top Header Bar with Exit / Cancel Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFB703)),
                    ),
                    child: const Row(
                      children: [
                        Text('⏰ ', style: TextStyle(fontSize: 16)),
                        Text(
                          'MISSIYA BUDILNIGI',
                          style: TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF090B18),
                          title: const Text('Budilnikni to‘xtatish', style: TextStyle(color: Colors.white)),
                          content: const Text(
                            'Missiyani bekor qilib chiqmoqchimisiz?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Davom etish', style: TextStyle(color: Color(0xFFFFB703))),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _stopAndExitMission();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Chiqish', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('To‘xtatish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Mission Progress Card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _currentStage == 1 ? const Color(0xFFFFB703) : const Color(0xFF3A7FCC),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentStage == 1 ? '1-BOSQICH: SQUATS (O‘TIRIB-TURISH)' : '2-BOSQICH: PUSH-UPS (OTJIMANIYA)',
                    style: TextStyle(
                      color: _currentStage == 1 ? const Color(0xFFFFB703) : const Color(0xFF3A7FCC),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStage == 1
                        ? '$_squatsDone / $_targetSquats'
                        : '$_pushupsDone / $_targetPushups',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _currentStage == 1
                          ? (_squatsDone / _targetSquats).clamp(0.0, 1.0)
                          : (_pushupsDone / _targetPushups).clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentStage == 1 ? const Color(0xFFFFB703) : const Color(0xFF3A7FCC),
                      ),
                      minHeight: 8,
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
}
