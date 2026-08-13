// ODAT — Real-Time Instant Clean Skeleton Canvas Overlay (0ms zero-lag, no overlapping polygon clutter)

import React, { useEffect, useRef } from 'react';
import { DetailedBodyChecklist, PoseLandmarks, PoseLandmarkIndex } from '../types';
import { PoseDetector } from '../PoseDetector';

interface DirectBodySkeletonOverlayProps {
  landmarks: PoseLandmarks | null;
  checklist: DetailedBodyChecklist;
  isMirrored: boolean;
  videoElement?: HTMLVideoElement | null;
  missingPartsUzbek?: string[];
  poseDetector?: PoseDetector | null;
}

export const DirectBodySkeletonOverlay: React.FC<DirectBodySkeletonOverlayProps> = ({
  landmarks: propLandmarks,
  checklist,
  isMirrored,
  videoElement,
  poseDetector,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d', { alpha: true });
    if (!ctx) return;

    let animFrameId: number;
    let active = true;

    const render = () => {
      if (!active) return;

      const rect = canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      const width = rect.width;
      const height = rect.height;

      if (canvas.width !== width * dpr || canvas.height !== height * dpr) {
        canvas.width = width * dpr;
        canvas.height = height * dpr;
      }

      ctx.save();
      ctx.scale(dpr, dpr);
      ctx.clearRect(0, 0, width, height);

      // Read landmarks directly from poseDetector memory ref or propLandmarks
      const activeLandmarks = (poseDetector && typeof poseDetector.getLastLandmarks === 'function')
        ? (poseDetector.getLastLandmarks() || propLandmarks)
        : propLandmarks;

      if (!activeLandmarks || activeLandmarks.length === 0) {
        ctx.restore();
        animFrameId = requestAnimationFrame(render);
        return;
      }

      let scale = 1;
      let offsetX = 0;
      let offsetY = 0;
      let vidW = width;
      let vidH = height;

      const activeVid = videoElement || (canvas.parentElement ? canvas.parentElement.querySelector('video') : null);

      if (activeVid && activeVid.videoWidth && activeVid.videoHeight) {
        vidW = activeVid.videoWidth;
        vidH = activeVid.videoHeight;
        const videoRatio = vidW / vidH;
        const canvasRatio = width / height;

        if (canvasRatio > videoRatio) {
          scale = width / vidW;
          offsetY = (height - vidH * scale) / 2;
        } else {
          scale = height / vidH;
          offsetX = (width - vidW * scale) / 2;
        }
      }

      const mapLm = (idx: number) => {
        const lm = activeLandmarks[idx];
        if (!lm) return null;

        const normX = isMirrored ? 1 - lm.x : lm.x;
        const normY = lm.y;

        const px = normX * vidW * scale + offsetX;
        const py = normY * vidH * scale + offsetY;
        return { x: px, y: py, vis: lm.visibility ?? 1.0 };
      };

      const GREEN = '#00e676';
      const CYAN = '#00e5ff';
      const strokeColor = GREEN;

      const drawLine = (p1: { x: number; y: number } | null, p2: { x: number; y: number } | null, color = strokeColor, widthPx = 5) => {
        if (!p1 || !p2) return;
        ctx.beginPath();
        ctx.moveTo(p1.x, p1.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.strokeStyle = color;
        ctx.lineWidth = widthPx;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.stroke();
      };

      const drawJointNode = (p: { x: number; y: number } | null, color = strokeColor, radius = 5) => {
        if (!p) return;
        ctx.beginPath();
        ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.fill();

        ctx.beginPath();
        ctx.arc(p.x, p.y, radius + 1.5, 0, Math.PI * 2);
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.2;
        ctx.stroke();
      };

      // Extract structural body keypoints
      const nose = mapLm(PoseLandmarkIndex.NOSE);
      const lShoulder = mapLm(PoseLandmarkIndex.LEFT_SHOULDER);
      const rShoulder = mapLm(PoseLandmarkIndex.RIGHT_SHOULDER);

      const lElbow = mapLm(PoseLandmarkIndex.LEFT_ELBOW);
      const rElbow = mapLm(PoseLandmarkIndex.RIGHT_ELBOW);
      const lWrist = mapLm(PoseLandmarkIndex.LEFT_WRIST);
      const rWrist = mapLm(PoseLandmarkIndex.RIGHT_WRIST);

      const lHip = mapLm(PoseLandmarkIndex.LEFT_HIP);
      const rHip = mapLm(PoseLandmarkIndex.RIGHT_HIP);

      const lKnee = mapLm(PoseLandmarkIndex.LEFT_KNEE);
      const rKnee = mapLm(PoseLandmarkIndex.RIGHT_KNEE);
      const lAnkle = mapLm(PoseLandmarkIndex.LEFT_ANKLE);
      const rAnkle = mapLm(PoseLandmarkIndex.RIGHT_ANKLE);

      // --- CLEAN HIGH-CONTRAST SKELETON BONES ---

      // Head to Shoulders
      if (nose && lShoulder) drawLine(nose, lShoulder, strokeColor, 4.5);
      if (nose && rShoulder) drawLine(nose, rShoulder, strokeColor, 4.5);

      // Shoulders & Torso
      if (lShoulder && rShoulder) drawLine(lShoulder, rShoulder, strokeColor, 5);
      if (lShoulder && lHip) drawLine(lShoulder, lHip, strokeColor, 5);
      if (rShoulder && rHip) drawLine(rShoulder, rHip, strokeColor, 5);
      if (lHip && rHip) drawLine(lHip, rHip, strokeColor, 5);

      // Left Arm
      if (lShoulder && lElbow) drawLine(lShoulder, lElbow, strokeColor, 5);
      if (lElbow && lWrist) drawLine(lElbow, lWrist, strokeColor, 4.5);

      // Right Arm
      if (rShoulder && rElbow) drawLine(rShoulder, rElbow, strokeColor, 5);
      if (rElbow && rWrist) drawLine(rElbow, rWrist, strokeColor, 4.5);

      // Left Leg
      if (lHip && lKnee) drawLine(lHip, lKnee, strokeColor, 5);
      if (lKnee && lAnkle) drawLine(lKnee, lAnkle, strokeColor, 4.5);

      // Right Leg
      if (rHip && rKnee) drawLine(rHip, rKnee, strokeColor, 5);
      if (rKnee && rAnkle) drawLine(rKnee, rAnkle, strokeColor, 4.5);

      // --- CRISP COMPACT JOINT NODES ---
      if (nose) drawJointNode(nose, CYAN, 4.5);
      if (lShoulder) drawJointNode(lShoulder, strokeColor, 5);
      if (rShoulder) drawJointNode(rShoulder, strokeColor, 5);
      if (lElbow) drawJointNode(lElbow, strokeColor, 5);
      if (rElbow) drawJointNode(rElbow, strokeColor, 5);
      if (lWrist) drawJointNode(lWrist, CYAN, 4.5);
      if (rWrist) drawJointNode(rWrist, CYAN, 4.5);
      if (lHip) drawJointNode(lHip, strokeColor, 5);
      if (rHip) drawJointNode(rHip, strokeColor, 5);
      if (lKnee) drawJointNode(lKnee, strokeColor, 5);
      if (rKnee) drawJointNode(rKnee, strokeColor, 5);
      if (lAnkle) drawJointNode(lAnkle, CYAN, 4.5);
      if (rAnkle) drawJointNode(rAnkle, CYAN, 4.5);

      ctx.restore();
      animFrameId = requestAnimationFrame(render);
    };

    animFrameId = requestAnimationFrame(render);
    return () => {
      active = false;
      cancelAnimationFrame(animFrameId);
    };
  }, [propLandmarks, checklist, isMirrored, videoElement, poseDetector]);

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'absolute',
        inset: 0,
        width: '100vw',
        height: '100vh',
        pointerEvents: 'none',
        zIndex: 15,
      }}
    />
  );
};
