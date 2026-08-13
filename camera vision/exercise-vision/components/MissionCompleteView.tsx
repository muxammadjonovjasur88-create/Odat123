// ODAT — Verified Mission Completion Overlay

import React, { useEffect } from 'react';
import confetti from 'canvas-confetti';
import { CheckCircle2, Flame, Award, ArrowRight, ShieldCheck } from 'lucide-react';
import { ODATCard } from '../../components/common/ODATCard';
import { ODATButton } from '../../components/common/ODATButton';
import { Mission, ExerciseTelemetry } from '../../types';

interface MissionCompleteViewProps {
  mission: Mission;
  telemetry: ExerciseTelemetry | null;
  pointsEarned: number;
  currentStreak: number;
  onFinish: () => void;
}

export const MissionCompleteView: React.FC<MissionCompleteViewProps> = ({
  mission,
  telemetry,
  pointsEarned,
  currentStreak,
  onFinish,
}) => {
  useEffect(() => {
    // Trigger celebration confetti
    confetti({
      particleCount: 80,
      spread: 70,
      origin: { y: 0.6 },
    });
  }, []);

  const totalReps = telemetry?.repetitions || mission.targetRepetitions || mission.targetValue || 20;

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      zIndex: 1200,
      background: 'rgba(9, 10, 15, 0.95)',
      backdropFilter: 'blur(16px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '20px',
    }}>
      <ODATCard glow={true} style={{ width: '100%', maxWidth: '420px', textAlign: 'center', background: 'var(--surface-1)' }}>
        
        {/* Verification Icon Badge */}
        <div style={{
          width: '72px',
          height: '72px',
          borderRadius: '50%',
          background: 'rgba(0, 229, 255, 0.15)',
          color: 'var(--brand-cyan)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          margin: '0 auto 16px auto',
          boxShadow: '0 0 30px rgba(0, 229, 255, 0.4)',
        }}>
          <CheckCircle2 size={40} />
        </div>

        <div style={{ fontSize: '11px', fontWeight: '800', color: 'var(--brand-cyan)', letterSpacing: '1px', textTransform: 'uppercase', marginBottom: '4px' }}>
          VERIFIED BY ODAT VISION
        </div>

        <h2 style={{ fontSize: '24px', fontWeight: '900', color: '#ffffff', marginBottom: '8px' }}>
          MISSION COMPLETE!
        </h2>

        <p style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '20px' }}>
          "{mission.title}" muvaffaqiyatli bajarildi va kamera orqali tasdiqlandi.
        </p>

        {/* Telemetry Summary Box */}
        <div style={{
          background: 'var(--surface-2)',
          borderRadius: '14px',
          padding: '16px',
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: '12px',
          marginBottom: '20px',
        }}>
          <div style={{ textAlign: 'center', borderRight: '1px solid var(--border-subtle)' }}>
            <div style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: '600' }}>TAKRORLASH</div>
            <div style={{ fontSize: '20px', fontWeight: '900', color: '#ffffff', marginTop: '2px' }}>
              {totalReps} / {mission.targetValue || 20}
            </div>
            <div style={{ fontSize: '10px', color: 'var(--brand-cyan)', marginTop: '2px', fontWeight: '700' }}>
              ✓ Exercise verified
            </div>
          </div>

          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: '600' }}>MUKOFOT</div>
            <div style={{ fontSize: '20px', fontWeight: '900', color: 'var(--status-warning)', marginTop: '2px' }}>
              +{pointsEarned || mission.pointReward} PT
            </div>
            <div style={{ fontSize: '10px', color: 'var(--status-warning)', marginTop: '2px', fontWeight: '700', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '2px' }}>
              <Flame size={12} /> {currentStreak} kun Streak
            </div>
          </div>
        </div>

        {/* Action Finish Button */}
        <ODATButton variant="primary" size="lg" fullWidth icon={<ArrowRight size={18} />} onClick={onFinish}>
          Yakunlash
        </ODATButton>
      </ODATCard>
    </div>
  );
};
