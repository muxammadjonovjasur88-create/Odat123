import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

@immutable
class DetailedBodyChecklist {
  const DetailedBodyChecklist({
    required this.head,
    required this.shoulders,
    required this.elbows,
    required this.hands,
    required this.hips,
    required this.knees,
    required this.feet,
  });

  final bool head;
  final bool shoulders;
  final bool elbows;
  final bool hands;
  final bool hips;
  final bool knees;
  final bool feet;
}

@immutable
class BodyReadinessResult {
  const BodyReadinessResult({
    required this.ready,
    required this.message,
    required this.missingPartsUzbek,
    required this.checklist,
    required this.confidence,
  });

  final bool ready;
  final String message;
  final List<String> missingPartsUzbek;
  final DetailedBodyChecklist checklist;
  final int confidence;
}

/// Service wrapping Google ML Kit Pose Detector and converting CameraImage frames.
class PoseDetectorService {
  PoseDetectorService() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  late final PoseDetector _detector;

  Future<List<Pose>> processCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    final inputImage = _inputImageFromCameraImage(image, camera, deviceOrientation);
    if (inputImage == null) return [];
    return await _detector.processImage(inputImage);
  }

  /// Checks if body parts required for an exercise (SQUAT, PUSH_UP, PLANK) are visible in frame.
  BodyReadinessResult checkExerciseReadiness(
    Pose? pose, {
    String exerciseType = 'SQUAT',
  }) {
    if (pose == null || pose.landmarks.isEmpty) {
      const emptyChecklist = DetailedBodyChecklist(
        head: false,
        shoulders: false,
        elbows: false,
        hands: false,
        hips: false,
        knees: false,
        feet: false,
      );
      return const BodyReadinessResult(
        ready: false,
        message: 'Kameraga to\'liq ko\'rining. Tana ko\'rinmayapti!',
        missingPartsUzbek: ['Tana'],
        checklist: emptyChecklist,
        confidence: 0,
      );
    }

    final lm = pose.landmarks;
    const minVis = 0.3;

    final hasHead = (lm[PoseLandmarkType.nose]?.likelihood ?? 0) > minVis ||
        ((lm[PoseLandmarkType.leftEye]?.likelihood ?? 0) > minVis &&
            (lm[PoseLandmarkType.rightEye]?.likelihood ?? 0) > minVis);

    final hasShoulders = (lm[PoseLandmarkType.leftShoulder]?.likelihood ?? 0) > minVis ||
        (lm[PoseLandmarkType.rightShoulder]?.likelihood ?? 0) > minVis;

    final hasElbows = (lm[PoseLandmarkType.leftElbow]?.likelihood ?? 0) > minVis ||
        (lm[PoseLandmarkType.rightElbow]?.likelihood ?? 0) > minVis;

    final hasHands = (lm[PoseLandmarkType.leftWrist]?.likelihood ?? 0) > minVis ||
        (lm[PoseLandmarkType.rightWrist]?.likelihood ?? 0) > minVis;

    final hasHips = (lm[PoseLandmarkType.leftHip]?.likelihood ?? 0) > minVis ||
        (lm[PoseLandmarkType.rightHip]?.likelihood ?? 0) > minVis;

    final hasKnees = (lm[PoseLandmarkType.leftKnee]?.likelihood ?? 0) > minVis ||
        (lm[PoseLandmarkType.rightKnee]?.likelihood ?? 0) > minVis;

    final hasFeet = (lm[PoseLandmarkType.leftAnkle]?.likelihood ?? 0) > minVis ||
        (lm[PoseLandmarkType.rightAnkle]?.likelihood ?? 0) > minVis;

    final checklist = DetailedBodyChecklist(
      head: hasHead,
      shoulders: hasShoulders,
      elbows: hasElbows,
      hands: hasHands,
      hips: hasHips,
      knees: hasKnees,
      feet: hasFeet,
    );

    final missing = <String>[];
    final isPushUpOrPlank = exerciseType == 'PUSH_UP' || exerciseType == 'PLANK';

    if (!isPushUpOrPlank && !hasHead) missing.add('Bosh');
    if (!hasShoulders) missing.add('Yelka');
    if (isPushUpOrPlank && (!hasElbows || !hasHands)) missing.add('Qo\'l');
    if (!hasHips) missing.add('Bel');
    if (!isPushUpOrPlank && !hasKnees) missing.add('Tizza');
    if (!isPushUpOrPlank && !hasFeet) missing.add('Oyoq');

    final ready = missing.isEmpty;
    String message = "Tanangiz to'liq aniqlandi ✓";

    if (!ready) {
      final isLegMissing = !hasFeet || !hasKnees;
      final isHeadMissing = !hasHead;

      if (!isPushUpOrPlank && isHeadMissing && missing.length >= 4) {
        message = 'Kameraga to\'liq ko\'rining. Tana ko\'rinmayapti!';
      } else if (!isPushUpOrPlank && isLegMissing && isHeadMissing) {
        message = 'Bosh va oyoq ko\'rinmayapti! Kameradan bir oz orqaga turing.';
      } else if (isLegMissing) {
        message = 'Oyoq ko\'rinmayapti! Kamerani pastroqqa qarating.';
      } else if (!isPushUpOrPlank && isHeadMissing) {
        message = 'Bosh ko\'rinmayapti! Kameraga to\'liq ko\'rining.';
      } else if (!hasHips) {
        message = 'Bel ko\'rinmayapti!';
      } else {
        message = "${missing.join(', ')} ko'rinmayapti.";
      }
    }

    double totalVis = 0.0;
    int count = 0;
    lm.forEach((_, l) {
      totalVis += l.likelihood;
      count++;
    });
    final confidence = count > 0 ? ((totalVis / count) * 100).round() : 0;

    return BodyReadinessResult(
      ready: ready,
      message: message,
      missingPartsUzbek: missing,
      checklist: checklist,
      confidence: confidence,
    );
  }

  /// Backward-compatible alias for Squat readiness
  BodyReadinessResult checkSquatReadiness(Pose? pose) =>
      checkExerciseReadiness(pose, exerciseType: 'SQUAT');

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.android) {
      var rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (defaultTargetPlatform == TargetPlatform.android &&
            format != InputImageFormat.nv21 &&
            format != InputImageFormat.yuv420) ||
        (defaultTargetPlatform == TargetPlatform.iOS &&
            format != InputImageFormat.bgra8888)) {
      return null;
    }

    Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
    } else {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  static final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<void> dispose() async {
    await _detector.close();
  }
}
