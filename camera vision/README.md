# 🎥 Camera Vision & 🏃‍♂️ Running Territory Map Modules

Ushbu papka mashqlarni bajarishda kamerada inson skeletini aniqlash va yugurish/yurish paytida GPS va xaritalar orqali hudud egallash kodlarini boshqa loyihalarga oson qo'shish uchun mustaqil modullar to'plamidir.

---

## 📁 Papka tuzilishi (Folder Structure)

```text
D:\camera vision\
├── README.md                           <- Ushbu qo'llanma va integratsiya yo'riqnomasi
├── package-dependencies.json           <- Kerakli npm paketlar ro'yxati
├── types/
│   └── index.ts                        <- Barcha TypeScript interfeyslari (Mission, Pose, Telemetry)
├── services/
│   └── db.ts                           <- LocalStorage polygon saqlash xizmati
├── components/
│   └── common/                         <- Umumiy UI komponentlar
│       ├── ODATCard.tsx                <- Holografik kartochka komponenti
│       └── ODATButton.tsx              <- Cyberpunk tugma komponenti
├── exercise-vision/                    <- Kamera Skelet & Mashq Aniqlash Moduli
│   ├── PoseDetector.ts                 <- MediaPipe Pose Landmarker integratsiyasi (Singleton)
│   ├── poseWorker.ts                   <- Web Worker orqali fonda pose aniqlash
│   ├── types.ts                        <- Landmark va bo'g'in burchaklari turlari
│   ├── ExerciseSessionManager.ts       <- Mashq seansini boshqarish va holat mashinasi
│   ├── SkeletonRenderer.ts             <- Canvas-da skelet chizish yordamchisi
│   ├── strategies/                     <- Har bir mashq algoritmi (Squat, PushUp, Plank, Motion)
│   │   ├── ExerciseStrategy.ts         <- Mashq strategiyasi bazaviy interfeysi
│   │   ├── PushUpStrategy.ts           <- Otjimaniya sanash va formani tekshirish
│   │   ├── SquatStrategy.ts            <- Cho'kish (Squat) sanash va chuqurlik burchagi
│   │   ├── PlankStrategy.ts            <- Plank taymer va gavda tekisligi
│   │   └── WalkingRunningStrategy.ts   <- Yurish/Yugurish harakati
│   └── components/                     <- React Kamera Vizualizatsiya Komponentlari
│       ├── CameraExerciseView.tsx      <- To'liq ekrandagi mashq kamerasi va real-vaqt skeleti
│       ├── CameraSetupView.tsx         <- Kamera pozitsiyasi va tananing to'liqligi tekshiruvi
│       ├── CyberSideSkeletonGuide.tsx  <- HUD yon skelet yo'riqnomasi (SVG)
│       ├── DirectBodySkeletonOverlay.tsx<- 0ms lag-siz inson ustiga chiziluvchi skelet canvas overlay
│       └── MissionCompleteView.tsx     <- Mashq yakunlanganda natijalar modali
└── running-map/                        <- GPS & Xaritada Hudud Egallash Moduli
    └── components/
        ├── RunTerritoryModal.tsx       <- Real-vaqt GPS trek, Leaflet xaritasi va yopiq zanjir hududini aniqlash
        ├── TerritoryMapView.tsx        <- Interaktiv Leaflet xarita rendereri
        └── RunTerritoryCompleteView.tsx<- Yugurish/Yurish yakuni va egallangan hududlar modali
```

---

## 🛠 Required Dependencies (Kutubxonalar)

Yangi loyihangizga quyidagi kutubxonalarni o'rnating:

```bash
npm install @mediapipe/tasks-vision leaflet @types/leaflet @capacitor/geolocation lucide-react canvas-confetti @types/canvas-confetti
```

---

## 🚀 Integratsiya misollari (Usage Examples)

### 1. Kamera Skelet Aniqlash va Mashq Sanash (Camera Exercise Vision)

```tsx
import React, { useState } from 'react';
import { CameraSetupView } from './exercise-vision/components/CameraSetupView';
import { CameraExerciseView } from './exercise-vision/components/CameraExerciseView';
import { MissionCompleteView } from './exercise-vision/components/MissionCompleteView';

export const ExercisePage = () => {
  const [step, setStep] = useState<'SETUP' | 'ACTIVE' | 'COMPLETE'>('SETUP');
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [telemetry, setTelemetry] = useState<any>(null);

  const mission = {
    id: 'm1',
    title: '20 ta Squat',
    exerciseType: 'SQUAT',
    targetValue: 20,
    pointReward: 150,
  };

  return (
    <>
      {step === 'SETUP' && (
        <CameraSetupView
          mission={mission as any}
          onStart={(mediaStream) => {
            setStream(mediaStream);
            setStep('ACTIVE');
          }}
          onCancel={() => console.log('Cancelled')}
        />
      )}

      {step === 'ACTIVE' && (
        <CameraExerciseView
          mission={mission as any}
          stream={stream}
          onCompleteSession={(resultTelemetry) => {
            setTelemetry(resultTelemetry);
            setStep('COMPLETE');
          }}
          onCancel={() => setStep('SETUP')}
        />
      )}

      {step === 'COMPLETE' && (
        <MissionCompleteView
          mission={mission as any}
          telemetry={telemetry}
          pointsEarned={150}
          currentStreak={5}
          onFinish={() => alert('Mashq yakunlandi!')}
        />
      )}
    </>
  );
};
```

---

### 2. Yugurish / Yurish Xaritasini Aniqlash va Hudud Egallash (Running Territory Map)

```tsx
import React, { useState } from 'react';
import { RunTerritoryModal } from './running-map/components/RunTerritoryModal';
import { RunTerritoryCompleteView } from './running-map/components/RunTerritoryCompleteView';

export const RunPage = () => {
  const [isCompleted, setIsCompleted] = useState(false);
  const [runTelemetry, setRunTelemetry] = useState<any>(null);

  const mission = {
    id: 'run-1',
    title: '3 km Yugurish va Hudud Egallash',
    exerciseType: 'RUNNING',
    targetValue: 3,
  };

  const user = {
    id: 'user-1',
    displayName: 'Ali',
    currentStreak: 7,
  };

  return (
    <div>
      {!isCompleted ? (
        <RunTerritoryModal
          mission={mission as any}
          user={user as any}
          onFinishSession={(telemetry) => {
            setRunTelemetry(telemetry);
            setIsCompleted(true);
          }}
          onCancel={() => console.log('Run cancelled')}
        />
      ) : (
        <RunTerritoryCompleteView
          mission={mission as any}
          telemetry={runTelemetry}
          pointsEarned={250}
          currentStreak={user.currentStreak}
          onFinish={() => setIsCompleted(false)}
        />
      )}
    </div>
  );
};
```

---

## ⚡ Asosiy Xususiyatlar (Key Features)

1. **MediaPipe Pose Vision**:
   - Web Worker yordamida videoni 30 FPS tezlikda GPU orqali tahlil qilish.
   - Tananing barcha 33 ta landmark bo'g'inlarini aniqlaydi.
   - Cho'kish (Squat) burchaklari (tizza va son burchaklari), Otjimaniya (tirsak burchaklari), Plank barqarorligi va harakat tezligini aniqlaydi.
   - Tananing kamerada to'liq ko'rinayotganini va masofani tekshiradi.

2. **Leaflet & Native GPS Territory Conquest**:
   - Geolocation orqali foydalanuvchining harakat yo'nalishini real-vaqtda polyline qilib chizadi.
   - **Closed-Loop Conquest Mechanic**: Foydalanuvchi biror hududni aylanib chiqib davrani yopsa (boshlangan nuqtaga qaytib kelsa), ushbu ko'pburchak (polygon) avtomatik ravishda uning rangi bilan bo'yaladi va egallanadi.
   - Masofa (km), Vaqt, Tezlik, Pace (min/km) va Yo'qotilgan kaloriya (kcal) hisoblanadi.
   - **Anti-Cheat Validation**: 25 km/h dan yuqori tezlik (mashina yoki fake GPS) aniqlanganda ogohlantirish beradi.
