// ODAT — Exercise Session Manager with Explicit Session State Machine

import { IExerciseStrategy } from './strategies/ExerciseStrategy';
import { SquatStrategy } from './strategies/SquatStrategy';
import { PushUpStrategy } from './strategies/PushUpStrategy';
import { PlankStrategy } from './strategies/PlankStrategy';
import { WalkingRunningStrategy } from './strategies/WalkingRunningStrategy';
import { PoseDetector, CameraFrameStatus } from './PoseDetector';
import { PoseLandmarks, ExerciseEvaluationResult, ExerciseSessionState } from './types';
import { ExerciseSession, ExerciseTelemetry } from '../types';

export class ExerciseSessionManager {
  private session: ExerciseSession;
  private strategy: IExerciseStrategy;
  private detector: PoseDetector;
  private state: ExerciseSessionState = 'CAMERA_INITIALIZING';
  private frameCount = 0;
  private validFrameCount = 0;

  constructor(session: ExerciseSession, detector?: PoseDetector) {
    this.session = session;
    this.detector = detector || PoseDetector.getInstance();
    this.strategy = this.createStrategy(session.exerciseType);
    this.state = 'BODY_CHECK';
  }

  private createStrategy(exerciseType: string): IExerciseStrategy {
    switch (exerciseType.toUpperCase()) {
      case 'SQUAT':
        return new SquatStrategy();
      case 'PUSH_UP':
        return new PushUpStrategy();
      case 'PLANK':
        return new PlankStrategy();
      case 'RUNNING':
        return new WalkingRunningStrategy('RUNNING');
      case 'WALKING':
        return new WalkingRunningStrategy('WALKING');
      default:
        return new SquatStrategy();
    }
  }

  public getState(): ExerciseSessionState {
    return this.state;
  }

  public setState(newState: ExerciseSessionState): void {
    this.state = newState;
  }

  public getSession(): ExerciseSession {
    return { ...this.session };
  }

  public startCountdown(): void {
    this.state = 'COUNTDOWN';
  }

  public startExercising(): void {
    this.state = 'EXERCISING';
    this.session.status = 'STARTED';
    this.session.startedAt = new Date().toISOString();
    this.strategy.reset();
  }

  public pauseSession(): void {
    this.state = 'PAUSED';
    this.session.status = 'PAUSED';
  }

  public resumeSession(): void {
    if (this.state === 'PAUSED') {
      this.state = 'EXERCISING';
      this.session.status = 'STARTED';
    }
  }

  public cancelSession(): void {
    this.state = 'COMPLETED';
    this.session.status = 'CANCELLED';
  }

  public processFrame(landmarks: PoseLandmarks | null, timestampMs: number): {
    evalResult: ExerciseEvaluationResult;
    envStatus: CameraFrameStatus;
    isTargetReached: boolean;
    sessionState: ExerciseSessionState;
  } {
    this.frameCount++;
    const envStatus = this.detector.analyzeFrameEnvironment(landmarks, null, this.session.exerciseType);

    // Update readiness state
    if (this.state === 'BODY_CHECK' || this.state === 'WAITING_FOR_POSITION') {
      if (envStatus.isFullyVisible) {
        this.state = 'READY';
      } else {
        this.state = 'WAITING_FOR_POSITION';
      }
    }

    // Repetition counting occurs whenever landmarks are detected during EXERCISING state
    let evalResult: ExerciseEvaluationResult;
    if (this.state === 'EXERCISING' && landmarks && landmarks.length > 0) {
      this.validFrameCount++;
      evalResult = this.strategy.evaluateFrame(landmarks, timestampMs);
    } else {
      evalResult = {
        validRepAdded: false,
        currentCount: this.strategy.getRepCount(),
        feedback: envStatus.message || 'Tayyorlaning...',
        formStatus: 'GOOD',
        currentPhase: 'WAITING',
        confidence: readinessConfidence(landmarks),
        bodyVisible: landmarks !== null,
        segments: envStatus.segments,
      };
    }

    const isTargetReached = (this.state === 'EXERCISING') && this.checkTargetReached();

    return {
      evalResult,
      envStatus,
      isTargetReached,
      sessionState: this.state,
    };
  }

  private checkTargetReached(): boolean {
    const currentReps = this.strategy.getRepCount();
    const currentDuration = this.strategy.getDurationSeconds();

    if (this.session.targetRepetitions && currentReps >= this.session.targetRepetitions) {
      return true;
    }
    if (this.session.targetDuration && currentDuration >= this.session.targetDuration) {
      return true;
    }
    return false;
  }

  public compileTelemetry(): ExerciseTelemetry {
    const reps = this.strategy.getRepCount();
    const duration = this.strategy.getDurationSeconds();
    const avgConfidence = this.frameCount > 0 ? (this.validFrameCount / this.frameCount) : 1.0;

    return {
      exerciseType: this.session.exerciseType,
      repetitions: reps,
      durationSeconds: duration,
      averageFormScore: Math.round(avgConfidence * 100),
      confidenceScore: Math.round(avgConfidence * 100),
      timestamp: new Date().toISOString(),
    };
  }

  public markCompleted(): ExerciseSession {
    this.state = 'COMPLETED';
    this.session.status = 'COMPLETED';
    this.session.completedAt = new Date().toISOString();
    this.session.telemetry = this.compileTelemetry();
    return this.session;
  }
}

function readinessConfidence(landmarks: PoseLandmarks | null): number {
  if (!landmarks || landmarks.length === 0) return 0;
  const sum = landmarks.reduce((acc, p) => acc + (p.visibility ?? 0), 0);
  return Math.round((sum / landmarks.length) * 100);
}
