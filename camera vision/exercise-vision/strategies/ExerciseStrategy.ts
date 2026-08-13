// ODAT — Exercise Strategy Interface

import { PoseLandmarks, ExerciseEvaluationResult } from './types';

export interface IExerciseStrategy {
  readonly exerciseType: string;
  evaluateFrame(landmarks: PoseLandmarks, timestampMs: number): ExerciseEvaluationResult;
  reset(): void;
  getRepCount(): number;
  getDurationSeconds(): number;
}
