import React, { useState, useEffect, useRef } from 'react';
import { Mission, UserProfile, TerritoryPolygon, RunSessionTelemetry } from '../../types';
import { TerritoryMapView } from './TerritoryMapView';
import { Play, Pause, Square, Navigation, Zap, Flame, Award, ShieldAlert, MapPin, AlertTriangle } from 'lucide-react';
import { db } from '../../services/db';
import { Geolocation } from '@capacitor/geolocation';

interface RunTerritoryModalProps {
  mission: Mission;
  user: UserProfile;
  onFinishSession: (telemetry: RunSessionTelemetry) => void;
  onCancel: () => void;
}

// Haversine formula to compute distance in km between 2 lat/lng points
function calcHaversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

export const RunTerritoryModal: React.FC<RunTerritoryModalProps> = ({
  mission,
  user,
  onFinishSession,
  onCancel,
}) => {
  const isWalking = mission.exerciseType === 'WALKING' || mission.title.toLowerCase().includes('yurish');
  
  // Navigation & Real GPS State
  const [currentPos, setCurrentPos] = useState<[number, number]>([41.2995, 69.2401]);
  const [path, setPath] = useState<Array<[number, number]>>([]);
  const [gpsActive, setGpsActive] = useState<boolean>(true);
  const [gpsError, setGpsError] = useState<string | null>(null);
  const [antiCheatWarning, setAntiCheatWarning] = useState<string | null>(null);

  // Closed Loop Polygons Captured
  const [polygons, setPolygons] = useState<TerritoryPolygon[]>(() => db.getSavedPolygons());
  const [capturedLoopCount, setCapturedLoopCount] = useState<number>(0);
  const [notification, setNotification] = useState<string | null>(null);

  // Workout State: IDLE -> RUNNING -> PAUSED
  const [workoutState, setWorkoutState] = useState<'IDLE' | 'RUNNING' | 'PAUSED'>('IDLE');
  const [elapsedSeconds, setElapsedSeconds] = useState<number>(0);
  const [distanceKm, setDistanceKm] = useState<number>(0);

  const watchIdRef = useRef<number | null>(null);
  const lastPosTimeRef = useRef<number>(Date.now());

  // Timer Counter
  useEffect(() => {
    if (workoutState !== 'RUNNING') return;
    const timer = setInterval(() => {
      setElapsedSeconds(prev => prev + 1);
    }, 1000);
    return () => clearInterval(timer);
  }, [workoutState]);

  // Request Native Location Permission & Watch Position
  const requestGpsAndStart = async () => {
    try {
      setGpsError(null);
      // First request native Capacitor permission prompt
      const permResult = await Geolocation.requestPermissions();
      if (permResult.location === 'denied') {
        setGpsError('GPS-dan foydalanish uchun qurilmangizda ruxsat berishingiz kerak.');
        return;
      }

      // Fetch high accuracy location
      const pos = await Geolocation.getCurrentPosition({ enableHighAccuracy: true, timeout: 15000 });
      const initLat = pos.coords.latitude;
      const initLng = pos.coords.longitude;
      const initPos: [number, number] = [initLat, initLng];
      setCurrentPos(initPos);
      if (path.length === 0) setPath([initPos]);
      setGpsActive(true);
    } catch (err: any) {
      console.warn('Native Geolocation error, falling back to HTML5 navigator:', err);
      if ('geolocation' in navigator) {
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            const initLat = pos.coords.latitude;
            const initLng = pos.coords.longitude;
            const initPos: [number, number] = [initLat, initLng];
            setCurrentPos(initPos);
            if (path.length === 0) setPath([initPos]);
            setGpsActive(true);
          },
          (e) => {
            setGpsError('GPS joylashuvini olish imkoni bo‘lmadi. Telefoningizda GPS (Location) yoqilganligini tekshiring.');
          },
          { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
      } else {
        setGpsError('GPS funksiyasi qo‘llab-quvvatlanmaydi.');
      }
    }
  };

  useEffect(() => {
    requestGpsAndStart();
  }, []);

  // AUTOMATIC REAL GPS WATCHER
  useEffect(() => {
    if (!('geolocation' in navigator)) return;

    // Watch position continuously
    watchIdRef.current = navigator.geolocation.watchPosition(
      (pos) => {
        const newLat = pos.coords.latitude;
        const newLng = pos.coords.longitude;
        const newPos: [number, number] = [newLat, newLng];

        // Always update current location display
        setCurrentPos(newPos);

        // Only record path and telemetry when workout is RUNNING!
        if (workoutState !== 'RUNNING') return;

        const now = Date.now();
        const timeDiffSec = (now - lastPosTimeRef.current) / 1000;

        setCurrentPos(prev => {
          const deltaKm = calcHaversineDistance(prev[0], prev[1], newLat, newLng);

          // Ignore stationary GPS jitter (< 4 meters)
          if (deltaKm < 0.004) return prev;

          // ANTI-CHEAT CHECK: Speed validation (max 25 km/h for running/walking)
          const speedKmh = timeDiffSec > 0 ? (deltaKm / (timeDiffSec / 3600)) : 0;
          if (speedKmh > 25) {
            setAntiCheatWarning('⚠️ TEZLIK CHEKLOVI BUZILDI! (Avtomobil yoki soxta GPS aniqlandi)');
            setTimeout(() => setAntiCheatWarning(null), 4000);
            return prev;
          }

          lastPosTimeRef.current = now;
          setDistanceKm(d => +(d + deltaKm).toFixed(3));
          
          setPath(existingPath => {
            const nextPath = [...existingPath, newPos];
            
            // CHECK CLOSED LOOP POLYGON CONQUEST MECHANIC
            if (nextPath.length >= 5) {
              for (let i = 0; i < nextPath.length - 4; i++) {
                const loopStartDist = calcHaversineDistance(newLat, newLng, nextPath[i][0], nextPath[i][1]);
                if (loopStartDist < 0.03) { // within ~30m
                  const loopPoints = nextPath.slice(i);
                  const newPoly: TerritoryPolygon = {
                    id: `poly-${Date.now()}`,
                    ownerId: user.id,
                    ownerName: user.displayName || 'Siz',
                    ownerColor: '#00F3FF',
                    points: loopPoints,
                    capturedAt: new Date().toISOString(),
                  };

                  setPolygons(prevPolys => {
                    const updated = [...prevPolys, newPoly];
                    db.savePolygons(updated);
                    return updated;
                  });

                  setCapturedLoopCount(c => c + 1);
                  setNotification('🎉 DAVRA YOPILDI! HUDUD TO‘LIQ BO‘YALDI VA EGALLANDI!');
                  setTimeout(() => setNotification(null), 4000);
                  break;
                }
              }
            }

            return nextPath;
          });

          return newPos;
        });
      },
      (err) => {
        setGpsError(`GPS Xatosi: ${err.message}`);
      },
      { enableHighAccuracy: true, maximumAge: 1000, timeout: 10000 }
    );

    return () => {
      if (watchIdRef.current !== null) {
        navigator.geolocation.clearWatch(watchIdRef.current);
      }
    };
  }, [workoutState]);

  // Telemetry Calculations
  // Calories: Walking ~ 45 kcal/km, Running ~ 65 kcal/km
  const kcalPerKm = isWalking ? 45 : 65;
  const caloriesBurned = Math.round(distanceKm * kcalPerKm);

  // Speed (km/h)
  const hours = elapsedSeconds / 3600;
  const avgSpeedKmh = hours > 0 && distanceKm > 0 ? +(distanceKm / hours).toFixed(1) : 0;

  // Pace (min/km)
  const minutes = elapsedSeconds / 60;
  let avgPaceMinKm = '0\'00"';
  if (distanceKm > 0.05) {
    const paceVal = minutes / distanceKm;
    const paceMin = Math.floor(paceVal);
    const paceSec = Math.round((paceVal - paceMin) * 60);
    avgPaceMinKm = `${paceMin}'${paceSec < 10 ? '0' : ''}${paceSec}"`;
  }

  // Format Elapsed Time MM:SS
  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}`;
  };

  // Recenter GPS Location handler
  const handleRecenterLocation = () => {
    if (!('geolocation' in navigator)) return;
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const realLat = pos.coords.latitude;
        const realLng = pos.coords.longitude;
        const realPos: [number, number] = [realLat, realLng];
        setCurrentPos(realPos);
        if (path.length === 0) setPath([realPos]);
      },
      (err) => {
        alert('GPS Joylashuv olinmadi: ' + err.message);
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
    );
  };

  const targetKm = mission.targetValue || (isWalking ? 2 : 3);

  const handleFinish = () => {
    if (distanceKm < targetKm * 0.8 && distanceKm < 0.3) {
      const confirmIncomplete = window.confirm(
        `⚠️ SIZ BELGILANGAN MASOFANI BOSIB O‘TMADINGIZ!\n\n` +
        `Talab etilgan masofa: ${targetKm} km\n` +
        `Bosib o'tilgan masofa: ${distanceKm.toFixed(2)} km\n\n` +
        `Missiya bajarilmadi va POINT berilmaydi. Mashg'ulotdan chiqishni xohlaysizmi?`
      );
      if (confirmIncomplete) {
        onCancel();
      }
      return;
    }

    const telemetry: RunSessionTelemetry = {
      exerciseType: isWalking ? 'WALKING' : 'RUNNING',
      distanceKm: +distanceKm.toFixed(2),
      durationSeconds: elapsedSeconds,
      caloriesBurned,
      avgSpeedKmh,
      avgPaceMinKm,
      polygonsCapturedCount: capturedLoopCount,
      polygons: polygons.map(p => p.points),
      path,
      timestamp: new Date().toISOString(),
    };
    onFinishSession(telemetry);
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: '#07090e',
        zIndex: 9999,
        display: 'flex',
        flexDirection: 'column',
        fontFamily: 'Inter, sans-serif',
      }}
    >
      {/* Top Header HUD Bar */}
      <div
        style={{
          padding: '14px 16px',
          backgroundColor: 'rgba(12, 16, 26, 0.95)',
          borderBottom: '1px solid rgba(0, 243, 255, 0.2)',
          backdropFilter: 'blur(10px)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <div>
          <div style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: '#00F3FF', fontWeight: 700, letterSpacing: '1px', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Navigation size={14} color="#39FF14" /> {isWalking ? '🚶‍♂️ Shaharni Egallash (Yurish)' : '🏃‍♂️ Hudud Egallash (Yugurish)'}
          </div>
          <div style={{ fontSize: '1.05rem', fontWeight: 800, color: '#fff' }}>
            {mission.title} ({targetKm} km target)
          </div>
        </div>

        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            onClick={handleRecenterLocation}
            title="Mening Joyim"
            style={{
              backgroundColor: 'rgba(57, 255, 20, 0.15)',
              border: '1px solid #39FF14',
              color: '#39FF14',
              padding: '6px 12px',
              borderRadius: '20px',
              fontSize: '0.8rem',
              fontWeight: 700,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
            }}
          >
            🎯 Mening Joyim
          </button>

          <button
            onClick={onCancel}
            style={{
              backgroundColor: 'rgba(255, 255, 255, 0.08)',
              border: '1px solid rgba(255, 255, 255, 0.15)',
              color: '#aaa',
              padding: '6px 14px',
              borderRadius: '20px',
              fontSize: '0.8rem',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Bekor qilish
          </button>
        </div>
      </div>

      {/* GPS Error & Permission Request Toast */}
      {gpsError && (
        <div
          style={{
            backgroundColor: '#ffb703',
            color: '#000',
            padding: '10px 16px',
            fontSize: '0.82rem',
            fontWeight: 800,
            textAlign: 'center',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '8px',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <AlertTriangle size={18} /> {gpsError}
          </div>
          <button
            onClick={requestGpsAndStart}
            style={{
              backgroundColor: '#000',
              color: '#fff',
              border: 'none',
              borderRadius: '8px',
              padding: '6px 12px',
              fontWeight: 800,
              cursor: 'pointer',
              whiteSpace: 'nowrap',
            }}
          >
            ⚙️ GPS-ni Yoqish & Ruxsat
          </button>
        </div>
      )}

      {/* Anti-Cheat Warning Toast */}
      {antiCheatWarning && (
        <div
          style={{
            backgroundColor: '#ff0055',
            color: '#fff',
            padding: '8px 16px',
            fontSize: '0.8rem',
            fontWeight: 800,
            textAlign: 'center',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px',
          }}
        >
          <ShieldAlert size={16} /> {antiCheatWarning}
        </div>
      )}

      {/* Main Map View Canvas */}
      <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
        <TerritoryMapView
          user={user}
          currentPos={currentPos}
          path={path}
          polygons={polygons}
          notification={notification}
        />

        {/* Floating Telemetry Stats Widget */}
        <div
          style={{
            position: 'absolute',
            top: '16px',
            left: '16px',
            right: '16px',
            backgroundColor: 'rgba(10, 14, 23, 0.88)',
            border: '1px solid rgba(0, 243, 255, 0.25)',
            borderRadius: '16px',
            padding: '12px 16px',
            backdropFilter: 'blur(12px)',
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.5)',
            display: 'grid',
            gridTemplateColumns: 'repeat(4, 1fr)',
            gap: '8px',
            textAlign: 'center',
            zIndex: 1000,
          }}
        >
          <div>
            <div style={{ fontSize: '0.68rem', color: '#8b9bb4', fontWeight: 600 }}>MASOFA</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 900, color: '#00F3FF' }}>
              {distanceKm.toFixed(2)} <span style={{ fontSize: '0.75rem', fontWeight: 600 }}>km</span>
            </div>
          </div>

          <div>
            <div style={{ fontSize: '0.68rem', color: '#8b9bb4', fontWeight: 600 }}>VAQT</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 900, color: '#ffffff' }}>
              {formatTime(elapsedSeconds)}
            </div>
          </div>

          <div>
            <div style={{ fontSize: '0.68rem', color: '#8b9bb4', fontWeight: 600 }}>PACE</div>
            <div style={{ fontSize: '1.15rem', fontWeight: 800, color: '#ffb703' }}>
              {avgPaceMinKm}
            </div>
          </div>

          <div>
            <div style={{ fontSize: '0.68rem', color: '#8b9bb4', fontWeight: 600 }}>KALORIYA</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 900, color: '#ff4d6d' }}>
              {caloriesBurned} <span style={{ fontSize: '0.7rem', fontWeight: 600 }}>kcal</span>
            </div>
          </div>
        </div>

        {/* Closed Loop Territory Counter Badge */}
        <div
          style={{
            position: 'absolute',
            bottom: '16px',
            left: '16px',
            backgroundColor: 'rgba(12, 18, 30, 0.9)',
            border: '1px solid #39FF14aa',
            borderRadius: '12px',
            padding: '8px 14px',
            zIndex: 1000,
            backdropFilter: 'blur(10px)',
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
          }}
        >
          <Award size={20} color="#39FF14" />
          <div>
            <div style={{ fontSize: '0.7rem', color: '#aaa', fontWeight: 600 }}>YOPILGAN DAVRALAR</div>
            <div style={{ fontSize: '0.95rem', fontWeight: 800, color: '#fff' }}>
              🎨 {capturedLoopCount} ta to‘liq bo‘yalgan hudud
            </div>
          </div>
        </div>
      </div>

      {/* Bottom Workout Controls */}
      <div
        style={{
          padding: '16px 20px',
          backgroundColor: '#0c101a',
          borderTop: '1px solid rgba(255, 255, 255, 0.08)',
          display: 'flex',
          gap: '12px',
        }}
      >
        {workoutState === 'IDLE' ? (
          <button
            onClick={() => {
              setWorkoutState('RUNNING');
              lastPosTimeRef.current = Date.now();
            }}
            style={{
              width: '100%',
              padding: '16px',
              borderRadius: '16px',
              background: 'linear-gradient(135deg, #39FF14 0%, #00F3FF 100%)',
              border: 'none',
              color: '#000',
              fontSize: '1.1rem',
              fontWeight: 900,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '10px',
              cursor: 'pointer',
              boxShadow: '0 6px 28px rgba(57, 255, 20, 0.5)',
              letterSpacing: '0.5px',
            }}
          >
            <Play size={22} fill="#000" /> BOSHLASH
          </button>
        ) : (
          <>
            <button
              onClick={() => setWorkoutState(workoutState === 'PAUSED' ? 'RUNNING' : 'PAUSED')}
              style={{
                flex: 1,
                padding: '14px',
                borderRadius: '14px',
                backgroundColor: workoutState === 'PAUSED' ? 'rgba(57, 255, 20, 0.15)' : 'rgba(255, 183, 3, 0.15)',
                border: `1px solid ${workoutState === 'PAUSED' ? '#39FF14' : '#ffb703'}`,
                color: workoutState === 'PAUSED' ? '#39FF14' : '#ffb703',
                fontSize: '0.95rem',
                fontWeight: 800,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                cursor: 'pointer',
              }}
            >
              {workoutState === 'PAUSED' ? <Play size={18} /> : <Pause size={18} />}
              {workoutState === 'PAUSED' ? 'DAVOM ETTIRISH' : 'TANAFFUS'}
            </button>

            <button
              onClick={handleFinish}
              style={{
                flex: 1.5,
                padding: '14px',
                borderRadius: '14px',
                background: 'linear-gradient(135deg, #00F3FF 0%, #0077FF 100%)',
                border: 'none',
                color: '#000',
                fontSize: '0.95rem',
                fontWeight: 900,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                cursor: 'pointer',
                boxShadow: '0 4px 20px rgba(0, 243, 255, 0.4)',
              }}
            >
              <Square size={18} fill="#000" /> MASHG‘ULOTNI YAKUNLASH
            </button>
          </>
        )}
      </div>
    </div>
  );
};
