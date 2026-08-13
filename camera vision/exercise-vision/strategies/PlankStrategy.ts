// ODAT — Fast & Accurate Plank Duration Strategy

import { IExerciseStrategy } from './ExerciseStrategy';
import { PoseLandmarks, PoseLandmarkIndex, ExerciseEvaluationResult, calculateAngle } from './types';

export class PlankStrategy implements IExerciseStrategy {
  readonly exerciseType = 'PLANK';

  private validDurationSeconds = 0;
  private lastFrameTimestamp: number | null = null;
  private formWarningCount = 0;

  public reset(): void {
    this.validDurationSeconds = 0;
    this.lastFrameTimestamp = null;
    this.formWarningCount = 0;
  }

  public getRepCount(): number {
    return Math.floor(this.validDurationSeconds);
  }

  public getDurationSeconds(): number {
    return Math.floor(this.validDurationSeconds);
  }

  public evaluateFrame(landmarks: PoseLandmarks, timestampMs: number): ExerciseEvaluationResult {
    if (this.lastFrameTimestamp === null) {
      this.lastFrameTimestamp = timestampMs;
    }

    const deltaSec = (timestampMs - this.lastFrameTimestamp) / 1000;
    this.lastFrameTimestamp = timestampMs;

    const leftShoulder = landmarks[PoseLandmarkIndex.LEFT_SHOULDER];
    const rightShoulder = landmarks[PoseLandmarkIndex.RIGHT_SHOULDER];
    const leftHip = landmarks[PoseLandmarkIndex.LEFT_HIP];
    const rightHip = landmarks[PoseLandmarkIndex.RIGHT_HIP];
    const leftAnkle = landmarks[PoseLandmarkIndex.LEFT_ANKLE];
    const rightAnkle = landmarks[PoseLandmarkIndex.RIGHT_ANKLE];

    const hasLeftSide = leftShoulder && leftHip && (leftHip.visibility ?? 0) > 0.15;
    const hasRightSide = rightShoulder && rightHip && (rightHip.visibility ?? 0) > 0.15;

    if (!hasLeftSide && !hasRightSide) {
      return {
        validRepAdded: false,
        currentCount: Math.floor(this.validDurationSeconds),
        feedback: 'Kamerada tanangiz ko‘rinishi kerak',
        formStatus: 'WARNING',
        currentPhase: 'PAUSED',
        confidence: 0,
        bodyVisible: false,
      };
    }

    let avgSpineAngle = 180;
    let confidence = 0.8;

    if (hasLeftSide && hasRightSide) {
      const leftAngle = calculateAngle(leftShoulder, leftHip, leftAnkle || leftHip);
      const rightAngle = calculateAngle(rightShoulder, rightHip, rightAnkle || rightHip);
      avgSpineAngle = (leftAngle + rightAngle) / 2;
      confidence = ((leftHip.visibility ?? 1) + (rightHip.visibility ?? 1)) / 2;
    } else if (hasLeftSide) {
      avgSpineAngle = calculateAngle(leftShoulder, leftHip, leftAnkle || leftHip);
      confidence = leftHip.visibility ?? 1;
    } else {
      avgSpineAngle = calculateAngle(rightShoulder, rightHip, rightAnkle || rightHip);
      confidence = rightHip.visibility ?? 1;
    }

    const isValidForm = avgSpineAngle >= 135 && avgSpineAngle <= 220;

    let feedback = 'Ajoyib barqarorlik! Plank ushlab turing';
    let formStatus: 'GOOD' | 'WARNING' | 'INVALID' = 'GOOD';
    let validRepAdded = false;

    if (isValidForm) {
      const prevWhole = Math.floor(this.validDurationSeconds);
      this.validDurationSeconds += Math.min(deltaSec, 1.0);
      const newWhole = Math.floor(this.validDurationSeconds);

      if (newWhole > prevWhole) {
        validRepAdded = true;
      }
    } else {
      this.formWarningCount++;
      formStatus = 'WARNING';
      if (avgSpineAngle < 135) {
        feedback = 'Beldan pastga tushib ketmang, tanani tekis tuting';
      } else {
        feedback = 'Beldan yuqoriga ko‘tarilib ketmang';
      }
    }

    return {
      validRepAdded,
      currentCount: Math.floor(this.validDurationSeconds),
      feedback,
      formStatus,
      currentPhase: isValidForm ? 'HOLDING' : 'FORM_WARNING',
      confidence,
      bodyVisible: true,
    };
  }
}
