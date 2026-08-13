// ODAT — Off-Thread Web Worker for MediaPipe Pose Landmarker

import { FilesetResolver, PoseLandmarker } from '@mediapipe/tasks-vision';

let poseLandmarker: any = null;
let isInitializing = false;

self.onmessage = async (e: MessageEvent) => {
  const { type, payload } = e.data;

  if (type === 'INIT') {
    if (poseLandmarker || isInitializing) return;
    isInitializing = true;
    const { wasmPath, modelPath, delegate } = payload;
    try {
      let resolver: any;
      let landmarkerClass: any = PoseLandmarker;

      try {
        resolver = await FilesetResolver.forVisionTasks(wasmPath);
      } catch (e1) {
        // Fallback for worker scope CDN vision bundle
        if (typeof (self as any).importScripts === 'function') {
          (self as any).importScripts('https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.22/wasm/vision_bundle.js');
          const vision = (self as any).tasksVision || (self as any).vision;
          resolver = await vision.FilesetResolver.forVisionTasks(wasmPath);
          landmarkerClass = vision.PoseLandmarker;
        } else {
          throw e1;
        }
      }

      poseLandmarker = await landmarkerClass.createFromOptions(resolver, {
        baseOptions: {
          modelAssetPath: modelPath,
          delegate: delegate || 'GPU',
        },
        runningMode: 'VIDEO',
        numPoses: 1,
        minPoseDetectionConfidence: 0.01,
        minPosePresenceConfidence: 0.01,
        minTrackingConfidence: 0.01,
      });
      self.postMessage({ type: 'INIT_DONE', success: true });
    } catch (err: any) {
      console.warn('[PoseWorker] Worker init failed:', err);
      self.postMessage({ type: 'INIT_DONE', success: false, error: String(err) });
    } finally {
      isInitializing = false;
    }
  } else if (type === 'DETECT') {
    const { imageBitmap, timestampMs } = payload;
    if (!poseLandmarker) {
      if (imageBitmap && typeof imageBitmap.close === 'function') {
        imageBitmap.close();
      }
      self.postMessage({ type: 'DETECT_RESULT', landmarks: null, timestampMs });
      return;
    }

    try {
      const result = poseLandmarker.detectForVideo(imageBitmap, timestampMs);
      if (imageBitmap && typeof imageBitmap.close === 'function') {
        imageBitmap.close();
      }
      const landmarks = (result && result.landmarks && result.landmarks.length > 0) ? result.landmarks[0] : null;
      self.postMessage({ type: 'DETECT_RESULT', landmarks, timestampMs });
    } catch (err) {
      if (imageBitmap && typeof imageBitmap.close === 'function') {
        imageBitmap.close();
      }
      self.postMessage({ type: 'DETECT_RESULT', landmarks: null, timestampMs, error: String(err) });
    }
  }
};
