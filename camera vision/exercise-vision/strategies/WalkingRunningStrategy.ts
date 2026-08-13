// ODAT — Walking & Running Motion & Step Pattern Strategy

import { IExerciseStrategy } from './ExerciseStrategy';
import { PoseLandmarks, PoseLandmarkIndex, ExerciseEvaluationResult, calculateDistance } from './types';

export class WalkingRunningStrategy implements IExerciseStrategy {
  readonly exerciseType: 'WALKING' | 'RUNNING';

  private stepCount = 0;
  private lastAnkleDistance = 0;
  private lastStepTimestamp = 0;
  private totalDurationSeconds = 0;
  private startTime: number | null = null;
  private stepPhase: 'EXPAND' | 'RETRACT' = 'RETRACT';

  constructor(type: 'WALKING' | 'RUNNING' = 'WALKING') {
    this.exerciseType = type;
  }

  public reset(): void {
    this.stepCount = 0;
    this.lastAnkleDistance = 0;
    this.lastStepTimestamp = 0;
    this.totalDurationSeconds = 0;
    this.startTime = null;
    this.stepPhase = 'RETRACT';
  }

  public getRepCount(): number {
    return this.stepCount;
  }

  public getDurationSeconds(): number {
    return Math.floor(this.totalDurationSeconds);
  }

  public addHardwareSensorSteps(sensorSteps: number) {
    this.stepCount += sensorSteps;
  }

  public evaluateFrame(landmarks: PoseLandmarks, timestampMs: number): ExerciseEvaluationResult {
    if (!this.startTime) {
      this.startTime = timestampMs;
    }
    this.totalDurationSeconds = (timestampMs - this.startTime) / 1000;

    const leftAnkle = landmarks[PoseLandmarkIndex.LEFT_ANKLE];
    const rightAnkle = landmarks[PoseLandmarkIndex.RIGHT_ANKLE];
    const leftHip = landmarks[PoseLandmarkIndex.LEFT_HIP];
    const rightHip = landmarks[PoseLandmarkIndex.RIGHT_HIP];

    if (!leftAnkle || !rightAnkle || !leftHip || !rightHip) {
      return {
        validRepAdded: false,
        currentCount: this.stepCount,
        feedback: 'Kameraga to‘liq ko‘rining',
        formStatus: 'WARNING',
        currentPhase: 'PAUSED',
        confidence: 0,
        bodyVisible: false,
      };
    }

    const confidence = (
      (leftAnkle.visibility ?? 1) + (rightAnkle.visibility ?? 1) +
      (leftHip.visibility ?? 1) + (rightHip.visibility ?? 1)
    ) / 4;

    const currentAnkleDist = calculateDistance(leftAnkle, rightAnkle);
    let validRepAdded = false;

    // Detect leg stride cycle (EXPAND -> RETRACT = +1 step)
    const threshold = this.exerciseType === 'RUNNING' ? 0.18 : 0.12;

    if (this.stepPhase === 'RETRACT') {
      if (currentAnkleDist > threshold) {
        this.stepPhase = 'EXPAND';
      }
    } else if (this.stepPhase === 'EXPAND') {
      if (currentAnkleDist < threshold * 0.7) {
        if ((timestampMs - this.lastStepTimestamp) > 250) {
          this.stepCount += 1;
          this.lastStepTimestamp = timestampMs;
          validRepAdded = true;
        }
        this.stepPhase = 'RETRACT';
      }
    }

    const modeText = this.exerciseType === 'RUNNING' ? 'Yugurish' : 'Yurish';
    const feedback = `${modeText} davom etmoqda. Sur'atni saqlang!`;

    return {
      validRepAdded,
      currentCount: this.stepCount,
      feedback,
      formStatus: 'GOOD',
      currentPhase: this.stepPhase,
      confidence,
      bodyVisible: true,
    };
  }
}
