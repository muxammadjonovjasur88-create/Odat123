// ODAT — Fast & Accurate Squat Strategy

import { IExerciseStrategy } from './ExerciseStrategy';
import { PoseLandmarks, PoseLandmarkIndex, ExerciseEvaluationResult, calculateAngle } from './types';

export type SquatPhase = 'STANDING' | 'DESCENDING' | 'BOTTOM' | 'ASCENDING';

export class SquatStrategy implements IExerciseStrategy {
  readonly exerciseType = 'SQUAT';

  private currentPhase: SquatPhase = 'STANDING';
  private repCount = 0;
  private lastRepTimestamp = 0;
  private minDepthReached = false;
  private totalDurationSeconds = 0;
  private startTime: number | null = null;

  // Optimized Thresholds for Fast Repetitions
  private readonly STANDING_ANGLE = 150; // Knee angle degrees for standing
  private readonly SQUAT_DEPTH_ANGLE = 115; // Knee angle <= 115° considered valid bottom
  private readonly DEBOUNCE_MS = 250; // Min 250ms between reps for fast squats

  public reset(): void {
    this.currentPhase = 'STANDING';
    this.repCount = 0;
    this.lastRepTimestamp = 0;
    this.minDepthReached = false;
    this.totalDurationSeconds = 0;
    this.startTime = null;
  }

  public getRepCount(): number {
    return this.repCount;
  }

  public getDurationSeconds(): number {
    return Math.floor(this.totalDurationSeconds);
  }

  public evaluateFrame(landmarks: PoseLandmarks, timestampMs: number): ExerciseEvaluationResult {
    if (!this.startTime) {
      this.startTime = timestampMs;
    }
    this.totalDurationSeconds = (timestampMs - this.startTime) / 1000;

    const leftHip = landmarks[PoseLandmarkIndex.LEFT_HIP];
    const rightHip = landmarks[PoseLandmarkIndex.RIGHT_HIP];
    const leftKnee = landmarks[PoseLandmarkIndex.LEFT_KNEE];
    const rightKnee = landmarks[PoseLandmarkIndex.RIGHT_KNEE];
    const leftAnkle = landmarks[PoseLandmarkIndex.LEFT_ANKLE];
    const rightAnkle = landmarks[PoseLandmarkIndex.RIGHT_ANKLE];

    const hasLeftLeg = leftHip && leftKnee && leftAnkle && (leftKnee.visibility ?? 0) > 0.15;
    const hasRightLeg = rightHip && rightKnee && rightAnkle && (rightKnee.visibility ?? 0) > 0.15;

    if (!hasLeftLeg && !hasRightLeg) {
      return {
        validRepAdded: false,
        currentCount: this.repCount,
        feedback: 'Oyoqlar va sonlar ko‘rinishi kerak',
        formStatus: 'WARNING',
        currentPhase: this.currentPhase,
        confidence: 0,
        bodyVisible: false,
      };
    }

    let avgKneeAngle: number;
    let confidence = 0;

    if (hasLeftLeg && hasRightLeg) {
      const leftAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
      const rightAngle = calculateAngle(rightHip, rightKnee, rightAnkle);
      avgKneeAngle = (leftAngle + rightAngle) / 2;
      confidence = ((leftKnee.visibility ?? 1) + (rightKnee.visibility ?? 1)) / 2;
    } else if (hasLeftLeg) {
      avgKneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
      confidence = leftKnee.visibility ?? 1;
    } else {
      avgKneeAngle = calculateAngle(rightHip, rightKnee, rightAnkle);
      confidence = rightKnee.visibility ?? 1;
    }

    let validRepAdded = false;
    let feedback = 'Yaxshi davom eting';
    let formStatus: 'GOOD' | 'WARNING' | 'INVALID' = 'GOOD';

    // State Machine logic optimized for fast execution
    switch (this.currentPhase) {
      case 'STANDING':
        if (avgKneeAngle < 140) {
          this.currentPhase = 'DESCENDING';
          this.minDepthReached = false;
        }
        break;

      case 'DESCENDING':
        if (avgKneeAngle <= this.SQUAT_DEPTH_ANGLE) {
          this.currentPhase = 'BOTTOM';
          this.minDepthReached = true;
        } else if (avgKneeAngle > 150) {
          this.currentPhase = 'STANDING';
          feedback = 'Pastroq tushing';
          formStatus = 'WARNING';
        }
        break;

      case 'BOTTOM':
        if (avgKneeAngle > 125) {
          this.currentPhase = 'ASCENDING';
        }
        break;

      case 'ASCENDING':
        if (avgKneeAngle >= this.STANDING_ANGLE) {
          if (this.minDepthReached && (timestampMs - this.lastRepTimestamp) > this.DEBOUNCE_MS) {
            this.repCount += 1;
            this.lastRepTimestamp = timestampMs;
            validRepAdded = true;
            feedback = 'Ajoyib squat! +1';
          }
          this.currentPhase = 'STANDING';
          this.minDepthReached = false;
        }
        break;
    }

    if (this.currentPhase === 'DESCENDING' && avgKneeAngle > 130) {
      feedback = 'Pastroq cho‘kishingiz kerak';
    } else if (this.currentPhase === 'BOTTOM') {
      feedback = 'Ajoyib chuqurlik! Endi tiklaning';
    }

    return {
      validRepAdded,
      currentCount: this.repCount,
      feedback,
      formStatus,
      currentPhase: this.currentPhase,
      confidence,
      bodyVisible: true,
    };
  }
}
