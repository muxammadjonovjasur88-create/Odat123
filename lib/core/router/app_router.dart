import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/task.dart';
import '../theme/app_motion.dart';
import '../widgets/flowa_loading.dart';
import '../services/auth_repository.dart';
import '../services/locale_store.dart';
import '../services/user_repository.dart';
import '../../features/active_focus/presentation/active_focus_view.dart';
import '../../features/add_goal/presentation/add_goal_screen.dart';
import '../../features/ai_planner/presentation/ai_planner_screen.dart';
import '../../features/blocking/presentation/blocking_permissions_screen.dart';
import '../../features/blocking/presentation/blocking_settings_screen.dart';
import '../../features/blocking/presentation/screens/digital_wellbeing_screen.dart';
import '../../features/blocking/presentation/screens/app_limits_screen.dart';
import '../../features/blocking/presentation/screens/digital_detox_screen.dart';
import '../../features/intro/presentation/intro_video_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/daily_plan/presentation/daily_plan_screen.dart';
import '../../features/deep_focus/data/focus_providers.dart';
import '../../features/deep_focus/presentation/deep_focus_screen.dart';
import '../../features/deep_focus/presentation/strict_discipline_screen.dart';
import '../../features/deep_focus/presentation/discipline_hub_screen.dart';
import '../../features/deep_focus/presentation/mission_alarm_screen.dart';
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
import '../../features/parent_mode/presentation/screens/role_selection_screen.dart';
import '../../features/parent_mode/presentation/screens/family_agreement_screen.dart';
import '../../features/parent_mode/presentation/screens/parent_home_screen.dart';
import '../../features/parent_mode/presentation/screens/parent_study_screen.dart';
import '../../features/parent_mode/presentation/screens/parent_missions_screen.dart';
import '../../features/parent_mode/presentation/screens/parent_wallet_screen.dart';
import '../../features/parent_mode/presentation/screens/parent_location_screen.dart';
import '../../features/interactive_games/presentation/screens/play_hub_screen.dart';
import '../../features/interactive_games/presentation/screens/skill_profile_screen.dart';
import '../../features/subscription/presentation/screens/subscription_paywall_screen.dart';
import '../../features/community/presentation/screens/community_hub_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/welcome/presentation/language_select_screen.dart';
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
import '../../features/boss_raid/presentation/screens/boss_raid_screen.dart';
import '../../features/knowledge/presentation/screens/subject_quiz_screen.dart';
import '../../features/knowledge/presentation/screens/audiobooks_screen.dart';
import '../../features/running/presentation/screens/running_screen.dart';
import '../../features/running/presentation/screens/run_summary_screen.dart';
import '../../features/exercise_vision/presentation/screens/exercise_selection_screen.dart';
import '../../features/exercise_vision/presentation/screens/exercise_camera_screen.dart';
import '../../features/exercise_vision/presentation/screens/exercise_summary_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../features/battle/presentation/screens/battle_arena_screen.dart';
import '../../features/battle/presentation/screens/battle_room_screen.dart';
import '../../features/referral/presentation/screens/referral_screen.dart';
import '../../features/news/presentation/screens/news_screen.dart';
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
      route(AppRoutes.languageSelect, (_) => const LanguageSelectScreen()),
      route(AppRoutes.discover, (_) => const DiscoverScreen()),
      route(AppRoutes.signIn, (_) => const SignInScreen()),
      route(AppRoutes.setupProfile, (_) => const SetupProfileScreen()),
      route(AppRoutes.roleSelection, (_) => const RoleSelectionScreen()),
      route(AppRoutes.familyAgreement, (_) => const FamilyAgreementScreen()),
      route(AppRoutes.parentHome, (_) => const ParentHomeScreen()),
      route(AppRoutes.parentStudy, (_) => const ParentStudyScreen()),
      route(AppRoutes.parentMissions, (_) => const ParentMissionsScreen()),
      route(AppRoutes.parentWallet, (_) => const ParentWalletScreen()),
      route(AppRoutes.parentLocation, (_) => const ParentLocationScreen()),
      route(AppRoutes.playHub, (_) => const PlayHubScreen()),
      route(AppRoutes.skillProfile, (_) => const SkillProfileScreen()),
      route(AppRoutes.subscriptionPaywall, (_) => const SubscriptionPaywallScreen()),
      route(AppRoutes.communityHub, (_) => const CommunityHubScreen()),

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

      // --- Focus (Task Focus & Strict Discipline & Intizom Hub) ---
      route(AppRoutes.deepFocus, (_) => const FocusScreen()),
      route(
        AppRoutes.strictDiscipline,
        (state) => StrictDisciplineScreen(reminderId: state.extra as String?),
      ),
      route(AppRoutes.disciplineHub, (_) => const DisciplineHubScreen()),
      route(AppRoutes.missionAlarm, (_) => const MissionAlarmScreen()),
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
      route(AppRoutes.digitalWellbeing, (_) => const DigitalWellbeingScreen()),
      route(AppRoutes.appLimits, (_) => const AppLimitsScreen()),
      route(AppRoutes.digitalDetox, (_) => const DigitalDetoxScreen()),

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
      GoRoute(
        path: AppRoutes.leaderboard,
        pageBuilder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final tab = switch (tabStr) {
            'clans' => LeaderboardTab.clans,
            'friends' => LeaderboardTab.friends,
            'region' => LeaderboardTab.region,
            _ => LeaderboardTab.global,
          };
          return _calmPage(context, state, LeaderboardScreen(initialTab: tab));
        },
      ),

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
      GoRoute(
        path: '/run-summary',
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
          final reminderId = extra['reminderId'] as String?;
          return _calmPage(
            context,
            state,
            ExerciseCameraScreen(
              exerciseType: exerciseType,
              targetReps: targetReps,
              reminderId: reminderId,
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
      route(AppRoutes.aiAssistant, (_) => const AiAssistantScreen()),
      route(AppRoutes.battle, (_) => const BattleArenaScreen()),
      GoRoute(
        path: '${AppRoutes.battle}/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _calmPage(context, state, BattleRoomScreen(battleId: id));
        },
      ),
      GoRoute(
        path: '${AppRoutes.battleRoom}/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _calmPage(context, state, BattleRoomScreen(battleId: id));
        },
      ),
      route(AppRoutes.referrals, (_) => const ReferralScreen()),
      route(AppRoutes.bossRaid, (_) => const BossRaidScreen()),
      route(AppRoutes.quiz, (_) => const SubjectQuizScreen()),
      route(AppRoutes.audiobooks, (_) => const AudiobooksScreen()),
      route(AppRoutes.news, (_) => const NewsScreen()),
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
  AppRoutes.languageSelect,
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
        loc == AppRoutes.roleSelection ||
        loc == AppRoutes.loading;

    // Auth status not yet known — show the calm branded loader.
    if (auth.isLoading || auth.hasError) {
      return loc == AppRoutes.loading ? null : AppRoutes.loading;
    }

    final user = auth.asData?.value;
    if (user == null) {
      if (inOnboarding) return null;
      return LocaleStore.hasSeenIntro() ? AppRoutes.signIn : AppRoutes.intro;
    }

    // Signed in: resolve the profile before deciding. Keep the loader visible
    // during the first profile load, but don't pull an in-app user onto it.
    final profile = _ref.read(userProfileProvider);
    if (profile.isLoading) {
      if (!preHome) return null;
      return loc == AppRoutes.loading ? null : AppRoutes.loading;
    }

    final userProfile = profile.asData?.value;
    final hasProfile = userProfile != null;
    if (!hasProfile) {
      return loc == AppRoutes.setupProfile ? null : AppRoutes.setupProfile;
    }

    // Post-registration role selection check
    final hasSelectedRole = userProfile.roleSelected || userProfile.appRole != null;
    if (!hasSelectedRole) {
      return loc == AppRoutes.roleSelection ? null : AppRoutes.roleSelection;
    }

    // ── Parent Role Lock ────────────────────────────────────────
    // If the user is a parent (appRole == 'family' && familyRole == 'parent'),
    // they should ONLY access parent-specific routes.
    // Block access to all personal / child screens.
    if (userProfile.isParent) {
      const parentRoutes = {
        AppRoutes.parentHome,
        AppRoutes.parentStudy,
        AppRoutes.parentMissions,
        AppRoutes.parentWallet,
        AppRoutes.parentLocation,
        AppRoutes.familyAgreement,
        AppRoutes.settings,
        AppRoutes.editProfile,
        AppRoutes.profile,
      };
      final isOnParentRoute = parentRoutes.contains(loc);
      if (!isOnParentRoute) {
        return preHome ? AppRoutes.parentHome : AppRoutes.parentHome;
      }
      return null;
    }
    // ────────────────────────────────────────────────────────────

    // Fully onboarded personal user — don't let them sit on onboarding/setup/loader/roleSelection screens.
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
