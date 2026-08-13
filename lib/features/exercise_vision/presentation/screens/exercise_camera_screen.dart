import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../domain/services/exercise_strategy.dart';
import '../../domain/services/plank_strategy.dart';
import '../../domain/services/pose_detector_service.dart';
import '../../domain/services/pushup_strategy.dart';
import '../../domain/services/squat_strategy.dart';
import '../widgets/skeleton_painter.dart';

class ExerciseCameraScreen extends ConsumerStatefulWidget {
  const ExerciseCameraScreen({
    super.key,
    this.exerciseType = 'SQUAT',
    this.targetReps = 20,
  });

  final String exerciseType;
  final int targetReps;

  @override
  ConsumerState<ExerciseCameraScreen> createState() =>
      _ExerciseCameraScreenState();
}

class _ExerciseCameraScreenState extends ConsumerState<ExerciseCameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _permissionDenied = false;

  late final PoseDetectorService _poseDetectorService;
  late final ExerciseStrategy _exerciseStrategy;

  List<Pose> _poses = [];
  bool _isProcessingFrame = false;
  int _lastFrameTimeMs = 0;
  static const int _frameIntervalMs = 70; // ~14 FPS throttling to save battery

  bool _navigatingToSummary = false;
  BodyReadinessResult? _readiness;
  ExerciseEvaluationResult? _evalResult;

  int _elapsedSeconds = 0;
  DateTime? _startTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poseDetectorService = PoseDetectorService();

    final type = widget.exerciseType.toUpperCase();
    if (type == 'PUSH_UP' || type == 'PUSHUP') {
      _exerciseStrategy = PushUpStrategy();
    } else if (type == 'PLANK') {
      _exerciseStrategy = PlankStrategy();
    } else {
      _exerciseStrategy = SquatStrategy();
    }

    _enableWakelock();
    _checkPermissionAndInitCamera();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Wakelock error: $e');
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Wakelock disable error: $e');
    }
  }

  Future<void> _checkPermissionAndInitCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    } else {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
        });
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final frontIdx =
          _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cameraIndex = frontIdx != -1 ? frontIdx : 0;

      await _startCameraStream(_cameras[_cameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _startCameraStream(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    _startTime = DateTime.now();
    _startTimer();

    await _cameraController!.startImageStream((image) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_isProcessingFrame || (now - _lastFrameTimeMs) < _frameIntervalMs) {
        return;
      }
      _isProcessingFrame = true;
      _lastFrameTimeMs = now;

      try {
        final poses = await _poseDetectorService.processCameraImage(
          image,
          camera,
          DeviceOrientation.portraitUp,
        );

        if (mounted) {
          final pose = poses.isNotEmpty ? poses.first : null;
          final readiness = _poseDetectorService.checkExerciseReadiness(
            pose,
            exerciseType: widget.exerciseType,
          );
          final eval = pose != null
              ? _exerciseStrategy.evaluateFrame(pose, now)
              : null;

          if (eval != null && eval.validRepAdded) {
            HapticFeedback.heavyImpact();
            SystemSound.play(SystemSoundType.click);

            if (_exerciseStrategy.repCount >= widget.targetReps && !_navigatingToSummary) {
              _navigatingToSummary = true;
              Future.delayed(const Duration(milliseconds: 700), () {
                if (mounted) _finishSession();
              });
            }
          }

          setState(() {
            _poses = poses;
            _readiness = readiness;
            _evalResult = eval;
          });
        }
      } catch (e) {
        debugPrint('Frame processing error: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
        _permissionDenied = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && mounted) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds;
        });
      }
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    setState(() {
      _isCameraInitialized = false;
    });
    await _startCameraStream(_cameras[_cameraIndex]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetectorService.dispose();
    _disableWakelock();
    super.dispose();
  }

  void _finishSession() {
    final count = _exerciseStrategy.repCount;
    final duration = _elapsedSeconds;
    final isPlank = widget.exerciseType.toUpperCase() == 'PLANK';

    int points = 0;
    if (isPlank) {
      points = (count ~/ 5) + (count >= widget.targetReps ? 10 : 0);
    } else {
      points = count + (count >= widget.targetReps ? 10 : 0);
    }

    context.push(
      '/exercise/summary',
      extra: {
        'exerciseType': widget.exerciseType,
        'repCount': count,
        'durationSeconds': duration,
        'pointsEarned': points,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: const Color(0xFF07090E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_rounded,
                    color: Color(0xFFFF0055), size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Kamera ruxsati kerak',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mashq davomida bo\'g\'inlaringizni va takrorlarni aniqlash uchun kameraga ruxsat bering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => openAppSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F3FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text(
                    'Sozlamalarni ochish',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF07090E),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00F3FF)),
              SizedBox(height: 16),
              Text(
                'Kamera va pose detector yuklanmoqda...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final camera = _cameras[_cameraIndex];
    final isFront = camera.lensDirection == CameraLensDirection.front;
    final count = _exerciseStrategy.repCount;
    final feedback = _evalResult?.feedback ?? _readiness?.message ?? '';
    final isReady = _readiness?.ready ?? false;
    final isPlank = widget.exerciseType.toUpperCase() == 'PLANK';

    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    final timerText = '${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}';

    final plankM = count ~/ 60;
    final plankS = count % 60;
    final plankHoldText = '${plankM < 10 ? '0$plankM' : plankM}:${plankS < 10 ? '0$plankS' : plankS}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- CAMERA PREVIEW ---
            if (_cameraController!.value.previewSize != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),

            // --- SKELETON OVERLAY ---
            if (_poses.isNotEmpty &&
                _cameraController!.value.previewSize != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: SkeletonPainter(
                    poses: _poses,
                    absoluteImageSize: Size(
                      _cameraController!.value.previewSize!.height,
                      _cameraController!.value.previewSize!.width,
                    ),
                    rotation: InputImageRotation.rotation90deg,
                    isFrontCamera: isFront,
                  ),
                ),
              ),

            // --- TOP BAR (TIMER & BACK) ---
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xCC0A0E17),
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0A0E17),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x4400F3FF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Color(0xFF00F3FF), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          timerText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- READINESS & FEEDBACK BANNER ---
            Positioned(
              top: 72,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isReady
                      ? const Color(0xEE0C101A)
                      : const Color(0xEEEE3A50),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isReady
                        ? const Color(0xFF39FF14)
                        : const Color(0xFFFF0055),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReady ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: isReady ? const Color(0xFF39FF14) : Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feedback,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- REPETITION / PLANK TIMER COUNTER BADGE ---
            Positioned(
              bottom: 110,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xEE0A0E17),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isPlank ? const Color(0xFFFF9F00) : const Color(0xFF00F3FF),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPlank ? const Color(0x66FF9F00) : const Color(0x6600F3FF),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.exerciseType.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF8B9BB4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      isPlank ? plankHoldText : '$count',
                      style: TextStyle(
                        color: isPlank ? const Color(0xFFFF9F00) : const Color(0xFF00F3FF),
                        fontSize: isPlank ? 36 : 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      isPlank
                          ? '/ ${widget.targetReps}s maqsad'
                          : '/ ${widget.targetReps} maqsad',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- CONTROL BUTTONS ---
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _switchCamera,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xCC151A27),
                      side: const BorderSide(color: Color(0x4400F3FF)),
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.flip_camera_ios_rounded,
                        color: Color(0xFF00F3FF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _finishSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF39FF14),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 24),
                        label: const Text(
                          'TUGATISH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
