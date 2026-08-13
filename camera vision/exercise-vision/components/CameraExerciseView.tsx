// ODAT — Fullscreen Camera Exercise Active Tracking View with Cyber Side Skeleton HUD

import React, { useState, useEffect, useRef } from 'react';
import { Pause, Play, X, AlertTriangle, RefreshCw } from 'lucide-react';
import { ODATCard } from '../../components/common/ODATCard';
import { ODATButton } from '../../components/common/ODATButton';
import { ExerciseSessionManager } from '../ExerciseSessionManager';
import { PoseDetector, CameraFrameStatus } from '../PoseDetector';
import { CyberSideSkeletonGuide } from './CyberSideSkeletonGuide';
import { DirectBodySkeletonOverlay } from './DirectBodySkeletonOverlay';
import { Mission } from '../../types';
import { PoseLandmarks } from '../types';

interface CameraExerciseViewProps {
  mission: Mission;
  existingProgress?: any;
  stream: MediaStream | null;
  onCompleteSession: (telemetry: any) => void;
  onCancel?: () => void;
  onCancelSession?: () => void;
}

export const CameraExerciseView: React.FC<CameraExerciseViewProps> = ({
  mission,
  stream,
  onCompleteSession,
  onCancel,
  onCancelSession,
}) => {
  const [countdown, setCountdown] = useState<number | null>(3);
  const [isPaused, setIsPaused] = useState(false);
  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('user');
  const [activeStream, setActiveStream] = useState<MediaStream | null>(stream);
  const [currentReps, setCurrentReps] = useState(0);
  const [targetReps] = useState(20);
  const [durationSeconds, setDurationSeconds] = useState(0);
  const [feedbackMessage, setFeedbackMessage] = useState('Mashqni boshlashga tayyorlaning...');
  const [formStatus, setFormStatus] = useState<'GOOD' | 'WARNING' | 'ERROR' | 'INVALID'>('GOOD');

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const managerRef = useRef<ExerciseSessionManager | null>(null);
  const poseDetectorRef = useRef<PoseDetector>(PoseDetector.getInstance());

  const handleCancel = onCancelSession || onCancel || (() => {});
  const exerciseType = mission.exerciseType || 'SQUAT';
  const [lastLandmarks, setLastLandmarks] = useState<PoseLandmarks | null>(null);

  const [envStatus, setEnvStatus] = useState<CameraFrameStatus>({
    personDetected: true,
    multiplePeopleDetected: false,
    isFullyVisible: true,
    headVisible: true,
    feetVisible: true,
    tooClose: false,
    tooFar: false,
    lightingGood: true,
    cameraStable: true,
    segments: {
      headDetected: true,
      shouldersDetected: true,
      armsDetected: true,
      coreDetected: true,
      legsDetected: true,
      checklist: { head: true, shoulders: true, elbows: true, hands: true, hips: true, knees: true, feet: true },
    },
    checklist: { head: true, shoulders: true, elbows: true, hands: true, hips: true, knees: true, feet: true },
    message: 'Tayyorlaning...',
    missingPartsUzbek: [],
  });

  // Initialize ExerciseSessionManager
  useEffect(() => {
    managerRef.current = new ExerciseSessionManager({
      id: `session_${Date.now()}`,
      userId: 'user_1',
      missionId: mission.id,
      exerciseType: exerciseType as any,
      targetRepetitions: targetReps,
      status: 'STARTED',
      startedAt: new Date().toISOString(),
    }, poseDetectorRef.current);

    return () => {
      managerRef.current = null;
    };
  }, [mission, exerciseType, targetReps]);

  const toggleCameraFacing = async () => {
    const nextFacing = facingMode === 'user' ? 'environment' : 'user';
    setFacingMode(nextFacing);
    if (poseDetectorRef.current) {
      poseDetectorRef.current.resetDetectionState();
    }
    try {
      if (activeStream) {
        activeStream.getTracks().forEach(t => t.stop());
      }

      let mediaStream: MediaStream;
      try {
        mediaStream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: nextFacing }, width: { ideal: 640 }, height: { ideal: 480 } },
          audio: false,
        });
      } catch (e1) {
        try {
          mediaStream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: nextFacing },
            audio: false,
          });
        } catch (e2) {
          mediaStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
        }
      }
      setActiveStream(mediaStream);
      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
        videoRef.current.play().catch(e => console.warn('Video play error:', e));
      }
    } catch (err) {
      console.warn('Failed to switch camera:', err);
    }
  };

  // Bind video stream
  useEffect(() => {
    if (videoRef.current && activeStream) {
      videoRef.current.srcObject = activeStream;
      videoRef.current.play().catch(e => console.warn('Video play error:', e));
    }
  }, [activeStream]);

  // Screen Lock/Unlock & App Resume Auto-Recovery Handler
  useEffect(() => {
    const handleResume = async () => {
      if (document.visibilityState === 'visible') {
        console.log('[ODAT] App resumed from lock screen/background');

        if (poseDetectorRef.current) {
          poseDetectorRef.current.resetDetectionState();
        }

        const tracks = activeStream ? activeStream.getTracks() : [];
        const isStreamDead = tracks.length === 0 || tracks.some(t => t.readyState === 'ended' || !t.enabled);

        if (isStreamDead) {
          console.log('[ODAT] Re-opening camera stream after unlock...');
          try {
            const newStream = await navigator.mediaDevices.getUserMedia({
              video: { facingMode: facingMode, width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 60 } },
              audio: false,
            });
            setActiveStream(newStream);
            if (videoRef.current) {
              videoRef.current.srcObject = newStream;
              await videoRef.current.play();
            }
          } catch (err) {
            console.warn('[ODAT] Failed to restart camera on resume:', err);
          }
        } else if (videoRef.current) {
          if (videoRef.current.paused) {
            console.log('[ODAT] Re-playing paused video stream after unlock...');
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
  }, [activeStream, facingMode]);



  // Snappy fast countdown timer logic (3...2...1... -> Start in ~1.2s total)
  useEffect(() => {
    if (countdown === null) return;

    if (countdown > 0) {
      const timer = setTimeout(() => setCountdown(countdown - 1), 350);
      return () => clearTimeout(timer);
    } else if (countdown === 0) {
      const timer = setTimeout(() => {
        setCountdown(null);
        if (managerRef.current) {
          managerRef.current.startExercising();
        }
      }, 250);
      return () => clearTimeout(timer);
    }
  }, [countdown]);

  // Real-time zero-lag MediaPipe detection & Exercise Session Manager loop
  useEffect(() => {
    let animFrameId: number;
    let running = true;
    let isDetecting = false; // Overlap guard flag prevents WebGL GPU congestion
    let lastUiTs = 0;
    let lastInferenceTs = 0;
    const UI_THROTTLE_MS = 250;
    const INFERENCE_INTERVAL_MS = 33; // 30 FPS inference pacing eliminates Android GPU decoder stalls

    const loop = async (ts: number) => {
      if (!running) return;
      const video = videoRef.current;
      if (video && video.readyState >= 2 && !video.paused && !isDetecting && (ts - lastInferenceTs >= INFERENCE_INTERVAL_MS)) {
        isDetecting = true;
        lastInferenceTs = ts;
        try {
          const landmarks = await poseDetectorRef.current.detectFromVideo(video);
          const activeLms = landmarks || poseDetectorRef.current.getLastLandmarks();
          if (activeLms) {
            setLastLandmarks(activeLms);
          }

          if (managerRef.current) {
            const { evalResult, envStatus: status, isTargetReached } = managerRef.current.processFrame(activeLms, ts);

            // Update repetition count & duration
            setCurrentReps(evalResult.currentCount);
            setDurationSeconds(managerRef.current.compileTelemetry().durationSeconds);

            if (ts - lastUiTs >= UI_THROTTLE_MS) {
              lastUiTs = ts;
              setEnvStatus(status);
              setFormStatus(evalResult.formStatus);
              setFeedbackMessage(evalResult.feedback);
            }

            if (isTargetReached) {
              running = false;
              const telemetry = managerRef.current.compileTelemetry();
              managerRef.current.markCompleted();
              onCompleteSession(telemetry);
              return;
            }
          }
        } catch (err) {
          console.warn('Detection error:', err);
        } finally {
          isDetecting = false;
        }
      }
      animFrameId = requestAnimationFrame(loop);
    };

    animFrameId = requestAnimationFrame(loop);
    return () => {
      running = false;
      cancelAnimationFrame(animFrameId);
    };
  }, [exerciseType, onCompleteSession]);

  const togglePause = () => {
    setIsPaused(!isPaused);
  };

  const progressPercent = Math.min(100, Math.round((currentReps / targetReps) * 100));

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
          zIndex: 1,
        }}
      />

      {/* Direct On-Person Body Skeleton Canvas Overlay */}
      <DirectBodySkeletonOverlay
        landmarks={lastLandmarks}
        checklist={envStatus.checklist}
        isMirrored={facingMode === 'user'}
        videoElement={videoRef.current}
        missingPartsUzbek={envStatus.missingPartsUzbek}
        poseDetector={poseDetectorRef.current}
      />

      {/* Countdown Overlay (3...2...1...START - Fast & Clickable to Skip) */}
      {countdown !== null && (
        <div
          onClick={() => {
            setCountdown(null);
            if (managerRef.current) {
              managerRef.current.startExercising();
            }
          }}
          style={{
            position: 'absolute',
            inset: 0,
            zIndex: 50,
            background: 'rgba(9, 10, 15, 0.4)',
            backdropFilter: 'blur(3px)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
          }}
        >
          <div style={{
            fontSize: countdown === 0 ? '64px' : '110px',
            fontWeight: '900',
            color: 'var(--brand-cyan)',
            textShadow: '0 0 40px rgba(0, 229, 255, 0.9), 0 0 80px rgba(0, 229, 255, 0.5)',
            animation: 'pulse 0.35s ease-in-out infinite alternate',
            userSelect: 'none',
          }}>
            {countdown === 0 ? 'BOSHLADIK!' : countdown}
          </div>
          <div style={{ fontSize: '14px', fontWeight: '800', color: '#ffffff', marginTop: '12px', userSelect: 'none' }}>
            Pozitsiyada turing • O‘tkazib yuborish uchun bosing
          </div>
        </div>
      )}

      {/* Pause Modal Overlay */}
      {isPaused && (
        <div style={{
          position: 'absolute',
          inset: 0,
          zIndex: 40,
          background: 'rgba(9, 10, 15, 0.85)',
          backdropFilter: 'blur(12px)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '24px',
        }}>
          <ODATCard style={{ maxWidth: '380px', width: '100%', textAlign: 'center', background: 'var(--surface-1)' }}>
            <AlertTriangle size={48} color="var(--brand-cyan)" style={{ margin: '0 auto 16px auto' }} />
            <h3 style={{ fontSize: '20px', fontWeight: '800', color: '#ffffff', marginBottom: '8px' }}>
              Mashq To‘xtatildi
            </h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '24px' }}>
              {envStatus.message || 'Davom etish uchun kameraga qayting.'}
            </p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <ODATButton variant="primary" icon={<Play size={18} />} fullWidth onClick={togglePause}>
                Davom ettirish
              </ODATButton>
              <ODATButton variant="secondary" icon={<X size={18} />} fullWidth onClick={handleCancel}>
                Chiqish
              </ODATButton>
            </div>
          </ODATCard>
        </div>
      )}

      {/* TOP FLOATING COUNTER & PROGRESS HUD */}
      <div style={{
        position: 'absolute',
        top: '16px',
        left: '16px',
        right: '16px',
        zIndex: 20,
        background: 'rgba(9, 10, 15, 0.85)',
        backdropFilter: 'blur(12px)',
        borderRadius: '18px',
        padding: '12px 18px',
        border: '1px solid var(--border-bright)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.6)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            fontSize: '32px',
            fontWeight: '900',
            color: 'var(--brand-cyan)',
            lineHeight: 1,
            textShadow: '0 0 16px rgba(0, 229, 255, 0.5)',
          }}>
            {currentReps}
            <span style={{ fontSize: '16px', color: 'var(--text-secondary)', fontWeight: '600', marginLeft: '4px' }}>
              / {targetReps}
            </span>
          </div>

          <div style={{ borderLeft: '1px solid var(--border-subtle)', paddingLeft: '12px' }}>
            <div style={{ fontSize: '10px', color: 'var(--text-secondary)', fontWeight: '700', textTransform: 'uppercase' }}>
              Vaqt
            </div>
            <div style={{ fontSize: '14px', fontWeight: '800', color: '#ffffff' }}>
              {Math.floor(durationSeconds / 60)}:{(durationSeconds % 60).toString().padStart(2, '0')}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            onClick={toggleCameraFacing}
            title="Kamerani almashtirish (Oldi / Orqa)"
            style={{
              height: '40px',
              padding: '0 12px',
              borderRadius: '20px',
              background: 'rgba(0, 229, 255, 0.15)',
              border: '1px solid var(--brand-cyan)',
              color: 'var(--brand-cyan)',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              cursor: 'pointer',
              fontSize: '12px',
              fontWeight: '800',
              boxShadow: '0 0 10px rgba(0, 229, 255, 0.3)',
            }}
          >
            <RefreshCw size={16} />
            <span>{facingMode === 'user' ? 'Orqa' : 'Oldi'}</span>
          </button>

          <button
            onClick={togglePause}
            style={{
              width: '40px',
              height: '40px',
              borderRadius: '50%',
              background: 'var(--surface-2)',
              border: '1px solid var(--border-bright)',
              color: '#ffffff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
            }}
          >
            {isPaused ? <Play size={20} /> : <Pause size={20} />}
          </button>
        </div>
      </div>

      {/* FEEDBACK BANNER */}
      <div style={{
        position: 'absolute',
        top: '86px',
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 10,
        background: envStatus.isFullyVisible ? 'rgba(0, 229, 255, 0.95)' : 'rgba(255, 51, 102, 0.95)',
        color: envStatus.isFullyVisible ? '#090a0f' : '#ffffff',
        padding: '8px 20px',
        borderRadius: '9999px',
        fontSize: '12px',
        fontWeight: '900',
        backdropFilter: 'blur(10px)',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.6)',
        whiteSpace: 'nowrap',
      }}>
        {envStatus.message || feedbackMessage}
      </div>

      {/* BOTTOM FLOATING PROGRESS BAR */}
      <div style={{
        position: 'absolute',
        bottom: '16px',
        left: '16px',
        right: '16px',
        maxWidth: '440px',
        margin: '0 auto',
        zIndex: 10,
        background: 'rgba(18, 22, 32, 0.85)',
        backdropFilter: 'blur(12px)',
        borderRadius: '12px',
        padding: '8px 12px',
        border: '1px solid var(--border-bright)',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', fontWeight: '800', marginBottom: '4px' }}>
          <span style={{ color: 'var(--text-secondary)' }}>Bajarilish progressi</span>
          <span style={{ color: 'var(--brand-cyan)' }}>{progressPercent}%</span>
        </div>
        <div style={{ width: '100%', height: '8px', background: 'rgba(255, 255, 255, 0.1)', borderRadius: '4px', overflow: 'hidden' }}>
          <div style={{
            width: `${progressPercent}%`,
            height: '100%',
            background: 'linear-gradient(90deg, var(--brand-cyan), #00ff88)',
            borderRadius: '4px',
            transition: 'width 0.3s ease',
          }} />
        </div>
      </div>
    </div>
  );
};
