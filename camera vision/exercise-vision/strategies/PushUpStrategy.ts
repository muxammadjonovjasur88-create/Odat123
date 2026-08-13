// ODAT — Fast & Accurate Push-Up Strategy

import { IExerciseStrategy } from './ExerciseStrategy';
import { PoseLandmarks, PoseLandmarkIndex, ExerciseEvaluationResult, calculateAngle } from './types';

export type PushUpPhase = 'UP' | 'DOWN';

export class PushUpStrategy implements IExerciseStrategy {
  readonly exerciseType = 'PUSH_UP';

  private currentPhase: PushUpPhase = 'UP';
  private repCount = 0;
  private lastRepTimestamp = 0;
  private minDepthReached = false;
  private totalDurationSeconds = 0;
  private startTime: number | null = null;

  // Thresholds optimized for fast reps
  private readonly UP_ANGLE = 145; // Elbow angle for standing/up
  private readonly DOWN_ANGLE = 110; // Elbow angle <= 110° considered valid bottom
  private readonly DEBOUNCE_MS = 250; // Min 250ms between reps

  public reset(): void {
    this.currentPhase = 'UP';
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

    const leftShoulder = landmarks[PoseLandmarkIndex.LEFT_SHOULDER];
    const rightShoulder = landmarks[PoseLandmarkIndex.RIGHT_SHOULDER];
    const leftElbow = landmarks[PoseLandmarkIndex.LEFT_ELBOW];
    const rightElbow = landmarks[PoseLandmarkIndex.RIGHT_ELBOW];
    const leftWrist = landmarks[PoseLandmarkIndex.LEFT_WRIST];
    const rightWrist = landmarks[PoseLandmarkIndex.RIGHT_WRIST];

    const hasLeftArm = leftShoulder && leftElbow && leftWrist && (leftElbow.visibility ?? 0) > 0.15;
    const hasRightArm = rightShoulder && rightElbow && rightWrist && (rightElbow.visibility ?? 0) > 0.15;

    if (!hasLeftArm && !hasRightArm) {
      return {
        validRepAdded: false,
        currentCount: this.repCount,
        feedback: 'Qo‘llar ko‘rinishi kerak',
        formStatus: 'WARNING',
        currentPhase: this.currentPhase,
        confidence: 0,
        bodyVisible: false,
      };
    }

    let avgElbowAngle: number;
    let confidence = 0;

    if (hasLeftArm && hasRightArm) {
      const leftAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
      const rightAngle = calculateAngle(rightShoulder, rightElbow, rightWrist);
      avgElbowAngle = (leftAngle + rightAngle) / 2;
      confidence = ((leftElbow.visibility ?? 1) + (rightElbow.visibility ?? 1)) / 2;
    } else if (hasLeftArm) {
      avgElbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
      confidence = leftElbow.visibility ?? 1;
    } else {
      avgElbowAngle = calculateAngle(rightShoulder, rightElbow, rightWrist);
      confidence = rightElbow.visibility ?? 1;
    }

    let validRepAdded = false;
    let feedback = 'Yaxshi davom eting';
    let formStatus: 'GOOD' | 'WARNING' | 'INVALID' = 'GOOD';

    // State machine logic
    if (this.currentPhase === 'UP') {
      if (avgElbowAngle <= this.DOWN_ANGLE) {
        this.currentPhase = 'DOWN';
        this.minDepthReached = true;
        feedback = 'Ajoyib tushdingiz!';
      }
    } else if (this.currentPhase === 'DOWN') {
      if (avgElbowAngle >= this.UP_ANGLE) {
        if (this.minDepthReached && (timestampMs - this.lastRepTimestamp) > this.DEBOUNCE_MS) {
          this.repCount += 1;
          this.lastRepTimestamp = timestampMs;
          validRepAdded = true;
          feedback = 'Zo‘r otjimaniya! +1';
        }
        this.currentPhase = 'UP';
        this.minDepthReached = false;
      }
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
