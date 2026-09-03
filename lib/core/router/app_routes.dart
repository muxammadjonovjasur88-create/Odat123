/// Centralized route paths & names for all 21 screens (plus the dev demo).
///
/// Real screens are wired up feature-by-feature later; for now each maps to a
/// placeholder in `app_router.dart`.
abstract final class AppRoutes {
  AppRoutes._();

  // Onboarding / auth
  static const welcome = '/'; // 01
  static const intro = '/intro'; // intro video
  static const languageSelect = '/language-select'; // 01b language selection
  static const loading = '/loading'; // branded wait: auth check / profile load
  static const discover = '/discover'; // 02
  static const signIn = '/sign-in'; // 03
  static const setupProfile = '/setup-profile'; // 05
  static const roleSelection = '/role-selection';
  static const familyAgreement = '/family-agreement';
  static const parentHome = '/parent-home';
  static const parentStudy = '/parent-study';
  static const parentMissions = '/parent-missions';
  static const parentWallet = '/parent-wallet';
  static const parentLocation = '/parent-location';
  static const playHub = '/play-hub';
  static const skillProfile = '/skill-profile';
  static const communityHub = '/community-hub';
  static const subscriptionPaywall = '/subscription-paywall';

  // Planning
  static const dailyPlan = '/daily'; // 06 / 07
  static const eslatma = '/eslatma';
  static const zametka = eslatma;
  static const weeklyView = '/weekly'; // 08
  static const addGoal = '/add-goal'; // 09
  static const editGoal = '/edit-goal'; // edit an existing task
  static const aiPlanner = '/ai-planner'; // 11

  // Focus / sessions / Intizom / Digital Wellbeing
  static const startingSoon = '/starting-soon'; // 10
  static const deepFocus = '/deep-focus'; // 12
  static const disciplineHub = '/discipline-hub';
  static const missionAlarm = '/mission-alarm';
  static const strictDiscipline = '/strict-discipline';
  static const digitalWellbeing = '/digital-wellbeing';
  static const appLimits = '/app-limits';
  static const digitalDetox = '/digital-detox';
  static const activeFocus = '/active-focus'; // 13
  static const goalReached = '/goal-reached'; // 14
  static const blocking = '/blocking'; // 15
  static const blockingPermissions = '/blocking/permissions';

  // Community / stats / account
  static const community = '/community'; // 16
  static const pointSystem = '/points'; // 17
  static const profile = '/profile'; // 18
  static const editProfile = '/edit-profile';
  static const settings = '/settings'; // 19
  static const progress = '/progress'; // 20
  static const leaderboard = '/leaderboard';
  static const wallet = '/wallet';

  // Private competition lobbies
  static const lobbies = '/lobbies';
  static const lobby = '/lobby'; // detail: '/lobby/:id'

  // Premium (subscription)
  static const paywall = '/paywall';
  static const premiumStats = '/premium-stats';


  /// Dev-only gallery to verify shared widgets in light & dark.
  static const demo = '/demo';

  // --- Qism 3: Tasodifiy Isbot ---
  static const telegramLink = '/telegram-link';
  static const friendsProofs = '/friends-proofs';
  static const taskAlarm = '/task-alarm';

  // Reminders (standalone budilnik)
  static const reminders = '/reminders';

  // Do'kon (Shop) feature routes
  static const shop = '/shop';
  static const shopPurchases = '/shop/purchases';
  static const couponDetail = '/shop/coupon';
  static const giftDetail = '/shop/gift';
  static const shippingForm = '/shop/shipping';

  // Kutubxona (Library) feature routes
  static const library = '/library';
  static const audiobooks = '/audiobooks';

  // Yugurish (Running) feature routes
  static const running = '/running';
  static const runningSummary = '/running/summary';

  // Exercise Vision feature routes
  static const exerciseSelect = '/exercise/select';
  static const exerciseCamera = '/exercise/camera';
  static const exerciseSummary = '/exercise/summary';

  // AI Assistant & STT
  static const aiAssistant = '/ai-assistant';

  // 1v1 Battle Arena
  static const battle = '/battle';
  static const battleRoom = '/battle/room';

  // Referrals & Friends
  static const referrals = '/referrals';
  static const friends = '/friends';

  // Boss Raid (Team Battle)
  static const bossRaid = '/boss-raid';

  // Bilim & Fan Testlari (Quizzes)
  static const quiz = '/quiz';

  // Yangiliklar (News Feed)
  static const news = '/news';
}

