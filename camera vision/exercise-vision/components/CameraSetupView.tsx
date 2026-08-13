// ODAT — Fullscreen Camera Setup View with Cyber Side Skeleton HUD

import React, { useState, useEffect, useRef } from 'react';
import { CheckCircle2, AlertTriangle, RefreshCw, ArrowLeft, Terminal, XCircle, Camera } from 'lucide-react';
import { ODATCard } from '../../components/common/ODATCard';
import { ODATButton } from '../../components/common/ODATButton';
import { PoseDetector, CameraFrameStatus } from '../PoseDetector';
import { CyberSideSkeletonGuide } from './CyberSideSkeletonGuide';
import { DirectBodySkeletonOverlay } from './DirectBodySkeletonOverlay';
import { Mission } from '../../types';
import { DetailedBodyChecklist, EXERCISE_LANDMARK_REQUIREMENTS, BODY_PART_LABELS_UZ, BodyPartKey, PoseLandmarks } from '../types';

interface CameraSetupViewProps {
  mission: Mission;
  onStart: (stream: MediaStream | null) => void;
  onCancel: () => void;
}

export const CameraSetupView: React.FC<CameraSetupViewProps> = ({
  mission,
  onStart,
  onCancel,
}) => {
  const [permissionState, setPermissionState] = useState<'IDLE' | 'GRANTED' | 'DENIED'>('IDLE');
  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('user');
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [showDebug, setShowDebug] = useState(false);
  const [lastLandmarks, setLastLandmarks] = useState<PoseLandmarks | null>(null);
  const [rawConfidences, setRawConfidences] = useState<Record<BodyPartKey, number>>({
    HEAD: 0,
    SHOULDERS: 0,
    ELBOWS: 0,
    HANDS: 0,
    HIPS: 0,
    KNEES: 0,
    FEET: 0,
  });

  const emptyChecklist: DetailedBodyChecklist = {
    head: false,
    shoulders: false,
    elbows: false,
    hands: false,
    hips: false,
    knees: false,
    feet: false,
  };

  const [frameStatus, setFrameStatus] = useState<CameraFrameStatus>({
    personDetected: false,
    multiplePeopleDetected: false,
    isFullyVisible: false,
    headVisible: false,
    feetVisible: false,
    tooClose: false,
    tooFar: false,
    lightingGood: true,
    cameraStable: true,
    segments: {
      headDetected: false,
      shouldersDetected: false,
      armsDetected: false,
      coreDetected: false,
      legsDetected: false,
      checklist: emptyChecklist,
    },
    checklist: emptyChecklist,
    message: 'Tanangiz va kerakli a’zolarni kameraga to‘liq ko‘rsating...',
    missingPartsUzbek: [],
  });

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const poseDetectorRef = useRef<PoseDetector>(PoseDetector.getInstance());

  const exerciseType = mission.exerciseType || 'SQUAT';
  const requiredParts = EXERCISE_LANDMARK_REQUIREMENTS[exerciseType] || EXERCISE_LANDMARK_REQUIREMENTS.SQUAT;

  const requestCameraPermission = async (targetFacing: 'user' | 'environment' = facingMode) => {
    try {
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }

      let mediaStream: MediaStream;
      try {
        mediaStream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: targetFacing }, width: { ideal: 640 }, height: { ideal: 480 } },
          audio: false,
        });
      } catch (e1) {
        try {
          mediaStream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: targetFacing },
            audio: false,
          });
        } catch (e2) {
          mediaStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
        }
      }

      setStream(mediaStream);
      setPermissionState('GRANTED');
      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
        videoRef.current.play().catch(() => {});
      }
    } catch (err) {
      console.warn('Camera permission denied or unavailable:', err);
      setPermissionState('DENIED');
    }
  };

  const toggleCameraFacing = () => {
    const nextFacing = facingMode === 'user' ? 'environment' : 'user';
    setFacingMode(nextFacing);
    if (poseDetectorRef.current) {
      poseDetectorRef.current.resetDetectionState();
    }
    requestCameraPermission(nextFacing);
  };

  useEffect(() => {
    requestCameraPermission(facingMode);
    return () => {
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }
    };
  }, []);

  useEffect(() => {
    if (permissionState === 'GRANTED' && videoRef.current && stream) {
      videoRef.current.srcObject = stream;
      videoRef.current.play().catch(e => console.warn('Video play error:', e));
    }
  }, [permissionState, stream]);

  // Screen Lock/Unlock & App Resume Auto-Recovery Handler
  useEffect(() => {
    const handleResume = async () => {
      if (document.visibilityState === 'visible' && permissionState === 'GRANTED') {
        console.log('[ODAT Setup] App resumed from lock screen/background');

        if (poseDetectorRef.current) {
          poseDetectorRef.current.resetDetectionState();
        }

        const tracks = stream ? stream.getTracks() : [];
        const isStreamDead = tracks.length === 0 || tracks.some(t => t.readyState === 'ended' || !t.enabled);

        if (isStreamDead) {
          console.log('[ODAT Setup] Re-opening camera stream after unlock...');
          requestCameraPermission(facingMode);
        } else if (videoRef.current) {
          if (videoRef.current.paused) {
            console.log('[ODAT Setup] Re-playing paused video stream after unlock...');
            videoRef.current.play().catch(e => console.warn('Video play error:', e));
          }
        }
      }
    };

    document.addEventListener('visibilitychange', handleResume);
    window.addEventListener('focus', handleResume);

    return () => {
      document.removeEventListener('visibilitychange', handleResume);
      window.removeEventListener('focus', handleResume);
    };
  }, [permissionState, stream, facingMode]);

  // Real-time zero-lag MediaPipe pose detection loop with overlap guard & 30 FPS pacing
  useEffect(() => {
    if (permissionState !== 'GRANTED') return;

    let animFrameId: number;
    let running = true;
    let isDetecting = false; // Prevents async WebGL promise overlap & GPU congestion
    let lastUiTs = 0;
    let lastInferenceTs = 0;
    const UI_THROTTLE_MS = 350;
    const INFERENCE_INTERVAL_MS = 33;

    const loop = async (ts: number) => {
      if (!running) return;

      const video = videoRef.current;
      if (video && video.readyState >= 2 && !video.paused && !isDetecting && (ts - lastInferenceTs >= INFERENCE_INTERVAL_MS)) {
        isDetecting = true;
        lastInferenceTs = ts;
        try {
          const landmarks = await poseDetectorRef.current.detectFromVideo(video);
          setLastLandmarks(landmarks);

          if (ts - lastUiTs >= UI_THROTTLE_MS) {
            lastUiTs = ts;
            const status = poseDetectorRef.current.analyzeFrameEnvironment(landmarks, null, exerciseType);
            const confs = poseDetectorRef.current.getRawLandmarkConfidences(landmarks);
            setFrameStatus(status);
            setRawConfidences(confs);
          }
        } catch (err) {
          console.warn('Detection error:', err);
        } finally {
          isDetecting = false;
        }
      } else if (!video || video.readyState < 2 || video.paused) {
        if (ts - lastUiTs >= UI_THROTTLE_MS) {
          lastUiTs = ts;
          const status = poseDetectorRef.current.analyzeFrameEnvironment(null, null, exerciseType);
          setFrameStatus(status);
        }
      }

      animFrameId = requestAnimationFrame(loop);
    };

    animFrameId = requestAnimationFrame(loop);
    return () => {
      running = false;
      cancelAnimationFrame(animFrameId);
    };
  }, [permissionState, mission, exerciseType]);

  if (permissionState === 'DENIED') {
    return (
      <div style={{
        position: 'fixed',
        inset: 0,
        background: '#090a0f',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px',
        color: '#ffffff',
        zIndex: 1000,
      }}>
        <Camera size={48} color="#ff3366" style={{ marginBottom: '16px' }} />
        <h2 style={{ fontSize: '18px', fontWeight: '800', marginBottom: '8px' }}>Kamera ruxsati berilmadi</h2>
        <p style={{ fontSize: '13px', color: '#a0aec0', textAlign: 'center', marginBottom: '24px', maxWidth: '320px' }}>
          Harakatlarni avtomatik sanash uchun kameraga ruxsat bering.
        </p>
        <ODATButton variant="primary" onClick={() => requestCameraPermission(facingMode)}>
          Kameraga ruxsat berish
        </ODATButton>
      </div>
    );
  }

  const isPartAvailable = (part: BodyPartKey): boolean => {
    switch (part) {
      case 'HEAD': return frameStatus.checklist.head;
      case 'SHOULDERS': return frameStatus.checklist.shoulders;
      case 'ELBOWS': return frameStatus.checklist.elbows;
      case 'HANDS': return frameStatus.checklist.hands;
      case 'HIPS': return frameStatus.checklist.hips;
      case 'KNEES': return frameStatus.checklist.knees;
      case 'FEET': return frameStatus.checklist.feet;
    }
  };

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      width: '100vw',
      height: '100vh',
      zIndex: 1000,
      background: '#000000',
      overflow: 'hidden',
    }}>
      {/* FULLSCREEN CAMERA PREVIEW (Clean Real Video Feed) */}
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted
        style={{
          width: '100vw',
          height: '100vh',
          objectFit: 'cover',
          transform: facingMode === 'user' ? 'scaleX(-1)' : 'none',
          position: 'absolute',
          inset: 0,
        }}
      />

      {/* Direct On-Person Body Skeleton Canvas Overlay */}
      <DirectBodySkeletonOverlay
        landmarks={lastLandmarks}
        checklist={frameStatus.checklist}
        isMirrored={facingMode === 'user'}
        videoElement={videoRef.current}
        missingPartsUzbek={frameStatus.missingPartsUzbek}
        poseDetector={poseDetectorRef.current}
      />

      {/* TOP FLOATING HEADER HUD */}
      <div style={{
        position: 'absolute',
        top: '16px',
        left: '16px',
        right: '16px',
        zIndex: 20,
        background: 'rgba(9, 10, 15, 0.82)',
        backdropFilter: 'blur(12px)',
        borderRadius: '16px',
        padding: '12px 18px',
        border: '1px solid var(--border-bright)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.5)',
      }}>
        <button
          onClick={onCancel}
          style={{ background: 'none', border: 'none', color: '#ffffff', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px' }}
        >
          <ArrowLeft size={18} />
          <span style={{ fontSize: '13px', fontWeight: '700' }}>Orqaga</span>
        </button>

        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: '10px', color: 'var(--brand-cyan)', fontWeight: '900', letterSpacing: '1px', textTransform: 'uppercase' }}>
            KAMERA TEKSHIRUVI ({exerciseType})
          </div>
          <div style={{ fontSize: '14px', fontWeight: '800', color: '#ffffff' }}>
            {mission.title}
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            onClick={toggleCameraFacing}
            title="Kamerani almashtirish (Oldi / Orqa)"
            style={{
              background: 'rgba(0, 229, 255, 0.15)',
              color: 'var(--brand-cyan)',
              border: '1px solid var(--brand-cyan)',
              padding: '6px 10px',
              borderRadius: '8px',
              fontSize: '11px',
              fontWeight: '800',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              boxShadow: '0 0 10px rgba(0,229,255,0.3)',
            }}
          >
            <RefreshCw size={14} />
            <span style={{ display: 'inline' }}>{facingMode === 'user' ? 'Orqa' : 'Oldi'}</span>
          </button>

          <button
            onClick={() => setShowDebug(!showDebug)}
            style={{
              background: showDebug ? 'var(--brand-cyan)' : 'rgba(255, 255, 255, 0.08)',
              color: showDebug ? '#090a0f' : '#ffffff',
              border: 'none',
              padding: '6px 8px',
              borderRadius: '8px',
              fontSize: '10px',
              fontWeight: '800',
              cursor: 'pointer',
            }}
          >
            <Terminal size={14} />
          </button>
        </div>
      </div>

      {/* Development Diagnostic Debug Panel */}
      {showDebug && (
        <div style={{
          position: 'absolute',
          top: '76px',
          left: '16px',
          zIndex: 15,
          background: 'rgba(9, 10, 15, 0.92)',
          border: '1px solid var(--brand-cyan)',
          borderRadius: '12px',
          padding: '8px 12px',
          fontSize: '10px',
          fontFamily: 'monospace',
          color: '#00e5ff',
          display: 'flex',
          gap: '10px',
          backdropFilter: 'blur(10px)',
        }}>
          <div>HEAD: <b>{rawConfidences.HEAD.toFixed(2)}</b></div>
          <div>SHOULDERS: <b>{rawConfidences.SHOULDERS.toFixed(2)}</b></div>
          <div>HIPS: <b>{rawConfidences.HIPS.toFixed(2)}</b></div>
          <div>KNEES: <b>{rawConfidences.KNEES.toFixed(2)}</b></div>
          <div>FEET: <b>{rawConfidences.FEET.toFixed(2)}</b></div>
        </div>
      )}

      {/* CENTER STATUS FEEDBACK BADGE */}
      <div style={{
        position: 'absolute',
        top: showDebug ? '120px' : '82px',
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 10,
        background: frameStatus.isFullyVisible ? 'rgba(0, 229, 255, 0.95)' : 'rgba(255, 51, 102, 0.95)',
        color: frameStatus.isFullyVisible ? '#090a0f' : '#ffffff',
        padding: '10px 20px',
        borderRadius: '9999px',
        fontSize: '13px',
        fontWeight: '900',
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        backdropFilter: 'blur(12px)',
        boxShadow: '0 4px 24px rgba(0, 0, 0, 0.6)',
        whiteSpace: 'nowrap',
      }}>
        {frameStatus.isFullyVisible ? <CheckCircle2 size={18} /> : <AlertTriangle size={18} />}
        <span>{frameStatus.message}</span>
      </div>

      {/* BOTTOM FLOATING REAL-TIME BODY ANALYSIS PANEL */}
      <div style={{
        position: 'absolute',
        bottom: '80px',
        left: '16px',
        right: '16px',
        maxWidth: '440px',
        margin: '0 auto',
        zIndex: 10,
        background: 'rgba(18, 22, 32, 0.9)',
        backdropFilter: 'blur(16px)',
        borderRadius: '20px',
        padding: '14px 16px',
        border: '1px solid var(--border-bright)',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.6)',
      }}>
        <div style={{ fontSize: '11px', fontWeight: '800', color: 'var(--brand-cyan)', textTransform: 'uppercase', letterSpacing: '0.8px', marginBottom: '10px' }}>
          REAL-TIME TANA QISMLARI TAHLILI ({exerciseType})
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '6px' }}>
          {requiredParts.map(partKey => {
            const available = isPartAvailable(partKey);
            const label = BODY_PART_LABELS_UZ[partKey];
            return (
              <div key={partKey} style={{
                background: available ? 'rgba(0, 229, 255, 0.12)' : 'rgba(255, 51, 102, 0.12)',
                padding: '8px 4px',
                borderRadius: '10px',
                textAlign: 'center',
                border: available ? '1px solid var(--brand-cyan)' : '1px solid #ff3366',
              }}>
                <div style={{ fontSize: '10px', color: available ? '#ffffff' : '#ff4d4d', fontWeight: '700' }}>
                  {label.split(' ')[0]}
                </div>
                <div style={{ fontSize: '12px', fontWeight: '900', marginTop: '2px', color: available ? 'var(--brand-cyan)' : '#ff3366' }}>
                  {available ? '🟢 ✓' : '🔴 ✕'}
                </div>
              </div>
            );
          })}
        </div>
      </div>



      {/* BOTTOM FLOATING START BUTTON */}
      <div style={{
        position: 'absolute',
        bottom: '16px',
        left: '16px',
        right: '16px',
        maxWidth: '440px',
        margin: '0 auto',
        zIndex: 10,
      }}>
        <ODATButton
          variant="primary"
          size="lg"
          fullWidth
          disabled={false}
          onClick={() => onStart(stream)}
          style={{
            height: '52px',
            fontSize: '16px',
            fontWeight: '900',
            borderRadius: '14px',
            boxShadow: '0 0 25px rgba(0, 229, 255, 0.6)',
          }}
        >
          BOSHLASH ▶
        </ODATButton>
      </div>
    </div>
  );
};
