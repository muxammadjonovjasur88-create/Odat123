import { FilesetResolver as NpmFilesetResolver, PoseLandmarker as NpmPoseLandmarker } from '@mediapipe/tasks-vision';

import {
  PoseLandmarks,
  PoseLandmarkIndex,
  NormalizedLandmark,
  BodySegmentStatus,
  BodyPartKey,
  DetailedBodyChecklist,
  CheckExerciseReadinessResult,
  EXERCISE_LANDMARK_REQUIREMENTS,
  BODY_PART_LABELS_UZ,
} from './types';

export interface PoseDetectorConfig {
  minConfidence: number;
  minConsecutiveFrames: number;
}

export interface CameraFrameStatus {
  personDetected: boolean;
  multiplePeopleDetected: boolean;
  isFullyVisible: boolean;
  headVisible: boolean;
  feetVisible: boolean;
  tooClose: boolean;
  tooFar: boolean;
  lightingGood: boolean;
  cameraStable: boolean;
  segments: BodySegmentStatus;
  checklist: DetailedBodyChecklist;
  message: string;
  missingPartsUzbek: string[];
}

export class PoseDetector {
  private static instance: PoseDetector | null = null;

  public static getInstance(config?: Partial<PoseDetectorConfig>): PoseDetector {
    if (!PoseDetector.instance) {
      PoseDetector.instance = new PoseDetector(config);
    }
    return PoseDetector.instance;
  }

  private config: PoseDetectorConfig;
  private worker: Worker | null = null;
  private poseLandmarkerFallback: any = null;
  private isInitializing = false;
  private isReady = false;
  private isWorkerMode = false;
  private isWorkerPending = false;
  private lastWorkerSentTime = 0;
  private isFallbackPending = false;
  private lastFallbackSentTime = 0;
  private emptyFramesCount = 0;

  // Zero-allocation pre-allocated landmark pools for 60 FPS GC-free execution
  private hasValidLandmarks = false;
  private preallocLast: PoseLandmarks = new Array(33).fill(null).map(() => ({ x: 0, y: 0, z: 0, visibility: 0 }));
  private preallocPrev: PoseLandmarks = new Array(33).fill(null).map(() => ({ x: 0, y: 0, z: 0, visibility: 0 }));
  private preallocRender: PoseLandmarks = new Array(33).fill(null).map(() => ({ x: 0, y: 0, z: 0, visibility: 0 }));

  private lastLandmarksTimestamp: number = 0;
  private prevLandmarksTimestamp: number = 0;

  private offscreenCanvas: HTMLCanvasElement | null = null;
  private offscreenCtx: CanvasRenderingContext2D | null = null;

  // Stability counters per body part
  private stabilityCounters: Record<BodyPartKey, number> = {
    HEAD: 0, SHOULDERS: 0, ELBOWS: 0, HANDS: 0, HIPS: 0, KNEES: 0, FEET: 0,
  };

  private absenceCounters: Record<BodyPartKey, number> = {
    HEAD: 0, SHOULDERS: 0, ELBOWS: 0, HANDS: 0, HIPS: 0, KNEES: 0, FEET: 0,
  };

  private detectionState: DetailedBodyChecklist = {
    head: false, shoulders: false, elbows: false, hands: false, hips: false, knees: false, feet: false,
  };

  constructor(config?: Partial<PoseDetectorConfig>) {
    this.config = {
      minConfidence: 0.05, // Ultra-sensitive motion blur tolerance threshold
      minConsecutiveFrames: 2,
      ...config,
    };
    this.initDetector();
  }

  private lastInferenceTimestampMs = 0;

  private getMonotonicTimestamp(): number {
    const now = performance.now();
    if (now <= this.lastInferenceTimestampMs) {
      this.lastInferenceTimestampMs += 1.0;
    } else {
      this.lastInferenceTimestampMs = now;
    }
    return this.lastInferenceTimestampMs;
  }

  private async initDetector() {
    if (this.isInitializing || this.isReady) return;
    this.isInitializing = true;

    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    const localWasmPath = `${origin}/mediapipe/wasm`;
    const localModelPath = `${origin}/mediapipe/pose_landmarker_lite.task`;
    const cdnWasmPath = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.22/wasm';
    const cdnModelPath = 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task';

    // 1. Try initializing Web Worker first (Zero Main-Thread Lag)
    if (typeof window !== 'undefined' && typeof Worker !== 'undefined') {
      try {
        this.worker = new Worker(new URL('./poseWorker.ts', import.meta.url), { type: 'module' });

        this.worker.onmessage = (e: MessageEvent) => {
          const { type, success, landmarks, timestampMs } = e.data;
          if (type === 'INIT_DONE') {
            if (success) {
              this.isReady = true;
              this.isWorkerMode = true;
              console.log('[ODAT] Web Worker Pose Detector ready (GPU) ✓');
            } else {
              console.warn('[ODAT] Web Worker init failed, using main-thread fallback...');
              this.initMainThreadFallback(localWasmPath, localModelPath, cdnWasmPath, cdnModelPath);
            }
          } else if (type === 'DETECT_RESULT') {
            this.isWorkerPending = false;
            this.handleNewLandmarks(landmarks, timestampMs);
          }
        };

        this.worker.onerror = (err) => {
          console.warn('[ODAT] Web Worker runtime error, unlocking:', err);
          this.isWorkerPending = false;
        };

        this.worker.postMessage({
          type: 'INIT',
          payload: {
            wasmPath: localWasmPath,
            modelPath: localModelPath,
            delegate: 'GPU',
          },
        });

        this.isInitializing = false;
        return;
      } catch (workerErr) {
        console.warn('[ODAT] Worker instantiation failed:', workerErr);
      }
    }

    // Fallback if Web Worker is not supported or failed
    await this.initMainThreadFallback(localWasmPath, localModelPath, cdnWasmPath, cdnModelPath);
  }

  private async initMainThreadFallback(localWasmPath: string, localModelPath: string, cdnWasmPath: string, cdnModelPath: string) {
    const tryInit = async (wasmPath: string, modelPath: string, delegate: 'GPU' | 'CPU') => {
      const resolverClass = (typeof window !== 'undefined' && (window as any).FilesetResolver) || NpmFilesetResolver;
      const landmarkerClass = (typeof window !== 'undefined' && (window as any).PoseLandmarker) || NpmPoseLandmarker;

      const filesetResolver = await resolverClass.forVisionTasks(wasmPath);
      return await landmarkerClass.createFromOptions(filesetResolver, {
        baseOptions: {
          modelAssetPath: modelPath,
          delegate: delegate,
        },
        runningMode: 'VIDEO',
        numPoses: 1,
        minPoseDetectionConfidence: 0.05,
        minPosePresenceConfidence: 0.05,
        minTrackingConfidence: 0.05,
      });
    };

    try {
      this.poseLandmarkerFallback = await tryInit(localWasmPath, localModelPath, 'GPU');
      this.isReady = true;
      console.log('[ODAT] Main-Thread MediaPipe Pose Landmarker ready (GPU) ✓');
    } catch (err1) {
      try {
        this.poseLandmarkerFallback = await tryInit(localWasmPath, localModelPath, 'CPU');
        this.isReady = true;
        console.log('[ODAT] Main-Thread MediaPipe Pose Landmarker ready (CPU) ✓');
      } catch (err2) {
        try {
          this.poseLandmarkerFallback = await tryInit(cdnWasmPath, cdnModelPath, 'CPU');
          this.isReady = true;
          console.log('[ODAT] CDN MediaPipe Pose Landmarker ready ✓');
        } catch (cdnErr) {
          console.error('[ODAT] MediaPipe init failed:', cdnErr);
          this.isReady = false;
        }
      }
    } finally {
      this.isInitializing = false;
    }
  }

  public getIsReady(): boolean {
    return this.isReady;
  }

  public resetDetectionState() {
    this.hasValidLandmarks = false;
    this.lastLandmarksTimestamp = 0;
    this.prevLandmarksTimestamp = 0;
    this.isWorkerPending = false;
    this.emptyFramesCount = 0;

    (Object.keys(this.stabilityCounters) as BodyPartKey[]).forEach(k => {
      this.stabilityCounters[k] = 0;
      this.absenceCounters[k] = 10;
      const key = k.toLowerCase() as keyof DetailedBodyChecklist;
      (this.detectionState as any)[key] = false;
    });
  }

  /**
   * Process raw landmarks with in-place ZERO-ALLOCATION array updates
   */
  private handleNewLandmarks(rawLandmarks: any[] | null, timestampMs: number) {
    if (!rawLandmarks || rawLandmarks.length === 0) {
      this.emptyFramesCount += 1;
      if (this.hasValidLandmarks) {
        // Keep active body lock (tanaga fiksatsiya) alive during transient frame drops
        this.lastLandmarksTimestamp = timestampMs || performance.now();
      }
      if (this.emptyFramesCount >= 300) { // Only reset if camera is empty for >5 full seconds
        this.resetDetectionState();
      }
      return;
    }

    this.emptyFramesCount = 0;
    const len = Math.min(33, rawLandmarks.length);

    // 1. Shift last to prev in-place without object allocation
    for (let i = 0; i < len; i++) {
      const cur = this.preallocLast[i];
      const prev = this.preallocPrev[i];
      prev.x = cur.x;
      prev.y = cur.y;
      prev.z = cur.z;
      prev.visibility = cur.visibility;
    }

    // 2. Instant Direct Landmark Copy (0ms Lag, No EMA delay)
    const alpha = 1.0;
    for (let i = 0; i < len; i++) {
      const raw = rawLandmarks[i];
      const cur = this.preallocLast[i];
      if (!raw) continue;
      cur.x = raw.x;
      cur.y = raw.y;
      cur.z = raw.z ?? 0;
      cur.visibility = raw.visibility ?? 1.0;
    }

    this.prevLandmarksTimestamp = this.lastLandmarksTimestamp;
    this.lastLandmarksTimestamp = timestampMs || performance.now();
    this.hasValidLandmarks = true;
  }

  /**
   * Get Zero-Allocation Extrapolated 0ms real-time landmarks with velocity prediction
   */
  public getLastLandmarks(): PoseLandmarks | null {
    if (!this.hasValidLandmarks) return null;
    const now = performance.now();

    // Continuous unbroken body lock (tanaga fiksatsiya) for up to 10 seconds
    if (this.lastLandmarksTimestamp > 0 && now - this.lastLandmarksTimestamp > 10000) {
      this.hasValidLandmarks = false;
      return null;
    }

    if (this.lastLandmarksTimestamp > this.prevLandmarksTimestamp) {
      const dtInference = this.lastLandmarksTimestamp - this.prevLandmarksTimestamp;
      const dtRender = Math.min(now - this.lastLandmarksTimestamp, 35);

      if (dtInference > 0 && dtRender > 0) {
        const factor = Math.min(1.0, dtRender / dtInference);
        for (let i = 0; i < 33; i++) {
          const cur = this.preallocLast[i];
          const prev = this.preallocPrev[i];
          const out = this.preallocRender[i];

          const vx = cur.x - prev.x;
          const vy = cur.y - prev.y;
          const vz = cur.z - prev.z;

          out.x = Math.max(0, Math.min(1, cur.x + vx * factor));
          out.y = Math.max(0, Math.min(1, cur.y + vy * factor));
          out.z = cur.z + vz * factor;
          out.visibility = cur.visibility;
        }
        return this.preallocRender;
      }
    }

    return this.preallocLast;
  }

  public async detectFromVideo(videoElement: HTMLVideoElement): Promise<PoseLandmarks | null> {
    if (videoElement.paused && typeof document !== 'undefined' && document.visibilityState === 'visible') {
      videoElement.play().catch(() => {});
    }

    if (videoElement.readyState < 2 || videoElement.paused || videoElement.ended) {
      return this.getLastLandmarks();
    }

    const timestampMs = this.getMonotonicTimestamp();

    if (this.isReady && this.isWorkerMode && this.worker) {
      if (this.isWorkerPending && timestampMs - this.lastWorkerSentTime > 35) {
        this.isWorkerPending = false;
      }

      if (!this.isWorkerPending) {
        try {
          this.isWorkerPending = true;
          this.lastWorkerSentTime = timestampMs;

          let imageBitmap: ImageBitmap | null = null;
          if (typeof createImageBitmap === 'function') {
            imageBitmap = await createImageBitmap(videoElement);
          }

          if (imageBitmap) {
            this.worker.postMessage(
              { type: 'DETECT', payload: { imageBitmap, timestampMs } },
              [imageBitmap]
            );
          } else {
            this.isWorkerPending = false;
          }
        } catch (e) {
          this.isWorkerPending = false;
        }
      }
      return this.getLastLandmarks();
    }

    // 2. Main-Thread Fallback Mode (Non-blocking Asynchronous Execution)
    if (this.isReady && this.poseLandmarkerFallback) {
      if (this.isFallbackPending && timestampMs - this.lastFallbackSentTime > 50) {
        this.isFallbackPending = false;
      }

      if (!this.isFallbackPending) {
        this.isFallbackPending = true;
        this.lastFallbackSentTime = timestampMs;

        try {
          if (videoElement && videoElement.readyState >= 2) {
            const result = this.poseLandmarkerFallback.detectForVideo(videoElement, timestampMs);
            if (result && result.landmarks && result.landmarks.length > 0) {
              this.handleNewLandmarks(result.landmarks[0], timestampMs);
            } else {
              this.handleNewLandmarks(null, timestampMs);
            }
          }
        } catch (err) {
          console.warn('[ODAT] MediaPipe fallback error:', err);
        } finally {
          this.isFallbackPending = false;
        }
      }
      return this.getLastLandmarks();
    }

    return this.getLastLandmarks();
  }

  public isValidLandmark(lm: NormalizedLandmark | undefined): boolean {
    if (!lm) return false;
    const vis = lm.visibility ?? 1.0;
    if (vis < this.config.minConfidence) return false;
    return true;
  }

  public getRawLandmarkConfidences(landmarks: PoseLandmarks | null): Record<BodyPartKey, number> {
    if (!landmarks || landmarks.length === 0) {
      return { HEAD: 0, SHOULDERS: 0, ELBOWS: 0, HANDS: 0, HIPS: 0, KNEES: 0, FEET: 0 };
    }

    const getVis = (idx: number) => {
      const lm = landmarks[idx];
      return lm ? (lm.visibility ?? 1.0) : 0.0;
    };

    return {
      HEAD: Math.round(Math.max(getVis(PoseLandmarkIndex.NOSE), getVis(PoseLandmarkIndex.LEFT_EYE)) * 100) / 100,
      SHOULDERS: Math.round(((getVis(PoseLandmarkIndex.LEFT_SHOULDER) + getVis(PoseLandmarkIndex.RIGHT_SHOULDER)) / 2) * 100) / 100,
      ELBOWS: Math.round(((getVis(PoseLandmarkIndex.LEFT_ELBOW) + getVis(PoseLandmarkIndex.RIGHT_ELBOW)) / 2) * 100) / 100,
      HANDS: Math.round(((getVis(PoseLandmarkIndex.LEFT_WRIST) + getVis(PoseLandmarkIndex.RIGHT_WRIST)) / 2) * 100) / 100,
      HIPS: Math.round(((getVis(PoseLandmarkIndex.LEFT_HIP) + getVis(PoseLandmarkIndex.RIGHT_HIP)) / 2) * 100) / 100,
      KNEES: Math.round(((getVis(PoseLandmarkIndex.LEFT_KNEE) + getVis(PoseLandmarkIndex.RIGHT_KNEE)) / 2) * 100) / 100,
      FEET: Math.round(((getVis(PoseLandmarkIndex.LEFT_ANKLE) + getVis(PoseLandmarkIndex.RIGHT_ANKLE)) / 2) * 100) / 100,
    };
  }

  public evaluateRawFrameParts(landmarks: PoseLandmarks | null): Record<BodyPartKey, boolean> {
    const ABSENT: Record<BodyPartKey, boolean> = {
      HEAD: false, SHOULDERS: false, ELBOWS: false,
      HANDS: false, HIPS: false, KNEES: false, FEET: false,
    };

    if (!landmarks || landmarks.length === 0) return ABSENT;

    const has = (idx: number) => this.isValidLandmark(landmarks[idx]);

    return {
      HEAD: has(PoseLandmarkIndex.NOSE) || (has(PoseLandmarkIndex.LEFT_EYE) && has(PoseLandmarkIndex.RIGHT_EYE)),
      SHOULDERS: has(PoseLandmarkIndex.LEFT_SHOULDER) || has(PoseLandmarkIndex.RIGHT_SHOULDER),
      ELBOWS: has(PoseLandmarkIndex.LEFT_ELBOW) || has(PoseLandmarkIndex.RIGHT_ELBOW),
      HANDS: has(PoseLandmarkIndex.LEFT_WRIST) || has(PoseLandmarkIndex.RIGHT_WRIST),
      HIPS: has(PoseLandmarkIndex.LEFT_HIP) || has(PoseLandmarkIndex.RIGHT_HIP),
      KNEES: has(PoseLandmarkIndex.LEFT_KNEE) || has(PoseLandmarkIndex.RIGHT_KNEE),
      FEET: has(PoseLandmarkIndex.LEFT_ANKLE) || has(PoseLandmarkIndex.RIGHT_ANKLE),
    };
  }

  public updateStabilityAndGetChecklist(landmarks: PoseLandmarks | null): DetailedBodyChecklist {
    const raw = this.evaluateRawFrameParts(landmarks);
    const REQ = this.config.minConsecutiveFrames;
    const DISAPPEAR = 4;

    (Object.keys(raw) as BodyPartKey[]).forEach(part => {
      const key = part.toLowerCase() as keyof DetailedBodyChecklist;

      if (raw[part]) {
        this.absenceCounters[part] = 0;
        this.stabilityCounters[part] = Math.min(REQ, this.stabilityCounters[part] + 1);
        if (this.stabilityCounters[part] >= REQ) {
          (this.detectionState as any)[key] = true;
        }
      } else {
        this.absenceCounters[part] += 1;
        this.stabilityCounters[part] = 0;
        if (this.absenceCounters[part] >= DISAPPEAR) {
          (this.detectionState as any)[key] = false;
        }
      }
    });

    return { ...this.detectionState };
  }

  public checkExerciseReadiness(
    landmarks: PoseLandmarks | null,
    exerciseType: string = 'SQUAT'
  ): CheckExerciseReadinessResult {
    const checklist = this.updateStabilityAndGetChecklist(landmarks);
    const requiredParts = EXERCISE_LANDMARK_REQUIREMENTS[exerciseType] || EXERCISE_LANDMARK_REQUIREMENTS.SQUAT;

    const missingParts: BodyPartKey[] = [];
    const missingPartsUzbek: string[] = [];

    requiredParts.forEach(part => {
      const key = part.toLowerCase() as keyof DetailedBodyChecklist;
      const isAvailable = checklist[key];
      if (!isAvailable) {
        missingParts.push(part);
        missingPartsUzbek.push(BODY_PART_LABELS_UZ[part]);
      }
    });

    const ready = missingParts.length === 0;

    let message = "Tanangiz to'liq aniqlandi ✓";
    if (!ready) {
      const isLegMissing = !checklist.feet || !checklist.knees;
      const isHeadMissing = !checklist.head;
      const isArmMissing = !checklist.hands || !checklist.elbows;
      const isHipMissing = !checklist.hips;

      if (!checklist.head && missingParts.length >= requiredParts.length - 1) {
        message = 'Kameraga to\'liq ko\'rining. Tana ko\'rinmayapti!';
      } else if (isLegMissing && isHeadMissing) {
        message = 'Bosh va oyoq ko\'rinmayapti! Kameradan bir oz orqaga turing.';
      } else if (isLegMissing) {
        message = 'Oyoq ko\'rinmayapti! Kamerani pastroqqa qarating.';
      } else if (isHeadMissing) {
        message = 'Bosh ko\'rinmayapti! Kameraga to\'liq ko\'rining.';
      } else if (isArmMissing) {
        message = 'Qo\'llar ko\'rinmayapti!';
      } else if (isHipMissing) {
        message = 'Bel ko\'rinmayapti!';
      } else if (missingPartsUzbek.length > 0) {
        message = `${missingPartsUzbek.join(', ')} ko'rinmayapti.`;
      }
    }

    const confidence = landmarks
      ? Math.round((landmarks.reduce((s, p) => s + (p.visibility ?? 0), 0) / landmarks.length) * 100)
      : 0;

    return { ready, missingParts, missingPartsUzbek, checklist, message, confidence };
  }

  public analyzeFrameEnvironment(
    landmarks: PoseLandmarks | null,
    _videoElement?: HTMLVideoElement | null,
    exerciseType: string = 'SQUAT'
  ): CameraFrameStatus {
    const activeLandmarks = landmarks ?? null;
    const readiness = this.checkExerciseReadiness(activeLandmarks, exerciseType);

    const segments: BodySegmentStatus = {
      headDetected: readiness.checklist.head,
      shouldersDetected: readiness.checklist.shoulders,
      armsDetected: readiness.checklist.elbows && readiness.checklist.hands,
      coreDetected: readiness.checklist.hips,
      legsDetected: readiness.checklist.knees && readiness.checklist.feet,
      checklist: readiness.checklist,
    };

    return {
      personDetected: activeLandmarks !== null,
      multiplePeopleDetected: false,
      isFullyVisible: readiness.ready,
      headVisible: readiness.checklist.head,
      feetVisible: readiness.checklist.feet,
      tooClose: false,
      tooFar: false,
      lightingGood: true,
      cameraStable: true,
      segments,
      checklist: readiness.checklist,
      message: readiness.message,
      missingPartsUzbek: readiness.missingPartsUzbek,
    };
  }

  public generateTestLandmarks(timestampMs: number, exerciseType: string): PoseLandmarks {
    const sinVal = Math.max(0, Math.sin((timestampMs % 3000) / 3000 * Math.PI * 2));
    const kY = exerciseType === 'SQUAT' ? sinVal * 0.15 : 0;
    const eX = exerciseType === 'PUSH_UP' ? sinVal * 0.16 : 0;

    const lm = (x: number, y: number): NormalizedLandmark => ({ x, y, z: 0, visibility: 0.95 });
    const landmarks: PoseLandmarks = new Array(33).fill(null).map(() => lm(0.5, 0.5));

    landmarks[PoseLandmarkIndex.NOSE] = lm(0.5, 0.15 + kY);
    landmarks[PoseLandmarkIndex.LEFT_EYE] = lm(0.48, 0.13 + kY);
    landmarks[PoseLandmarkIndex.RIGHT_EYE] = lm(0.52, 0.13 + kY);
    landmarks[PoseLandmarkIndex.LEFT_SHOULDER] = lm(0.40, 0.30 + kY);
    landmarks[PoseLandmarkIndex.RIGHT_SHOULDER] = lm(0.60, 0.30 + kY);
    landmarks[PoseLandmarkIndex.LEFT_ELBOW] = lm(0.32 - eX, 0.45 + kY);
    landmarks[PoseLandmarkIndex.RIGHT_ELBOW] = lm(0.68 + eX, 0.45 + kY);
    landmarks[PoseLandmarkIndex.LEFT_WRIST] = lm(0.38, 0.60);
    landmarks[PoseLandmarkIndex.RIGHT_WRIST] = lm(0.62, 0.60);
    landmarks[PoseLandmarkIndex.LEFT_HIP] = lm(0.42, 0.55 + kY);
    landmarks[PoseLandmarkIndex.RIGHT_HIP] = lm(0.58, 0.55 + kY);
    landmarks[PoseLandmarkIndex.LEFT_KNEE] = lm(0.42 - sinVal * 0.12, 0.72);
    landmarks[PoseLandmarkIndex.RIGHT_KNEE] = lm(0.58 + sinVal * 0.12, 0.72);
    landmarks[PoseLandmarkIndex.LEFT_ANKLE] = lm(0.42, 0.90);
    landmarks[PoseLandmarkIndex.RIGHT_ANKLE] = lm(0.58, 0.90);

    return landmarks;
  }
}
