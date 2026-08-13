import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_bottom_nav.dart';
import 'app_routes.dart';

/// Maps a bottom-nav tab to its home route.
String routeForTab(AppNavTab tab) {
  switch (tab) {
    case AppNavTab.dashboard:
      return AppRoutes.dailyPlan;
    case AppNavTab.zametka:
      return AppRoutes.eslatma;
    case AppNavTab.ai:
      return AppRoutes.aiPlanner;
    case AppNavTab.leaderboard:
      return AppRoutes.leaderboard;
    case AppNavTab.profile:
      return AppRoutes.profile;
  }
}

/// Switches the primary destination via the bottom nav.
void goToTab(BuildContext context, AppNavTab tab) =>
    context.go(routeForTab(tab));
