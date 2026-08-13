// ODAT — Futuristic Live Skeleton HUD Guide
// Renders a real-time skeleton that mirrors MediaPipe landmark positions

import React, { useMemo } from 'react';
import { DetailedBodyChecklist, PoseLandmarks, PoseLandmarkIndex } from '../types';

interface CyberSideSkeletonGuideProps {
  checklist: DetailedBodyChecklist;
  landmarks: PoseLandmarks | null;
}

// SVG canvas dimensions for the skeleton HUD
const W = 70;
const H = 150;

/**
 * Maps a normalized landmark (0..1) to SVG canvas coordinates.
 * Mirrors X because camera is front-facing (mirrored).
 */
function lmToSvg(lm: { x: number; y: number } | null | undefined, fallback: { x: number; y: number }): { x: number; y: number } {
  if (!lm) return { x: fallback.x * W, y: fallback.y * H };
  // Mirror X so skeleton faces same direction as person
  return {
    x: (1 - lm.x) * W,
    y: lm.y * H,
  };
}

export const CyberSideSkeletonGuide: React.FC<CyberSideSkeletonGuideProps> = ({ checklist, landmarks }) => {
  const cyan = '#00e5ff';
  const red = '#ff3366';
  const gray = '#334155';

  const headColor = checklist.head ? cyan : red;
  const shoulderColor = checklist.shoulders ? cyan : red;
  const armColor = (checklist.elbows || checklist.hands) ? cyan : (checklist.shoulders ? gray : red);
  const coreColor = checklist.hips ? cyan : red;
  const legColor = (checklist.knees || checklist.feet) ? cyan : (checklist.hips ? gray : red);
  const kneeColor = checklist.knees ? cyan : (checklist.hips ? gray : red);
  const footColor = checklist.feet ? cyan : gray;

  // Fallback static positions (standing pose, normalized 0..1)
  const fallbacks = {
    nose:     { x: 0.5, y: 0.08 },
    lShoulder:{ x: 0.35, y: 0.26 },
    rShoulder:{ x: 0.65, y: 0.26 },
    lElbow:   { x: 0.22, y: 0.42 },
    rElbow:   { x: 0.78, y: 0.42 },
    lWrist:   { x: 0.25, y: 0.58 },
    rWrist:   { x: 0.75, y: 0.58 },
    lHip:     { x: 0.40, y: 0.55 },
    rHip:     { x: 0.60, y: 0.55 },
    lKnee:    { x: 0.38, y: 0.74 },
    rKnee:    { x: 0.62, y: 0.74 },
    lAnkle:   { x: 0.38, y: 0.92 },
    rAnkle:   { x: 0.62, y: 0.92 },
  };

  // Get SVG coordinates from real landmarks or fallbacks
  const pts = useMemo(() => {
    const get = (idx: number, fb: { x: number; y: number }) => {
      const lm = landmarks?.[idx];
      // Only use real landmark if it has reasonable visibility
      if (lm && (lm.visibility ?? 1) > 0.3) {
        return lmToSvg(lm, fb);
      }
      return lmToSvg(null, fb);
    };

    return {
      nose:      get(PoseLandmarkIndex.NOSE, fallbacks.nose),
      lShoulder: get(PoseLandmarkIndex.LEFT_SHOULDER, fallbacks.lShoulder),
      rShoulder: get(PoseLandmarkIndex.RIGHT_SHOULDER, fallbacks.rShoulder),
      lElbow:    get(PoseLandmarkIndex.LEFT_ELBOW, fallbacks.lElbow),
      rElbow:    get(PoseLandmarkIndex.RIGHT_ELBOW, fallbacks.rElbow),
      lWrist:    get(PoseLandmarkIndex.LEFT_WRIST, fallbacks.lWrist),
      rWrist:    get(PoseLandmarkIndex.RIGHT_WRIST, fallbacks.rWrist),
      lHip:      get(PoseLandmarkIndex.LEFT_HIP, fallbacks.lHip),
      rHip:      get(PoseLandmarkIndex.RIGHT_HIP, fallbacks.rHip),
      lKnee:     get(PoseLandmarkIndex.LEFT_KNEE, fallbacks.lKnee),
      rKnee:     get(PoseLandmarkIndex.RIGHT_KNEE, fallbacks.rKnee),
      lAnkle:    get(PoseLandmarkIndex.LEFT_ANKLE, fallbacks.lAnkle),
      rAnkle:    get(PoseLandmarkIndex.RIGHT_ANKLE, fallbacks.rAnkle),
    };
  }, [landmarks]);

  // Head center: midpoint of eyes or nose position
  const headCx = pts.nose.x;
  const headCy = pts.nose.y;
  const headR = 7;

  // Neck connects head to shoulder midpoint
  const neckX = (pts.lShoulder.x + pts.rShoulder.x) / 2;
  const neckY = (pts.lShoulder.y + pts.rShoulder.y) / 2;

  // Spine goes from shoulder midpoint to hip midpoint
  const hipMidX = (pts.lHip.x + pts.rHip.x) / 2;
  const hipMidY = (pts.lHip.y + pts.rHip.y) / 2;

  // Glow filter ID
  const glowId = 'skeletonGlow';

  return (
    <div style={{
      position: 'absolute',
      top: '70px',
      right: '12px',
      zIndex: 20,
      background: 'rgba(9, 10, 15, 0.88)',
      backdropFilter: 'blur(14px)',
      border: `1px solid ${checklist.head || checklist.shoulders ? cyan + '66' : '#334155'}`,
      borderRadius: '16px',
      padding: '10px 8px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: '6px',
      boxShadow: checklist.head ? `0 0 18px rgba(0,229,255,0.25), 0 8px 32px rgba(0,0,0,0.6)` : '0 8px 32px rgba(0,0,0,0.6)',
      pointerEvents: 'none',
      transition: 'box-shadow 0.3s ease',
    }}>
      <div style={{
        fontSize: '8px',
        fontWeight: '900',
        color: checklist.head ? cyan : '#64748b',
        letterSpacing: '1.5px',
        textTransform: 'uppercase',
        transition: 'color 0.3s ease',
      }}>
        BODY HUD
      </div>

      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} fill="none" style={{ overflow: 'visible' }}>
        <defs>
          <filter id={glowId} x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="1.5" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        {/* === BONES (Lines connecting joints) === */}

        {/* Neck */}
        <line x1={headCx} y1={headCy + headR} x2={neckX} y2={neckY}
          stroke={shoulderColor} strokeWidth="2.5" strokeLinecap="round" filter={`url(#${glowId})`} />

        {/* Collar / Shoulder line */}
        <line x1={pts.lShoulder.x} y1={pts.lShoulder.y} x2={pts.rShoulder.x} y2={pts.rShoulder.y}
          stroke={shoulderColor} strokeWidth="3" strokeLinecap="round" filter={`url(#${glowId})`} />

        {/* Spine */}
        <line x1={neckX} y1={neckY} x2={hipMidX} y2={hipMidY}
          stroke={coreColor} strokeWidth="2.5" strokeLinecap="round" filter={`url(#${glowId})`} />

        {/* Hip line */}
        <line x1={pts.lHip.x} y1={pts.lHip.y} x2={pts.rHip.x} y2={pts.rHip.y}
          stroke={coreColor} strokeWidth="3" strokeLinecap="round" filter={`url(#${glowId})`} />

        {/* Left Arm: shoulder → elbow → wrist */}
        <line x1={pts.lShoulder.x} y1={pts.lShoulder.y} x2={pts.lElbow.x} y2={pts.lElbow.y}
          stroke={armColor} strokeWidth="2.5" strokeLinecap="round" filter={`url(#${glowId})`} />
        <line x1={pts.lElbow.x} y1={pts.lElbow.y} x2={pts.lWrist.x} y2={pts.lWrist.y}
          stroke={armColor} strokeWidth="2" strokeLinecap="round" filter={`url(#${glowId})`} />

        {/* Right Arm: shoulder → elbow → wrist */}
        <line x1={pts.rShoulder.x} y1={pts.rShoulder.y} x2={pts.rElbow.x} y2={pts.rElbow.y}
          stroke={armColor} strokeWidth="2.5" strokeLinecap="round" filter={`url(#${glowId})`} />
        <line x1={pts.rElbow.x} y1={pts.rElbow.y} x2={pts.rWrist.x} y2={pts.rWrist.y}
          stroke={armColor} strokeWidth="2" strokeLinecap="round" filter={`url(#${glowId})`} />

        {/* Left Leg: hip → knee → ankle */}
        <line x1={pts.lHip.x} y1={pts.lHip.y} x2={pts.lKnee.x} y2={pts.lKnee.y}
          stroke={legColor} strokeWidth="3" strokeLinecap="round" filter={`url(#${glowId})`} />
        <line x1={pts.lKnee.x} y1={pts.lKnee.y} x2={pts.lAnkle.x} y2={pts.lAnkle.y}
          stroke={kneeColor} strokeWidth="2.5" strokeLinecap="round" filter={`url(#${glowId})`} />

        {/* Right Leg: hip → knee → ankle */}
        <line x1={pts.rHip.x} y1={pts.rHip.y} x2={pts.rKnee.x} y2={pts.rKnee.y}
          stroke={legColor} strokeWidth="3" strokeLinecap="round" filter={`url(#${glowId})`} />
        <line x1={pts.rKnee.x} y1={pts.rKnee.y} x2={pts.rAnkle.x} y2={pts.rAnkle.y}
          stroke={kneeColor} strokeWidth="2.5" strokeLinecap="round" filter={`url(#${glowId})`} />

        {/* === HEAD === */}
        <circle
          cx={headCx} cy={headCy} r={headR}
          stroke={headColor} strokeWidth="2.5"
          fill={checklist.head ? 'rgba(0,229,255,0.18)' : 'rgba(255,51,102,0.15)'}
          filter={`url(#${glowId})`}
          style={{ transition: 'stroke 0.2s ease, fill 0.2s ease' }}
        />
        {/* Nose dot */}
        <circle cx={headCx} cy={headCy} r={2} fill={headColor} />

        {/* === JOINT DOTS === */}
        {/* Shoulders */}
        <circle cx={pts.lShoulder.x} cy={pts.lShoulder.y} r="3.5" fill={shoulderColor} filter={`url(#${glowId})`} />
        <circle cx={pts.rShoulder.x} cy={pts.rShoulder.y} r="3.5" fill={shoulderColor} filter={`url(#${glowId})`} />

        {/* Elbows */}
        <circle cx={pts.lElbow.x} cy={pts.lElbow.y} r="2.8" fill={armColor} filter={`url(#${glowId})`} />
        <circle cx={pts.rElbow.x} cy={pts.rElbow.y} r="2.8" fill={armColor} filter={`url(#${glowId})`} />

        {/* Wrists */}
        <circle cx={pts.lWrist.x} cy={pts.lWrist.y} r="2.2" fill={armColor} />
        <circle cx={pts.rWrist.x} cy={pts.rWrist.y} r="2.2" fill={armColor} />

        {/* Hips */}
        <circle cx={pts.lHip.x} cy={pts.lHip.y} r="3.5" fill={coreColor} filter={`url(#${glowId})`} />
        <circle cx={pts.rHip.x} cy={pts.rHip.y} r="3.5" fill={coreColor} filter={`url(#${glowId})`} />

        {/* Knees */}
        <circle cx={pts.lKnee.x} cy={pts.lKnee.y} r="3.5" fill={kneeColor} filter={`url(#${glowId})`} />
        <circle cx={pts.rKnee.x} cy={pts.rKnee.y} r="3.5" fill={kneeColor} filter={`url(#${glowId})`} />

        {/* Ankles */}
        <circle cx={pts.lAnkle.x} cy={pts.lAnkle.y} r="2.8" fill={footColor} />
        <circle cx={pts.rAnkle.x} cy={pts.rAnkle.y} r="2.8" fill={footColor} />
      </svg>
    </div>
  );
};
