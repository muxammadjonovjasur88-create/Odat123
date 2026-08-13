import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/task.dart';
import '../theme/app_motion.dart';
import '../widgets/flowa_loading.dart';
import '../services/auth_repository.dart';
import '../services/user_repository.dart';
import '../../features/active_focus/presentation/active_focus_view.dart';
import '../../features/add_goal/presentation/add_goal_screen.dart';
import '../../features/ai_planner/presentation/ai_planner_screen.dart';
import '../../features/blocking/presentation/blocking_permissions_screen.dart';
import '../../features/blocking/presentation/blocking_settings_screen.dart';
import '../../features/intro/presentation/intro_video_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/daily_plan/presentation/daily_plan_screen.dart';
import '../../features/deep_focus/data/focus_providers.dart';
import '../../features/deep_focus/presentation/deep_focus_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/goal_reached/domain/goal_reached_args.dart';
import '../../features/goal_reached/presentation/goal_reached_screen.dart';
import '../../features/lobby/presentation/lobbies_screen.dart';
import '../../features/lobby/presentation/lobby_detail_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/point_system/presentation/point_system_screen.dart';
import '../../features/premium/presentation/paywall_screen.dart';
import '../../features/premium/presentation/premium_stats_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/public_profile_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/setup_profile/presentation/setup_profile_screen.dart';
import '../../features/sign_in/presentation/sign_in_screen.dart';
import '../../features/starting_soon/presentation/starting_soon_screen.dart';
import '../../features/weekly_view/presentation/weekly_view_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/random_proof/presentation/proof_capture_screen.dart';
import '../../features/random_proof/presentation/friends_proofs_screen.dart';
import '../../features/settings/presentation/telegram_link_screen.dart';
import '../../features/notifications/presentation/task_alarm_screen.dart';
import '../../features/reminders/presentation/screens/reminders_list_screen.dart';
import '../../features/shop/domain/models/shop_item.dart';
import '../../features/shop/presentation/screens/shop_screen.dart';
import '../../features/shop/presentation/screens/coupon_detail_screen.dart';
import '../../features/shop/presentation/screens/gift_detail_screen.dart';
import '../../features/shop/presentation/screens/shipping_form_screen.dart';
import '../../features/shop/presentation/screens/my_purchases_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/running/domain/models/run_session.dart';
import '../../features/running/presentation/screens/running_screen.dart';
import '../../features/running/presentation/screens/run_summary_screen.dart';
import '../../features/exercise_vision/presentation/screens/exercise_selection_screen.dart';
import '../../features/exercise_vision/presentation/screens/exercise_camera_screen.dart';
import '../../features/exercise_vision/presentation/screens/exercise_summary_screen.dart';
import 'app_routes.dart';


final rootNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide router with an auth gate.
///
/// Redirect rules:
/// * unknown auth (still loading) → stay on the Welcome splash;
/// * signed out → only the onboarding flow is reachable;
/// * signed in without a profile → Setup Profile;
/// * signed in with a profile → Home (Daily Plan), kept out of onboarding.
final routerProvider = Provider<GoRouter>((ref) {
  final gate = _AuthGate(ref);
  ref.onDispose(gate.dispose);

  GoRoute route(String path, Widget Function(GoRouterState) build) => GoRoute(
    path: path,
    pageBuilder: (context, state) => _calmPage(context, state, build(state)),
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.intro,
    refreshListenable: gate,
    redirect: gate.redirect,
    routes: [
      // Branded wait shown while auth/profile resolve (see [_AuthGate]).
      route(AppRoutes.loading, (_) => const FlowaLoadingScreen()),

      // --- Onboarding / auth (real screens) ---
      route(AppRoutes.welcome, (_) => const WelcomeScreen()),
      route(AppRoutes.intro, (_) => const IntroVideoScreen()),
      route(AppRoutes.discover, (_) => const DiscoverScreen()),
      route(AppRoutes.signIn, (_) => const SignInScreen()),
      route(AppRoutes.setupProfile, (_) => const SetupProfileScreen()),

      // --- Planning (real screens) ---
      route(AppRoutes.dailyPlan, (_) => const DailyPlanScreen()),
      route(AppRoutes.eslatma, (_) => const RemindersListScreen()),
      route(AppRoutes.weeklyView, (_) => const WeeklyViewScreen()),
      route(AppRoutes.addGoal, (_) => const AddGoalScreen()),
      route(
        AppRoutes.editGoal,
        (state) => AddGoalScreen(existing: state.extra as Task?),
      ),
      route(AppRoutes.aiPlanner, (_) => const AiPlannerScreen()),

      // --- Focus (real screens) ---
      route(AppRoutes.deepFocus, (_) => const FocusScreen()),
      GoRoute(
        path: AppRoutes.activeFocus,
        pageBuilder: (context, state) {
          final task = ProviderScope.containerOf(
            context,
          ).read(currentFocusTaskProvider);
          return _calmPage(
            context,
            state,
            task == null ? const FocusScreen() : ActiveFocusView(task: task),
          );
        },
      ),
      route(
        AppRoutes.goalReached,
        (state) => GoalReachedScreen(args: state.extra as GoalReachedArgs?),
      ),

      // --- Blocking (real screens) ---
      route(
        AppRoutes.startingSoon,
        (state) {
          // Guard against missing or wrong-type extra (e.g. deep-link, hot
          // restart, or back-stack restore) — return a safe fallback instead
          // of throwing a [TypeError] that would crash the app.
          final task = state.extra;
          if (task is! Task) return const FlowaLoadingScreen();
          return StartingSoonScreen(task: task);
        },
      ),
      route(AppRoutes.blocking, (_) => const BlockingSettingsScreen()),
      route(
        AppRoutes.blockingPermissions,
        (_) => const BlockingPermissionsScreen(),
      ),

      // --- Community / stats / account (real screens) ---
      route(AppRoutes.community, (_) => const CommunityScreen()),
      route(AppRoutes.pointSystem, (_) => const PointSystemScreen()),
      route(AppRoutes.profile, (_) => const ProfileScreen()),
      GoRoute(
        path: '${AppRoutes.profile}/:userId',
        pageBuilder: (context, state) => _calmPage(
          context,
          state,
          PublicProfileScreen(userId: state.pathParameters['userId']!),
        ),
      ),
      route(AppRoutes.editProfile, (_) => const EditProfileScreen()),
      route(AppRoutes.settings, (_) => const SettingsScreen()),
      route(AppRoutes.progress, (_) => const ProgressScreen()),
      route(AppRoutes.leaderboard, (_) => const LeaderboardScreen()),

      // Private lobbies
      route(AppRoutes.lobbies, (_) => const LobbiesScreen()),
      GoRoute(
        path: '${AppRoutes.lobby}/:id',
        pageBuilder: (context, state) => _calmPage(
          context,
          state,
          LobbyDetailScreen(lobbyId: state.pathParameters['id']!),
        ),
      ),

      // Premium (subscription)
      route(AppRoutes.paywall, (_) => const PaywallScreen()),
      route(AppRoutes.premiumStats, (_) => const PremiumStatsScreen()),

      // Random Proof Capture
      GoRoute(
        path: '/proof-capture/:sessionId',
        pageBuilder: (context, state) => _calmPage(
          context,
          state,
          ProofCaptureScreen(sessionId: state.pathParameters['sessionId']!),
        ),
      ),

      // --- Qism 3 ---
      route(AppRoutes.telegramLink, (_) => const TelegramLinkScreen()),
      route(AppRoutes.friendsProofs, (_) => const FriendsProofsScreen()),

      // --- Reminders (standalone budilnik) ---
      route(AppRoutes.reminders, (_) => const RemindersListScreen()),

      // --- Do'kon (Shop) ---
      route(AppRoutes.shop, (_) => const ShopScreen()),
      route(AppRoutes.shopPurchases, (_) => const MyPurchasesScreen()),
      GoRoute(
        path: AppRoutes.couponDetail,
        pageBuilder: (context, state) => _calmPage(
          context,
          state,
          CouponDetailScreen(item: state.extra as ShopItem),
        ),
      ),
      GoRoute(
        path: AppRoutes.giftDetail,
        pageBuilder: (context, state) => _calmPage(
          context,
          state,
          GiftDetailScreen(item: state.extra as ShopItem),
        ),
      ),
      GoRoute(
        path: AppRoutes.shippingForm,
        pageBuilder: (context, state) => _calmPage(
          context,
          state,
          ShippingFormScreen(item: state.extra as ShopItem),
        ),
      ),

      // --- Task Alarm (Budilnik) ---

      GoRoute(
        path: AppRoutes.taskAlarm,
        pageBuilder: (context, state) {
          final taskId = state.uri.queryParameters['taskId'] ?? '';
          final title = state.uri.queryParameters['title'] ?? 'Vazifa';
          final minutesBefore = int.tryParse(state.uri.queryParameters['minutesBefore'] ?? '10') ?? 10;
          final notificationId = int.tryParse(state.uri.queryParameters['notificationId'] ?? '0') ?? 0;
          
          return NoTransitionPage(
            child: TaskAlarmScreen(
              taskId: taskId,
              title: title,
              minutesBefore: minutesBefore,
              notificationId: notificationId,
            ),
          );
        },
      ),
      // --- Kutubxona (Library) ---
      route(AppRoutes.library, (_) => const LibraryScreen()),

      // --- Yugurish (Running) ---
      route(AppRoutes.running, (_) => const RunningScreen()),
      GoRoute(
        path: AppRoutes.runningSummary,
        pageBuilder: (context, state) => _calmPage(
          context,
          state,
          RunSummaryScreen(session: state.extra as RunSession),
        ),
      ),

      // --- Exercise Vision ---
      route(AppRoutes.exerciseSelect, (_) => const ExerciseSelectionScreen()),
      GoRoute(
        path: AppRoutes.exerciseCamera,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final exerciseType = extra['exerciseType'] as String? ?? 'SQUAT';
          final targetReps = extra['targetReps'] as int? ?? 20;
          return _calmPage(
            context,
            state,
            ExerciseCameraScreen(
              exerciseType: exerciseType,
              targetReps: targetReps,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.exerciseSummary,
        pageBuilder: (context, state) => _calmPage(
          context,
          state,
          ExerciseSummaryScreen(
            sessionData: state.extra as Map<String, dynamic>? ?? {},
          ),
        ),
      ),
    ],
  );
});

/// Wraps a screen in a calm, consistent fade + slight-slide page transition
/// (~320ms ease) used for every route.
///
/// When the OS asks to minimise motion, we drop the animation entirely and hand
/// back a [NoTransitionPage] so navigation is instant but still clean.
Page<void> _calmPage(BuildContext context, GoRouterState state, Widget child) {
  if (context.reduceMotion) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.pageReverse,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// Onboarding routes reachable while signed out.
const _onboardingRoutes = {
  AppRoutes.welcome,
  AppRoutes.discover,
  AppRoutes.signIn,
};

/// Bridges Riverpod auth/profile state to go_router: notifies the router to
/// re-run [redirect] whenever auth or the user's profile changes.
class _AuthGate extends ChangeNotifier {
  _AuthGate(this._ref) {
    _subs = [
      _ref.listen(authStateProvider, (_, _) => notifyListeners()),
      _ref.listen(userProfileProvider, (_, _) => notifyListeners()),
    ];
  }

  final Ref _ref;
  late final List<ProviderSubscription> _subs;

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;

    // Intro video screen runs on initial launch; do not redirect away while watching intro.
    if (loc == AppRoutes.intro) {
      return null;
    }

    final auth = _ref.read(authStateProvider);
    final inOnboarding = _onboardingRoutes.contains(loc);
    // Pre-home locations from which it's safe to show the branded loader (never
    // yank a user who is already inside the app).
    final preHome =
        inOnboarding ||
        loc == AppRoutes.setupProfile ||
        loc == AppRoutes.loading;

    // Auth status not yet known — show the calm branded loader.
    if (auth.isLoading || auth.hasError) {
      return loc == AppRoutes.loading ? null : AppRoutes.loading;
    }

    final user = auth.asData?.value;
    if (user == null) {
      return inOnboarding ? null : AppRoutes.welcome;
    }

    // Signed in: resolve the profile before deciding. Keep the loader visible
    // during the first profile load, but don't pull an in-app user onto it.
    final profile = _ref.read(userProfileProvider);
    if (profile.isLoading) {
      if (!preHome) return null;
      return loc == AppRoutes.loading ? null : AppRoutes.loading;
    }

    final hasProfile = profile.asData?.value != null;
    if (!hasProfile) {
      return loc == AppRoutes.setupProfile ? null : AppRoutes.setupProfile;
    }

    // Fully onboarded — don't let them sit on onboarding/setup/loader screens.
    if (preHome) {
      return AppRoutes.dailyPlan;
    }
    return null;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.close();
    }
    super.dispose();
  }
}
