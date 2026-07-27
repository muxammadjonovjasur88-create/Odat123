/// Centralized route paths & names for all 21 screens (plus the dev demo).
///
/// Real screens are wired up feature-by-feature later; for now each maps to a
/// placeholder in `app_router.dart`.
abstract final class AppRoutes {
  AppRoutes._();

  // Onboarding / auth
  static const welcome = '/'; // 01
  static const loading = '/loading'; // branded wait: auth check / profile load
  static const discover = '/discover'; // 02
  static const signIn = '/sign-in'; // 03
  static const setupProfile = '/setup-profile'; // 05

  // Planning
  static const dailyPlan = '/daily'; // 06 / 07
  static const weeklyView = '/weekly'; // 08
  static const addGoal = '/add-goal'; // 09
  static const editGoal = '/edit-goal'; // edit an existing task
  static const aiPlanner = '/ai-planner'; // 11

  // Focus / sessions
  static const startingSoon = '/starting-soon'; // 10
  static const deepFocus = '/deep-focus'; // 12
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
}
