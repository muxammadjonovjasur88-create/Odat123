import React, { useEffect } from 'react';
import confetti from 'canvas-confetti';
import { Mission, RunSessionTelemetry } from '../../types';
import { Trophy, Flame, Zap, Award, CheckCircle, Navigation, MapPin, Sparkles } from 'lucide-react';

interface RunTerritoryCompleteViewProps {
  mission: Mission;
  telemetry: RunSessionTelemetry;
  pointsEarned: number;
  currentStreak: number;
  onFinish: () => void;
}

export const RunTerritoryCompleteView: React.FC<RunTerritoryCompleteViewProps> = ({
  mission,
  telemetry,
  pointsEarned,
  currentStreak,
  onFinish,
}) => {
  useEffect(() => {
    // Fire festive celebration confetti
    try {
      confetti({
        particleCount: 120,
        spread: 80,
        origin: { y: 0.6 },
        colors: ['#00F3FF', '#39FF14', '#FF007F', '#FFB703'],
      });
    } catch (e) {
      console.warn('Confetti launch error', e);
    }
  }, []);

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m} daq ${s} sek`;
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: '#070a10',
        zIndex: 10000,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px',
        fontFamily: 'Inter, sans-serif',
        overflowY: 'auto',
      }}
    >
      <div
        style={{
          maxWidth: '480px',
          width: '100%',
          backgroundColor: 'rgba(12, 17, 28, 0.95)',
          border: '1px solid rgba(0, 243, 255, 0.3)',
          borderRadius: '28px',
          padding: '28px 24px',
          boxShadow: '0 0 50px rgba(0, 243, 255, 0.25)',
          textAlign: 'center',
          backdropFilter: 'blur(16px)',
        }}
      >
        {/* Animated Trophy Icon */}
        <div
          style={{
            width: '80px',
            height: '80px',
            borderRadius: '50%',
            backgroundColor: 'rgba(0, 243, 255, 0.15)',
            border: '2px solid #00F3FF',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 16px auto',
            boxShadow: '0 0 24px rgba(0, 243, 255, 0.5)',
          }}
        >
          <Trophy size={42} color="#00F3FF" />
        </div>

        <div style={{ fontSize: '0.8rem', color: '#00F3FF', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '1px' }}>
          MISSIYA BAJARILDI!
        </div>

        <h2 style={{ fontSize: '1.4rem', fontWeight: 900, color: '#fff', margin: '6px 0 16px 0' }}>
          {mission.title}
        </h2>

        {/* Reward & Streak Pill */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: '12px', marginBottom: '24px' }}>
          <div
            style={{
              backgroundColor: 'rgba(57, 255, 20, 0.15)',
              border: '1px solid #39FF14',
              borderRadius: '20px',
              padding: '6px 14px',
              color: '#39FF14',
              fontWeight: 800,
              fontSize: '0.9rem',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
            }}
          >
            <Sparkles size={16} /> +{pointsEarned} POINT
          </div>

          <div
            style={{
              backgroundColor: 'rgba(255, 183, 3, 0.15)',
              border: '1px solid #ffb703',
              borderRadius: '20px',
              padding: '6px 14px',
              color: '#ffb703',
              fontWeight: 800,
              fontSize: '0.9rem',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
            }}
          >
            <Flame size={16} /> {currentStreak} Kun Streak
          </div>
        </div>

        {/* Detailed Workout Telemetry Grid */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(2, 1fr)',
            gap: '12px',
            marginBottom: '24px',
            textAlign: 'left',
          }}
        >
          <div style={{ backgroundColor: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '16px', padding: '14px' }}>
            <div style={{ fontSize: '0.7rem', color: '#8b9bb4', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Navigation size={14} color="#00F3FF" /> JAMI MASOFA
            </div>
            <div style={{ fontSize: '1.3rem', fontWeight: 900, color: '#fff', marginTop: '4px' }}>
              {telemetry.distanceKm.toFixed(2)} <span style={{ fontSize: '0.8rem', color: '#aaa' }}>km</span>
            </div>
          </div>

          <div style={{ backgroundColor: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '16px', padding: '14px' }}>
            <div style={{ fontSize: '0.7rem', color: '#8b9bb4', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Flame size={14} color="#ff4d6d" /> YO‘QOTILGAN KALORIYA
            </div>
            <div style={{ fontSize: '1.3rem', fontWeight: 900, color: '#ff4d6d', marginTop: '4px' }}>
              {telemetry.caloriesBurned} <span style={{ fontSize: '0.8rem', color: '#aaa' }}>kcal</span>
            </div>
          </div>

          <div style={{ backgroundColor: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '16px', padding: '14px' }}>
            <div style={{ fontSize: '0.7rem', color: '#8b9bb4', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Zap size={14} color="#ffb703" /> O‘RTACHA PACE
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: '#ffb703', marginTop: '4px' }}>
              {telemetry.avgPaceMinKm}
            </div>
          </div>

          <div style={{ backgroundColor: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '16px', padding: '14px' }}>
            <div style={{ fontSize: '0.7rem', color: '#8b9bb4', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Award size={14} color="#39FF14" /> BO‘YALGAN HUDUDLAR
            </div>
            <div style={{ fontSize: '1.1rem', fontWeight: 900, color: '#39FF14', marginTop: '4px' }}>
              🎨 {telemetry.polygonsCapturedCount || 0} to‘liq davra
            </div>
          </div>
        </div>

        {telemetry.polygonsCapturedCount > 0 && (
          <div
            style={{
              backgroundColor: 'rgba(57, 255, 20, 0.1)',
              border: '1px dashed #39FF1488',
              borderRadius: '14px',
              padding: '10px 14px',
              marginBottom: '24px',
              fontSize: '0.85rem',
              color: '#39FF14',
              fontWeight: 700,
            }}
          >
            🎨 Siz <b>{telemetry.polygonsCapturedCount} ta</b> davrani to‘liq yopib, hududni o‘z ravingizga bo‘yadingiz (+{telemetry.polygonsCapturedCount * 50} Bonus Points)!
          </div>
        )}

        <button
          onClick={onFinish}
          style={{
            width: '100%',
            padding: '16px',
            borderRadius: '16px',
            background: 'linear-gradient(135deg, #00F3FF 0%, #0077FF 100%)',
            border: 'none',
            color: '#000',
            fontWeight: 900,
            fontSize: '1rem',
            cursor: 'pointer',
            boxShadow: '0 6px 24px rgba(0, 243, 255, 0.4)',
          }}
        >
          TAYYOR / BOSH SAHIFAGA QAYTISH
        </button>
      </div>
    </div>
  );
};
