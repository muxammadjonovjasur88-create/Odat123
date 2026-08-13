// ODAT — Pose Landmark & Movement Math Types

export interface NormalizedLandmark {
  x: number; // 0.0 to 1.0
  y: number; // 0.0 to 1.0
  z: number;
  visibility?: number;
}

export type PoseLandmarks = NormalizedLandmark[];

export enum PoseLandmarkIndex {
  NOSE = 0,
  LEFT_EYE_INNER = 1,
  LEFT_EYE = 2,
  LEFT_EYE_OUTER = 3,
  RIGHT_EYE_INNER = 4,
  RIGHT_EYE = 5,
  RIGHT_EYE_OUTER = 6,
  LEFT_EAR = 7,
  RIGHT_EAR = 8,
  MOUTH_LEFT = 9,
  MOUTH_RIGHT = 10,
  LEFT_SHOULDER = 11,
  RIGHT_SHOULDER = 12,
  LEFT_ELBOW = 13,
  RIGHT_ELBOW = 14,
  LEFT_WRIST = 15,
  RIGHT_WRIST = 16,
  LEFT_PINKY = 17,
  RIGHT_PINKY = 18,
  LEFT_INDEX = 19,
  RIGHT_INDEX = 20,
  LEFT_THUMB = 21,
  RIGHT_THUMB = 22,
  LEFT_HIP = 23,
  RIGHT_HIP = 24,
  LEFT_KNEE = 25,
  RIGHT_KNEE = 26,
  LEFT_ANKLE = 27,
  RIGHT_ANKLE = 28,
  LEFT_HEEL = 29,
  RIGHT_HEEL = 30,
  LEFT_FOOT_INDEX = 31,
  RIGHT_FOOT_INDEX = 32,
}

export type FormStatus = 'GOOD' | 'WARNING' | 'INVALID';

export type ExerciseSessionState =
  | 'CAMERA_INITIALIZING'
  | 'BODY_CHECK'
  | 'WAITING_FOR_POSITION'
  | 'READY'
  | 'COUNTDOWN'
  | 'EXERCISING'
  | 'PAUSED'
  | 'COMPLETED'
  | 'ERROR';

export type BodyPartKey = 'HEAD' | 'SHOULDERS' | 'ELBOWS' | 'HANDS' | 'HIPS' | 'KNEES' | 'FEET';

export const EXERCISE_LANDMARK_REQUIREMENTS: Record<string, BodyPartKey[]> = {
  SQUAT: ['HEAD', 'SHOULDERS', 'HIPS', 'KNEES', 'FEET'],
  PUSH_UP: ['SHOULDERS', 'ELBOWS', 'HANDS', 'HIPS', 'KNEES', 'FEET'],
  PLANK: ['SHOULDERS', 'ELBOWS', 'HANDS', 'HIPS', 'KNEES', 'FEET'],
  WALKING: ['HIPS', 'KNEES', 'FEET'],
  RUNNING: ['HIPS', 'KNEES', 'FEET'],
};

export const BODY_PART_LABELS_UZ: Record<BodyPartKey, string> = {
  HEAD: 'Bosh',
  SHOULDERS: 'Yelka',
  ELBOWS: 'Tirsak',
  HANDS: 'Qo‘l',
  HIPS: 'Bel / Tos',
  KNEES: 'Tizza',
  FEET: 'Oyoq / To‘piq',
};

export interface DetailedBodyChecklist {
  head: boolean;
  shoulders: boolean;
  elbows: boolean;
  hands: boolean;
  hips: boolean;
  knees: boolean;
  feet: boolean;
}

export interface CheckExerciseReadinessResult {
  ready: boolean;
  missingParts: BodyPartKey[];
  missingPartsUzbek: string[];
  checklist: DetailedBodyChecklist;
  message: string;
  confidence: number;
}

export interface BodySegmentStatus {
  headDetected: boolean;
  shouldersDetected: boolean;
  armsDetected: boolean;
  coreDetected: boolean;
  legsDetected: boolean;
  checklist?: DetailedBodyChecklist;
}

export interface ExerciseEvaluationResult {
  validRepAdded: boolean;
  currentCount: number;
  feedback: string;
  formStatus: FormStatus;
  currentPhase: string;
  confidence: number;
  bodyVisible: boolean;
  segments?: BodySegmentStatus;
  visibilityMessage?: string;
}

/**
 * Calculates 2D angle in degrees between three keypoints (A -> B -> C, vertex at B)
 */
export function calculateAngle(
  pointA: NormalizedLandmark,
  pointB: NormalizedLandmark,
  pointC: NormalizedLandmark
): number {
  const radians = Math.atan2(pointC.y - pointB.y, pointC.x - pointB.x) -
                  Math.atan2(pointA.y - pointB.y, pointA.x - pointB.x);
  let angle = Math.abs((radians * 180.0) / Math.PI);
  if (angle > 180.0) {
    angle = 360.0 - angle;
  }
  return angle;
}

/**
 * Calculates Euclidean distance between two landmarks
 */
export function calculateDistance(
  p1: NormalizedLandmark,
  p2: NormalizedLandmark
): number {
  const dx = p1.x - p2.x;
  const dy = p1.y - p2.y;
  return Math.sqrt(dx * dx + dy * dy);
}
