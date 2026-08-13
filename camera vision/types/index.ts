// ODAT — Centralized TypeScript Definitions

export type UserRole = 'USER' | 'ADMIN';

export type GoalCategory = 
  | 'Ta\'lim'
  | 'Sport'
  | 'Kitob'
  | 'Sog‘liq'
  | 'Karyera'
  | 'Shaxsiy rivojlanish'
  | 'Moliyaviy'
  | 'Ijod'
  | 'Boshqa';

export type GoalPriority = 'Past' | 'O‘rta' | 'Yuqori' | 'Muhim';

export type GoalStatus = 'draft' | 'active' | 'paused' | 'completed' | 'archived' | 'cancelled';

export type MilestoneStatus = 'locked' | 'active' | 'completed' | 'skipped';

export type QuestType = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'SPECIAL' | 'GOAL_QUEST' | 'BATTLE_QUEST';

export type QuestExecutionMode = 'SEQUENTIAL' | 'PARALLEL';

export type DifficultyLevel = 'Oson' | 'O‘rta' | 'Qiyin' | 'Juda qiyin';

export type MissionMeasurementType = 'TIME' | 'DISTANCE' | 'STEPS' | 'COUNT' | 'BOOLEAN' | 'USER_INPUT';

export type MissionVerificationType = 'SELF_REPORT' | 'TIMER' | 'STEP_SENSOR' | 'TEST_SCORE' | 'GPS' | 'CAMERA_EXERCISE';

export type ExerciseType = 'SQUAT' | 'PUSH_UP' | 'PLANK' | 'WALKING' | 'RUNNING' | string;

export type ExerciseSessionStatus = 'CREATED' | 'STARTED' | 'PAUSED' | 'COMPLETED' | 'FAILED' | 'CANCELLED' | 'EXPIRED';

export interface ExerciseTelemetry {
  exerciseType: ExerciseType;
  repetitions: number;
  durationSeconds: number;
  averageFormScore: number;
  confidenceScore: number;
  timestamp: string;
}

export interface RunSessionTelemetry {
  exerciseType: 'RUNNING' | 'WALKING' | string;
  distanceKm: number;
  durationSeconds: number;
  caloriesBurned: number;
  avgSpeedKmh: number;
  avgPaceMinKm: string;
  polygonsCapturedCount: number;
  polygons: Array<Array<[number, number]>>;
  path: Array<[number, number]>;
  timestamp: string;
}

export interface TerritoryPolygon {
  id: string;
  ownerId: string;
  ownerName: string;
  ownerColor: string;
  points: Array<[number, number]>;
  capturedAt: string;
}

export interface ExerciseSession {
  id: string;
  missionId: string;
  userId: string;
  exerciseType: ExerciseType;
  targetRepetitions?: number;
  targetDuration?: number;
  status: ExerciseSessionStatus;
  startedAt?: string;
  completedAt?: string;
  telemetry?: ExerciseTelemetry;
  runTelemetry?: RunSessionTelemetry;
}

export type MissionStatus = 'pending' | 'in_progress' | 'completed' | 'skipped' | 'expired' | 'locked';

export type RecurrencePattern = 'DAILY' | 'WEEKDAYS' | 'WEEKENDS' | 'WEEKLY' | 'CUSTOM';

export type AchievementCategory = 
  | 'Boshlanish'
  | 'Intizom'
  | 'Ta\'lim'
  | 'Kitob'
  | 'Sport'
  | 'Quest'
  | 'Battle'
  | 'POINT'
  | 'Level'
  | 'Maxsus';

export type RarityTier = 'Common' | 'Rare' | 'Epic' | 'Legendary' | 'Mythic';

export type BattleType = '1v1' | 'Group' | 'Global';

export type BattleScoringType = 'POINT' | 'MISSION_COUNT' | 'QUEST_COUNT' | 'STREAK' | 'DISTANCE' | 'STEPS';

export type BattleStatus = 'upcoming' | 'active' | 'completed' | 'cancelled';

export type NotificationType = 'MISSION' | 'GOAL' | 'QUEST' | 'STREAK' | 'BATTLE' | 'ACHIEVEMENT' | 'LEVEL_UP' | 'SYSTEM';

export type NavigationTab = 'home' | 'reminders' | 'ai' | 'leaderboard' | 'profile';

export interface UserProfile {
  id: string;
  email: string;
  username: string;
  displayName: string;
  avatarUrl?: string;
  bio?: string;
  timezone: string;
  language: 'uz' | 'ru' | 'en';
  isPrivate: boolean;
  totalPoints: number;
  level: number;
  currentXp: number;
  nextLevelXp: number;
  disciplineScore: number; // 0 - 100%
  currentStreak: number;
  bestStreak: number;
  lastEligibleDate?: string;
  featuredBadges: string[];
  createdAt: string;
}

export interface Goal {
  id: string;
  userId: string;
  title: string;
  description?: string;
  category: GoalCategory;
  priority: GoalPriority;
  status: GoalStatus;
  startDate: string;
  targetDate?: string;
  progressPercentage: number;
  milestones: Milestone[];
  createdAt: string;
  updatedAt: string;
}

export interface Milestone {
  id: string;
  goalId: string;
  title: string;
  description?: string;
  orderIndex: number;
  targetValue?: number;
  currentValue: number;
  status: MilestoneStatus;
  deadline?: string;
}

export interface Quest {
  id: string;
  userId: string;
  goalId?: string;
  milestoneId?: string;
  title: string;
  description?: string;
  questType: QuestType;
  executionMode: QuestExecutionMode;
  difficulty: DifficultyLevel;
  startDate: string;
  endDate?: string;
  status: 'active' | 'completed' | 'expired' | 'paused';
  pointReward: number;
  totalMissions: number;
  completedMissions: number;
  missions: Mission[];
  createdAt: string;
}

export interface Mission {
  id: string;
  userId: string;
  goalId?: string;
  questId?: string;
  title: string;
  description?: string;
  measurementType: MissionMeasurementType;
  verificationType: MissionVerificationType;
  difficulty: DifficultyLevel;
  targetValue?: number;
  currentProgress: number;
  unit?: string;
  estimatedMinutes?: number;
  scheduledDate: string;
  deadlineTime?: string;
  recurrenceRule?: RecurrencePattern;
  pointReward: number;
  status: MissionStatus;
  exerciseType?: ExerciseType;
  targetRepetitions?: number;
  targetDuration?: number;
  formValidation?: boolean;
  cameraRequired?: boolean;
  createdAt: string;
}

export interface MissionCompletionEvent {
  id: string;
  missionId: string;
  userId: string;
  completedAt: string;
  completionDate: string;
  eventId: string; // Idempotency key
  recordedValue?: number;
  verified: boolean;
  pointsAwarded: number;
}

export interface PointTransaction {
  id: string;
  userId: string;
  amount: number;
  type: 'MISSION' | 'QUEST' | 'ACHIEVEMENT' | 'STREAK' | 'BATTLE' | 'REWARD';
  sourceType: string;
  sourceId: string;
  description: string;
  uniqueKey: string;
  createdAt: string;
}

export interface Achievement {
  id: string;
  code: string;
  title: string;
  description: string;
  category: AchievementCategory;
  rarity: RarityTier;
  isHidden: boolean;
  conditionType: string;
  conditionValue: number;
  currentProgress?: number;
  pointReward: number;
  badgeIcon: string;
  unlockedAt?: string;
}

export interface Battle {
  id: string;
  creatorId: string;
  creatorName: string;
  title: string;
  description?: string;
  battleType: BattleType;
  scoringType: BattleScoringType;
  visibility: 'Public' | 'Private' | 'Friends';
  joinCode?: string;
  startAt: string;
  endAt: string;
  maxParticipants: number;
  currentParticipantsCount: number;
  dailyScoreLimit?: number;
  status: BattleStatus;
  rewardPoolPoints: number;
  userRank?: number;
  userScore?: number;
  participants: BattleParticipant[];
}

export interface BattleParticipant {
  id: string;
  battleId: string;
  userId: string;
  displayName: string;
  avatarUrl?: string;
  joinedAt: string;
  currentScore: number;
  finalRank?: number;
}

export interface Reminder {
  id: string;
  userId: string;
  missionId?: string;
  title: string;
  scheduledTime: string;
  recurrenceRule: RecurrencePattern;
  repeatDays?: number[]; // [1, 3, 5]
  isEnabled: boolean;
  createdAt: string;
}

export interface ODATNotification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  deepLinkUrl?: string;
  isRead: boolean;
  createdAt: string;
}

export interface AIMessage {
  id: string;
  sender: 'user' | 'assistant' | 'system';
  content: string;
  intentProposal?: AIActionProposal;
  createdAt: string;
}

export interface AIActionProposal {
  id: string;
  type: 'CREATE_GOAL' | 'CREATE_MISSION' | 'CREATE_QUEST' | 'CREATE_REMINDER';
  title: string;
  details: string;
  payload: any;
  status: 'pending' | 'confirmed' | 'cancelled';
}

export interface DailySummary {
  date: string;
  completedMissions: number;
  totalMissions: number;
  pointsEarned: number;
  streakDays: number;
  disciplineScore: number;
}
