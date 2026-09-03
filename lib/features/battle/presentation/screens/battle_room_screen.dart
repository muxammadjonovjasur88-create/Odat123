import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/services/auth_repository.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../exercise_vision/domain/services/exercise_strategy.dart';
import '../../../exercise_vision/domain/services/pose_detector_service.dart';
import '../../../exercise_vision/domain/services/pushup_strategy.dart';
import '../../../exercise_vision/domain/services/squat_strategy.dart';
import '../../../exercise_vision/presentation/widgets/skeleton_painter.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../friends/data/friends_repository.dart';
import '../../data/battle_repository.dart';
import '../../domain/models/battle_match.dart';
import '../../domain/services/fast_frame_converter.dart';
import '../../domain/services/webrtc_signaling_service.dart';

class BattleRoomScreen extends ConsumerStatefulWidget {
  const BattleRoomScreen({super.key, required this.battleId});

  final String battleId;

  @override
  ConsumerState<BattleRoomScreen> createState() => _BattleRoomScreenState();
}

class _BattleRoomScreenState extends ConsumerState<BattleRoomScreen> {
  int _reps = 0;
  int _secondsLeft = 60;
  Timer? _timer;
  bool _isWorkoutActive = false;
  bool _hasSubmitted = false;
  bool _hasStartedTransition = false;
  int _lastSyncedScore = -1;

  // WebRTC P2P Video Call Service
  final WebRtcSignalingService _webrtcService = WebRtcSignalingService();
  bool _hasInitializedWebRtc = false;

  // AI Vision / Camera properties
  CameraController? _cameraController;
  PoseDetectorService? _poseDetectorService;
  ExerciseStrategy? _exerciseStrategy;
  final ValueNotifier<List<Pose>> _detectedPosesNotifier = ValueNotifier<List<Pose>>([]);
  final ValueNotifier<int> _repsNotifier = ValueNotifier<int>(0);
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  int _lastFrameTimeMs = 0;
  int _lastFrameBroadcastTimeMs = 0;

  // Countdown preparation animation (5 seconds)
  int _countdownNumber = 5;
  bool _showCountdown = false;
  Timer? _countdownTimer;

  // Quiz Battle state
  int _quizCurrentIndex = 0;
  int? _quizSelectedAnswer;
  bool _quizAnswerRevealed = false;
  int _quizCorrectAnswers = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initCameraForExercise(String exerciseType) async {
    if (exerciseType == 'finger_tap' || exerciseType == 'quiz') return;
    if (_cameraController != null) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _poseDetectorService = PoseDetectorService();
      if (exerciseType == 'pushup') {
        _exerciseStrategy = PushUpStrategy();
      } else if (exerciseType == 'squat') {
        _exerciseStrategy = SquatStrategy();
      }

      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _isCameraReady = true);

      _cameraController!.startImageStream((image) {
        _processCameraFrame(image, frontCam);
      });
    } catch (e) {
      debugPrint('Battle camera init error: $e');
    }
  }

  void _processCameraFrame(CameraImage image, CameraDescription cam) async {
    if ((!_isWorkoutActive && !_showCountdown) || _isProcessingFrame || _poseDetectorService == null || _exerciseStrategy == null) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameTimeMs < 25) return; // Real-time 35-40 FPS
    _lastFrameTimeMs = now;
    _isProcessingFrame = true;

    try {
      // 1. Broadcast live camera frame to opponent at ~4-5 FPS (every 220ms)
      if (now - _lastFrameBroadcastTimeMs > 220) {
        _lastFrameBroadcastTimeMs = now;
        final bmpBase64 = FastFrameConverter.convertCameraImageToBase64Bmp(
          image,
          isFrontCamera: cam.lensDirection == CameraLensDirection.front,
        );
        if (bmpBase64 != null && bmpBase64.isNotEmpty) {
          final uid = ref.read(authStateProvider).asData?.value?.uid;
          if (uid != null) {
            ref.read(battleRepositoryProvider).updatePlayerLiveFrame(
              battleId: widget.battleId,
              uid: uid,
              frameBase64: bmpBase64,
              reps: _reps,
            );
          }
        }
      }

      // 2. Process frame with ML Kit for pose detection
      final poses = await _poseDetectorService!.processCameraImage(
        image,
        cam,
        DeviceOrientation.portraitUp,
      );

      if (poses.isNotEmpty && mounted) {
        _detectedPosesNotifier.value = poses;

        if (_isWorkoutActive) {
          final pose = poses.first;
          final res = _exerciseStrategy!.evaluateFrame(pose, now);
          final repCount = _exerciseStrategy!.repCount;

          if (res.validRepAdded || repCount > _reps) {
            _reps = repCount;
            _repsNotifier.value = repCount;
            HapticFeedback.mediumImpact();
            _syncLiveScore();
          }
        }
      }
    } catch (e) {
      debugPrint('Pose processing frame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _initWebRtcForBattle(BattleMatch battle, bool isHost, String myUid) async {
    if (_hasInitializedWebRtc) return;
    _hasInitializedWebRtc = true;

    debugPrint('[Battle] 🔗 Initializing WebRTC... isHost=$isHost');

    try {
      await _webrtcService.initializeRenderers();
      // Give a small delay so ML Kit camera can settle first
      await Future.delayed(const Duration(milliseconds: 800));
      await _webrtcService.startLocalStream();

      if (isHost) {
        await _webrtcService.createRoom(
          battleId: widget.battleId,
          hostUid: myUid,
        );
        debugPrint('[Battle] 📡 WebRTC room created by host: ${widget.battleId}');
      } else {
        await _webrtcService.joinRoom(
          battleId: widget.battleId,
          opponentUid: myUid,
        );
        debugPrint('[Battle] 📡 WebRTC room joined by guest: ${widget.battleId}');
      }
    } catch (e) {
      debugPrint('[Battle] WebRTC initialization error: $e');
    }
  }

  Timer? _botSimulationTimer;
  int _simulatedBotReps = 0;

  void _checkStatusTransition(BattleMatch battle, bool isHost, String myUid) {
    // Start WebRTC early — when both players are in the lobby and ready
    if (!_hasInitializedWebRtc && battle.hostReady && battle.opponentReady) {
      _initWebRtcForBattle(battle, isHost, myUid);
    }

    if (battle.status == BattleStatus.active && !_hasStartedTransition && !_isWorkoutActive && !_hasSubmitted) {
      _hasStartedTransition = true;
      HapticFeedback.heavyImpact();
      final opponentName = isHost ? (battle.opponentName ?? 'Raqib') : battle.hostName;
      ref.read(notificationServiceProvider).showBattleStartNotification(
        opponentName: opponentName.isEmpty ? 'Raqib' : opponentName,
        battleId: widget.battleId,
      );

      // Ensure WebRTC is initialized if not already
      if (!_hasInitializedWebRtc) {
        _initWebRtcForBattle(battle, isHost, myUid);
      }
      _triggerMatchCountdown(battle);
    }
  }

  // 30-second lobby waiting timeout
  Timer? _lobby30sTimer;
  int _lobbySecondsRemaining = 30;
  bool _hasClaimedTimeoutWin = false;

  void _syncLobbyTimeout(BattleMatch battle, bool myReady, bool otherReady, String? uid) {
    if (uid == null || battle.status != BattleStatus.waiting) return;
    if (myReady && !otherReady) {
      if (_lobby30sTimer == null && !_hasClaimedTimeoutWin) {
        _lobbySecondsRemaining = 30;
        final otherName = battle.hostUid == uid ? (battle.opponentName ?? 'Raqib') : battle.hostName;
        try {
          ref.read(notificationServiceProvider).showBattleStartNotification(
            opponentName: 'extra.battle_1v1_wait'.tr(namedArgs: {'opponent': otherName}),
            battleId: widget.battleId,
          );
        } catch (_) {}

        _lobby30sTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
          if (!mounted || _hasClaimedTimeoutWin) {
            t.cancel();
            return;
          }
          if (_lobbySecondsRemaining > 1) {
            setState(() => _lobbySecondsRemaining--);
          } else {
            t.cancel();
            _hasClaimedTimeoutWin = true;
            HapticFeedback.heavyImpact();
            try {
              await ref.read(battleRepositoryProvider).claimTimeoutWin(
                    battleId: widget.battleId,
                    winnerUid: uid,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF3A7FCC),
                    duration: const Duration(seconds: 5),
                    content: Text(
                      '🎉 Raqib 30 soniya ichida tayyor bo‘lmadi! Texnik g‘alaba: +${battle.winnerPrize} PTS hisobingizga qo‘shildi!',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
            } catch (_) {}
          }
        });
      }
    } else {
      _lobby30sTimer?.cancel();
      _lobby30sTimer = null;
    }
  }

  /// 5-second preparation countdown giving users time to position phone and get into workout stance
  void _triggerMatchCountdown(BattleMatch battle) {
    _lobby30sTimer?.cancel();
    _lobby30sTimer = null;
    _countdownTimer?.cancel();
    setState(() {
      _showCountdown = true;
      _countdownNumber = 5;
    });

    // Start camera immediately so players can see their position
    _initCameraForExercise(battle.exerciseType);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (cdTimer) {
      if (!mounted) {
        cdTimer.cancel();
        return;
      }

      if (_countdownNumber > 1) {
        HapticFeedback.mediumImpact();
        setState(() => _countdownNumber--);
      } else {
        cdTimer.cancel();
        setState(() {
          _showCountdown = false;
          _countdownNumber = 0;
        });
        final matchDuration = battle.durationSeconds > 0
            ? battle.durationSeconds
            : (battle.exerciseType == 'finger_tap' ? 30 : 60);
        _startTimer(matchDuration, battle);
      }
    });
  }

  @override
  void dispose() {
    _lobby30sTimer?.cancel();
    _countdownTimer?.cancel();
    _timer?.cancel();
    _botSimulationTimer?.cancel();
    _cameraController?.dispose();
    _poseDetectorService?.dispose();
    _detectedPosesNotifier.dispose();
    _repsNotifier.dispose();
    _webrtcService.dispose();
    super.dispose();
  }

  void _startTimer(int totalSeconds, BattleMatch battle) {
    setState(() {
      _isWorkoutActive = true;
      _secondsLeft = totalSeconds;
      _reps = 0;
      _repsNotifier.value = 0;
      _lastSyncedScore = -1;
    });

    // Start Bot Simulation if fighting against an AI bot
    final isBot = battle.opponentUid != null && battle.opponentUid!.startsWith('bot_');
    if (isBot) {
      _simulatedBotReps = 0;
      _botSimulationTimer?.cancel();
      _botSimulationTimer = Timer.periodic(const Duration(milliseconds: 2750), (bTimer) {
        if (!_isWorkoutActive || !mounted) {
          bTimer.cancel();
          return;
        }
        _simulatedBotReps++;
        ref.read(battleRepositoryProvider).updateBotScore(widget.battleId, _simulatedBotReps);
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 5) {
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
        }
        _syncLiveScore();
      } else {
        _timer?.cancel();
        _botSimulationTimer?.cancel();
        HapticFeedback.vibrate();
        _finishWorkout();
      }
    });
  }

  void _syncLiveScore() {
    if (_reps == _lastSyncedScore) return;
    _lastSyncedScore = _reps;
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid != null) {
      ref.read(battleRepositoryProvider).submitScore(
        battleId: widget.battleId,
        uid: uid,
        score: _reps,
      );
    }
  }

  void _incrementRep(String exerciseType) {
    if (!_isWorkoutActive) return;
    if (exerciseType != 'finger_tap') return; // ONLY finger tap allows screen tapping!
    HapticFeedback.lightImpact();
    _reps++;
    _repsNotifier.value = _reps;
    _syncLiveScore();
  }

  Future<void> _finishWorkout() async {
    setState(() {
      _isWorkoutActive = false;
      _hasSubmitted = true;
    });
    HapticFeedback.heavyImpact();

    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid != null) {
      await ref.read(battleRepositoryProvider).submitScore(
        battleId: widget.battleId,
        uid: uid,
        score: _reps,
        isFinal: true,
      );
    }
  }

  void _confirmCancelBattle(BattleMatch battle, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFF0055), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF0055)),
            const SizedBox(width: 8),
            Text('battle.cancel_room_btn'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'battle.delete_room_confirm'.tr(namedArgs: {'wager': battle.wagerPoints.toString()}),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.back'.tr(), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(battleRepositoryProvider).cancelBattle(
                      battleId: widget.battleId,
                      uid: uid,
                    );
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF3A7FCC),
                      content: Text('battle.room_deleted_refunded'.tr(namedArgs: {'wager': battle.wagerPoints.toString()})),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('$e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0055),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('common.cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    final battleAsync = ref.watch(singleBattleStreamProvider(widget.battleId));

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text('battle.arena_banner_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [
          battleAsync.maybeWhen(
            data: (battle) {
              if (battle != null && battle.status == BattleStatus.waiting && battle.hostUid == uid) {
                return IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4D6D)),
                  tooltip: 'Xonani o‘chirish',
                  onPressed: () => _confirmCancelBattle(battle, uid!),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: battleAsync.when(
        data: (battle) {
          if (battle == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 48),
                  const SizedBox(height: 12),
                  Text('battle.room_not_found'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055), foregroundColor: Colors.white),
                    child: Text('battle.go_back'.tr()),
                  ),
                ],
              ),
            );
          }

          final isHost = battle.hostUid == uid;
          _checkStatusTransition(battle, isHost, uid ?? '');

          return Stack(
            children: [
              // 1. WAITING & READY LOBBY
              if (battle.status == BattleStatus.waiting)
                _buildLobbyState(battle, uid, isHost)
              // 2. FINISHED STATE
              else if (battle.status == BattleStatus.finished)
                _buildFinishedState(battle, uid)
              // 3. ACTIVE LIVE MATCH
              else
                _buildActiveMatch(battle, isHost),

              // Countdown Preparation 5..4..3..2..1 Overlay
              if (_showCountdown)
                Container(
                  color: Colors.black.withValues(alpha: 0.92),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0x3300FF88),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF3A7FCC)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'RAQIB BILAN JANG BOSHLANMOQDA!',
                                  style: TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x334AADDC),
                              border: Border.all(color: const Color(0xFF4AADDC), width: 3.5),
                              boxShadow: const [BoxShadow(color: Color(0x884AADDC), blurRadius: 30)],
                            ),
                            child: Center(
                              child: Text(
                                '$_countdownNumber',
                                style: const TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '📱 Telefonni qulay joylashtiring!',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            battle.exerciseType == 'pushup'
                                ? '🏋️ Push-up (Otjimaniye) holatini egallang!'
                                : (battle.exerciseType == 'squat'
                                    ? '🏋️ Squat (O‘tirib-turish) holatiga o‘ting!'
                                    : '⚡ Ekranga tez-tez bosishga tayyorlaning!'),
                            style: const TextStyle(color: Color(0xFFFFB703), fontSize: 14, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Kamera va AI tayyorlanmoqda...',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: FlowaLoading()),
        error: (err, _) => Center(child: Text('Xatolik: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  /// 1. Interactive Lobby (Both players press Ready, no auto timeout)
  Widget _buildLobbyState(BattleMatch battle, String? uid, bool isHost) {
    final hasOpponent = battle.opponentUid != null && battle.opponentUid!.isNotEmpty;
    final myReady = isHost ? battle.hostReady : battle.opponentReady;
    final otherReady = isHost ? battle.opponentReady : battle.hostReady;
    final opponentName = isHost ? (battle.opponentName ?? 'Raqib kutilmoqda...') : battle.hostName;
    final opponentAvatar = isHost ? (battle.opponentAvatar ?? '0') : battle.hostAvatar;
    final opponentPhotoUrl = isHost ? battle.opponentPhotoUrl : battle.hostPhotoUrl;
    final opponentPhotoBase64 = isHost ? battle.opponentPhotoBase64 : battle.hostPhotoBase64;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Match Wager & Exercise Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF090B18), Color(0xFF090B18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x444AADDC)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      battle.exerciseDisplayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mukofot: +${battle.winnerPrize} ⚡ 🏆',
                      style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFB703),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFB703)),
                  ),
                  child: Text(
                    '${battle.wagerPoints} ⚡ Garov',
                    style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Match Info Guide Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF111726),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x334AADDC)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_kabaddi_rounded,
                  color: Color(0xFF4AADDC),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasOpponent
                        ? 'Ikkala ishtirokchi "TAYYORMAN" tugmasini bosgandan so‘ng 5 soniya tayyorgarlik bilan jang boshlanadi!'
                        : 'Raqib qo‘shilishi kutilmoqda. Do‘stingiz kirishi bilan ikkalangiz tayyor bo‘lib boshlaysiz!',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // VS Player Cards
          Row(
            children: [
              // Host Card
              Expanded(
                child: _buildLobbyPlayerCard(
                  name: battle.hostName,
                  avatar: battle.hostAvatar,
                  photoUrl: battle.hostPhotoUrl,
                  photoBase64: battle.hostPhotoBase64,
                  isMe: isHost,
                  isReady: battle.hostReady,
                  isHost: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('VS', style: TextStyle(color: Color(0xFFFF0055), fontSize: 24, fontWeight: FontWeight.w900)),
              ),
              // Opponent Card
              Expanded(
                child: hasOpponent
                    ? _buildLobbyPlayerCard(
                        name: battle.opponentName ?? 'Raqib',
                        avatar: battle.opponentAvatar ?? '0',
                        photoUrl: battle.opponentPhotoUrl,
                        photoBase64: battle.opponentPhotoBase64,
                        isMe: !isHost,
                        isReady: battle.opponentReady,
                        isHost: false,
                      )
                    : Container(
                        height: 160,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090B18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x22FFFFFF)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.hourglass_top_rounded, color: Colors.white24, size: 36),
                            const SizedBox(height: 8),
                            Text('battle.waiting_opponent'.tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action Button: "Jangga Tayyorman / Boshlash"
          if (!myReady)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (uid != null) {
                    HapticFeedback.mediumImpact();
                    await ref.read(battleRepositoryProvider).setPlayerReady(
                      battleId: widget.battleId,
                      uid: uid,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A7FCC),
                  foregroundColor: Colors.black,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 24),
                label: const Text(
                  'TAYYORMAN / BOSHLASH 🔥',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            )
          else ...[
            Builder(
              builder: (context) {
                _syncLobbyTimeout(battle, myReady, otherReady, uid);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x224AADDC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3A7FCC)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasOpponent && !otherReady
                                  ? 'Siz tayyorsiz! Raqib "Tayyorman" deb bosishi kutilmoqda...'
                                  : (hasOpponent ? 'Har ikkalangiz tayyorsiz! Jang boshlanmoqda...' : 'Siz tayyorsiz! Raqib qo‘shilishi kutilmoqda...'),
                              style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.bold, fontSize: 12.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      if (hasOpponent && !otherReady) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x33FFB703),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFB703)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined, color: Color(0xFFFFB703), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '⏱️ Raqib kutilmoqda: ${_lobbySecondsRemaining}s',
                                style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '30 soniyada tayyor bo‘lmasa sizga g‘alaba (+${battle.winnerPrize} PTS) beriladi!',
                          style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],

          if (isHost) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => _confirmCancelBattle(battle, uid!),
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4D6D), size: 18),
              label: Text('battle.cancel_room_refund'.tr(), style: const TextStyle(color: Color(0xFFFF4D6D), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLobbyPlayerCard({
    required String name,
    required String avatar,
    String? photoUrl,
    String? photoBase64,
    required bool isMe,
    required bool isReady,
    required bool isHost,
  }) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isReady ? const Color(0xFF3A7FCC) : const Color(0x334AADDC), width: isReady ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarCircle(
            avatarKey: avatar,
            photoUrl: photoUrl,
            photoBase64: photoBase64,
            size: 48,
          ),
          const SizedBox(height: 6),
          Text(
            isMe ? '$name (SIZ)' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isReady ? const Color(0xFF3A7FCC) : const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isReady ? '✅ TAYYOR' : '⏳ KUTILMOQDA',
              style: TextStyle(
                color: isReady ? Colors.black : Colors.white60,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Active Match View (Full-Screen AI Vision Camera + Dual Fighter HP Bars)
  Widget _buildActiveMatch(BattleMatch battle, bool isHost) {
    final myName = isHost ? battle.hostName : (battle.opponentName ?? 'Siz');
    final myAvatar = isHost ? battle.hostAvatar : (battle.opponentAvatar ?? '0');
    final myPhotoUrl = isHost ? battle.hostPhotoUrl : battle.opponentPhotoUrl;
    final myPhotoBase64 = isHost ? battle.hostPhotoBase64 : battle.opponentPhotoBase64;

    final myScore = isHost ? battle.hostScore : battle.opponentScore;
    final opponentName = isHost ? (battle.opponentName ?? 'Raqib') : battle.hostName;
    final opponentAvatar = isHost ? (battle.opponentAvatar ?? '0') : battle.hostAvatar;
    final opponentPhotoUrl = isHost ? battle.opponentPhotoUrl : battle.hostPhotoUrl;
    final opponentPhotoBase64 = isHost ? battle.opponentPhotoBase64 : battle.hostPhotoBase64;
    final opponentScore = isHost ? battle.opponentScore : battle.hostScore;
    final isFingerTap = battle.exerciseType == 'finger_tap';
    final isQuiz = battle.exerciseType == 'quiz';

    return Stack(
      children: [
        // 1. FULL-SCREEN BACKGROUND CAMERA & AI SKELETON (or Tap/Quiz Area)
        Positioned.fill(
          child: isQuiz
              ? _buildQuizBattleArea(battle, myScore, isHost)
              : isFingerTap
              ? _buildFingerTapBattleArea()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full Screen Camera Viewfinder
                    if (_isCameraReady && _cameraController != null && _cameraController!.value.isInitialized)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 400,
                          height: _cameraController!.value.previewSize?.width ?? 300,
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFF080D18),
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF4AADDC)),
                        ),
                      ),

                    // Live AI Skelet Pose Overlay
                    if (_isCameraReady && _cameraController != null)
                      ValueListenableBuilder<List<Pose>>(
                        valueListenable: _detectedPosesNotifier,
                        builder: (context, poses, _) {
                          final previewSize = _cameraController!.value.previewSize;
                          final portraitSize = previewSize != null
                              ? Size(previewSize.height, previewSize.width)
                              : const Size(480, 640);
                          return CustomPaint(
                            painter: SkeletonPainter(
                              poses: poses,
                              absoluteImageSize: portraitSize,
                              rotation: InputImageRotation.rotation0deg,
                              isFrontCamera: true,
                            ),
                          );
                        },
                      ),

                    // Subtle Vignette Gradient
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // 2. TOP FIGHTING GAME HP & SCORE HUD
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xEE0A0F1D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x555BC8FA), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x334AADDC), blurRadius: 16),
                ],
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: _repsNotifier,
                builder: (context, myReps, _) {
                  final myHp = (100 - (opponentScore * 4)).clamp(10, 100);
                  final opponentHp = (100 - (myReps * 4)).clamp(10, 100);
                  final totalReps = myReps + opponentScore;
                  final leadRatio = totalReps == 0 ? 0.5 : (myReps / totalReps).clamp(0.05, 0.95);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dual Fighter Heads + Timer
                      Row(
                        children: [
                          // Left: You
                          Expanded(
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    AvatarCircle(
                                      avatarKey: myAvatar,
                                      photoUrl: myPhotoUrl,
                                      photoBase64: myPhotoBase64,
                                      size: 40,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF3A7FCC),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.flash_on_rounded, color: Colors.black, size: 9),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        myName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFF4AADDC), fontWeight: FontWeight.w900, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$myReps PUSH-UP',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Center: Timer Circle
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF0055), Color(0xFFFFB703)]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(color: Color(0x66FF0055), blurRadius: 10)],
                            ),
                            child: Text(
                              '$_secondsLeft s',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),

                          // Right: Opponent
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        opponentName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFFFF4D6D), fontWeight: FontWeight.w900, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$opponentScore PUSH-UP',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Stack(
                                  children: [
                                    AvatarCircle(
                                      avatarKey: opponentAvatar,
                                      photoUrl: opponentPhotoUrl,
                                      photoBase64: opponentPhotoBase64,
                                      size: 40,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF0055),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.sports_kabaddi_rounded, color: Colors.white, size: 9),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Dual HP Bars (Green vs Red)
                      Row(
                        children: [
                          // My HP
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: myHp / 100.0,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3A7FCC)),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Opponent HP
                          Expanded(
                            child: Transform.flip(
                              flipX: true,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: opponentHp / 100.0,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0055)),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Tug-of-war Dynamic Lead Line
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: leadRatio,
                          backgroundColor: const Color(0xFFFF0055),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4AADDC)),
                          minHeight: 3.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // 3. BOTTOM FLOATING AI VISION ACTIVE CHIP
        Positioned(
          bottom: 24,
          left: 20,
          right: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xEE0A0F1D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A7FCC), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x5500FF88), blurRadius: 14),
                ],
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: _repsNotifier,
                builder: (context, reps, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF3A7FCC), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'AI VISION SKELET: FAOL 🟢 · $reps REPS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        // 4. FLOATING MIC TOGGLE BUTTON
        Positioned(
          top: 90,
          right: 20,
          child: SafeArea(
            child: ValueListenableBuilder<bool>(
              valueListenable: _webrtcService.isMuted,
              builder: (context, isMuted, _) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _webrtcService.toggleMute();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMuted ? const Color(0xCCFF0055) : const Color(0xCC5BC8FA),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isMuted ? const Color(0x66FF0055) : const Color(0x664AADDC),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: isMuted ? Colors.white : Colors.black,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 1. Finger Tap Workout Area
  Widget _buildFingerTapBattleArea() {
    return Center(
      child: GestureDetector(
        onTap: () => _incrementRep('finger_tap'),
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0x334AADDC), Color(0xFF080C14)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF4AADDC), width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: _repsNotifier,
                  builder: (_, reps, __) => Text('$reps', style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4AADDC), Color(0xFF0088CC)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x664AADDC), blurRadius: 20)],
                  ),
                  child: Text('battle.tap_btn'.tr(), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Quiz Battle Area — 5 questions, each correct answer = 1 point
  Widget _buildQuizBattleArea(BattleMatch battle, int myScore, bool isHost) {
    final questions = battle.questions;
    if (questions.isEmpty) {
      return const Center(
        child: Text(
          '⚠️ Savollar yuklanmadi.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    final isFinished = _quizCurrentIndex >= questions.length;

    if (isFinished) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              "Siz $_quizCorrectAnswers/${questions.length} ta to'g'ri javob berdingiz!",
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final q = questions[_quizCurrentIndex];
    final questionText = q['questionText'] as String? ?? '';
    final options = (q['options'] as List<dynamic>? ?? []).map((o) => o.toString()).toList();
    final correctIndex = (q['correctIndex'] as num?)?.toInt() ?? 0;

    return Container(
      color: const Color(0xFF080C14),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress bar
              Row(
                children: [
                  Text(
                    'Savol ${_quizCurrentIndex + 1}/${questions.length}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_quizCurrentIndex + 1) / questions.length,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4AADDC)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$myScore ✅',
                    style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Question card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF090B18), Color(0xFF0A0F1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x555BC8FA), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x224AADDC), blurRadius: 20)],
                ),
                child: Text(
                  questionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              // Answer options
              ...options.asMap().entries.map((entry) {
                final idx = entry.key;
                final optionText = entry.value;
                final isSelected = _quizSelectedAnswer == idx;
                final isCorrect = idx == correctIndex;
                Color bgColor = const Color(0xFF090B18);
                Color borderColor = const Color(0x33FFFFFF);
                if (_quizAnswerRevealed) {
                  if (isCorrect) {
                    bgColor = const Color(0x224AADDC);
                    borderColor = const Color(0xFF3A7FCC);
                  } else if (isSelected && !isCorrect) {
                    bgColor = const Color(0x33FF0055);
                    borderColor = const Color(0xFFFF0055);
                  }
                } else if (isSelected) {
                  bgColor = const Color(0x224AADDC);
                  borderColor = const Color(0xFF4AADDC);
                }
                return GestureDetector(
                  onTap: _quizAnswerRevealed ? null : () async {
                    setState(() {
                      _quizSelectedAnswer = idx;
                      _quizAnswerRevealed = true;
                      if (isCorrect) _quizCorrectAnswers++;
                    });

                    // Sync score to Firestore
                    final uid = ref.read(authStateProvider).asData?.value?.uid ?? '';
                    final isLastQuestion = _quizCurrentIndex >= questions.length - 1;
                    await ref.read(battleRepositoryProvider).submitScore(
                      battleId: widget.battleId,
                      uid: uid,
                      score: _quizCorrectAnswers,
                      isFinal: isLastQuestion,
                    );

                    // Move to next question after delay
                    await Future.delayed(const Duration(milliseconds: 1200));
                    if (mounted) {
                      setState(() {
                        _quizCurrentIndex++;
                        _quizSelectedAnswer = null;
                        _quizAnswerRevealed = false;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: borderColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + idx), // A, B, C, D
                              style: TextStyle(color: borderColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            optionText,
                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                          ),
                        ),
                        if (_quizAnswerRevealed && isCorrect)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 20),
                        if (_quizAnswerRevealed && isSelected && !isCorrect)
                          const Icon(Icons.cancel_rounded, color: Color(0xFFFF0055), size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// 2. Split-Screen AI Vision Camera Workout Area (Push-up / Squats)

  Widget _buildSplitScreenCameraArea(BattleMatch battle, String opponentName, String opponentAvatar, int opponentScore) {
    final myUid = ref.read(authStateProvider).asData?.value?.uid ?? '';
    final opponentUid = battle.hostUid == myUid ? (battle.opponentUid ?? '') : battle.hostUid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          // Top Half: Opponent live Video Call Stream Viewport
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF090B18), Color(0xFF0A0F1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x88FF0055), width: 1.8),
                boxShadow: const [
                  BoxShadow(color: Color(0x33FF0055), blurRadius: 18, spreadRadius: 1),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: StreamBuilder<Map<String, dynamic>?>(
                  stream: ref.read(battleRepositoryProvider).watchPlayerLiveFrame(
                    battleId: widget.battleId,
                    opponentUid: opponentUid,
                  ),
                  builder: (context, frameSnap) {
                    final liveFrameBase64 = frameSnap.data?['frame'] as String?;
                    final hasLiveFrame = liveFrameBase64 != null && liveFrameBase64.isNotEmpty;

                    return ValueListenableBuilder<bool>(
                      valueListenable: _webrtcService.isRemoteVideoAvailable,
                      builder: (context, isRemoteVideoOn, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. WebRTC Live Video Stream
                            if (isRemoteVideoOn) ...[
                              Positioned.fill(
                                child: RTCVideoView(
                                  _webrtcService.remoteRenderer,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                  mirror: false,
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0x55000000), Colors.transparent, Color(0x77000000)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ]
                            // 2. High-speed Live Camera Mirror Stream
                            else if (hasLiveFrame) ...[
                              Positioned.fill(
                                child: Image.memory(
                                  base64Decode(liveFrameBase64),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0x44000000), Colors.transparent, Color(0x66000000)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ]
                            else ...[
                              // Video Call Mesh/Scanline Background when waiting for stream
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.15,
                                  child: CustomPaint(
                                    painter: SkeletonPainter(
                                      poses: const [],
                                      absoluteImageSize: const Size(400, 300),
                                      rotation: InputImageRotation.rotation0deg,
                                      isFrontCamera: true,
                                    ),
                                  ),
                                ),
                              ),
                              // Center avatar & pulsing effect ONLY when no video stream
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF0055), Color(0xFFFFB703)],
                                          ),
                                          boxShadow: const [
                                            BoxShadow(color: Color(0x88FF0055), blurRadius: 20, spreadRadius: 3),
                                          ],
                                        ),
                                        child: AvatarCircle(avatarKey: opponentAvatar, size: 64),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF3A7FCC),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.videocam_rounded, color: Colors.black, size: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    opponentName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Jonli video ulanmoqda...',
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],

                        // Floating Real-Time Score Badge (Bottom Center)
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xDD0C1220),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFF0055), width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Color(0x66FF0055), blurRadius: 12),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AvatarCircle(avatarKey: opponentAvatar, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  opponentName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                                ),
                                const SizedBox(width: 8),
                                const Text('🦾', style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 4),
                                Text(
                                  '$opponentScore ${battle.exerciseType == "pushup" ? "PUSH-UP" : "SQUAT"}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFB703),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Top Left: Opponent Video Call Badge & Latency
                        Positioned(
                          top: 10,
                          left: 10,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _webrtcService.isConnected,
                            builder: (context, isConnected, _) {
                              final active = isRemoteVideoOn || hasLiveFrame || isConnected;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC000000),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: active ? const Color(0xFF3A7FCC) : const Color(0x33FFFFFF)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.videocam_rounded,
                                      color: active ? const Color(0xFF3A7FCC) : const Color(0xFFFFB703),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      active ? '🟢 JONLI VIDEO' : '🟡 ULANMOQDA...',
                                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // Top Right: Live Broadcasting Indicator
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0055),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Color(0x88FF0055), blurRadius: 8)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fiber_manual_record_rounded, color: Colors.white, size: 10),
                                const SizedBox(width: 4),
                                Text('battle.video_mode'.tr(), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),

          // Bottom Half: Live AI Vision Camera Viewfinder with SkeletonPainter & Rep Counter
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6, bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF090B18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4AADDC), width: 2),
                boxShadow: const [BoxShadow(color: Color(0x334AADDC), blurRadius: 16)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Camera viewfinder with live AI skeleton tracking
                    if (_isCameraReady && _cameraController != null && _cameraController!.value.isInitialized)
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? 400,
                            height: _cameraController!.value.previewSize?.width ?? 300,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      )
                    else
                      ValueListenableBuilder<bool>(
                        valueListenable: _webrtcService.isLocalCameraReady,
                        builder: (context, ready, _) {
                          if (ready) {
                            return SizedBox.expand(
                              child: RTCVideoView(
                                _webrtcService.localRenderer,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                mirror: true,
                              ),
                            );
                          }
                          return const Center(
                            child: Icon(Icons.videocam_rounded, color: Color(0xFF4AADDC), size: 48),
                          );
                        },
                      ),

                    // Skeleton overlay — correctly sized with swapped w/h for portrait
                    if (_isCameraReady && _cameraController != null)
                      SizedBox.expand(
                        child: ValueListenableBuilder<List<Pose>>(
                          valueListenable: _detectedPosesNotifier,
                          builder: (context, poses, _) {
                            final previewSize = _cameraController!.value.previewSize;
                            final portraitSize = previewSize != null
                                ? Size(previewSize.height, previewSize.width)
                                : const Size(480, 640);
                            return CustomPaint(
                              painter: SkeletonPainter(
                                poses: poses,
                                absoluteImageSize: portraitSize,
                                rotation: InputImageRotation.rotation0deg,
                                isFrontCamera: true,
                              ),
                            );
                          },
                        ),
                      ),

                    // Floating Sleek Rep Counter Badge (Bottom Center)
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xEE0C1220),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF4AADDC), width: 1.8),
                          boxShadow: const [BoxShadow(color: Color(0x664AADDC), blurRadius: 14)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fitness_center_rounded, color: Color(0xFF4AADDC), size: 18),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<int>(
                              valueListenable: _repsNotifier,
                              builder: (_, reps, __) => Text(
                                '$reps REPS',
                                style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Left Badge: AI Vision Active
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF3A7FCC), borderRadius: BorderRadius.circular(8)),
                        child: Text('battle.ai_vision_you'.tr(), style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedState(BattleMatch battle, String? uid) {
    final isWinner = battle.winnerUid == uid;
    final isDraw = battle.winnerUid == null;

    final resultTitle = isWinner
        ? '🎉 SIZ G‘OLIBSIZ!'
        : (isDraw ? '🤝 DURANG BO‘LDI' : '💔 SIZ MAG‘LUBSİZ');

    final resultDesc = isWinner
        ? 'G‘alaba qozondingiz! +${battle.winnerPrize} PTS yutib oldingiz! 🏆'
        : (isDraw
            ? 'Har ikkala ishtirokchiga tikilgan ${battle.wagerPoints} PTS to‘liq qaytarildi.'
            : 'Afsuski, ushbu jangda mag‘lub bo‘ldingiz (-${battle.wagerPoints} PTS). Keyingi safar albatta g‘alaba qozonasiz!');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isWinner ? const Color(0xFF3A7FCC) : (isDraw ? const Color(0xFF4AADDC) : const Color(0xFFFF0055)),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isWinner ? const Color(0xFF3A7FCC) : const Color(0xFFFF0055)).withValues(alpha: 0.25),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWinner ? Icons.emoji_events_rounded : (isDraw ? Icons.handshake_rounded : Icons.sentiment_dissatisfied_rounded),
                color: isWinner ? const Color(0xFFFFB703) : (isDraw ? const Color(0xFF4AADDC) : const Color(0xFFFF0055)),
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(
                resultTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isWinner ? const Color(0xFF3A7FCC) : (isDraw ? Colors.white : const Color(0xFFFF0055)),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                resultDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB0C4DE), fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2338),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Siz: ${battle.hostUid == uid ? battle.hostScore : battle.opponentScore}  VS  Raqib: ${battle.hostUid == uid ? battle.opponentScore : battle.hostScore}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              // Friend Request Button
              if (battle.opponentUid != null && !battle.opponentUid!.startsWith('bot_') && battle.opponentUid != uid) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    try {
                      final myUid = ref.read(authStateProvider).asData?.value?.uid;
                      final targetUid = battle.hostUid == uid ? battle.opponentUid : battle.hostUid;
                      if (myUid != null && targetUid != null) {
                        await ref.read(friendsRepositoryProvider).addFriend(myUid, targetUid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF3A7FCC),
                              behavior: SnackBarBehavior.floating,
                              content: Text('battle.friend_request_sent'.tr()),
                            ),
                          );
                        }
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF3A7FCC), size: 18),
                  label: const Text(
                    '🤝 DO‘STLIK TAKLIF QILISH',
                    style: TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3A7FCC), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(battleRepositoryProvider).cleanupFinishedBattle(battle.id);
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4AADDC),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('battle.understood_ok'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
