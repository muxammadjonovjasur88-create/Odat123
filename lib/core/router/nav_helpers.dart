import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_bottom_nav.dart';
import 'app_routes.dart';

/// Maps a bottom-nav tab to its home route.
String routeForTab(AppNavTab tab) {
  switch (tab) {
    case AppNavTab.calendar:
      return AppRoutes.dailyPlan;
    case AppNavTab.focus:
      return AppRoutes.deepFocus;
    case AppNavTab.stats:
      return AppRoutes.progress;
    case AppNavTab.profile:
      return AppRoutes.profile;
  }
}

/// Switches the primary destination via the bottom nav.
void goToTab(BuildContext context, AppNavTab tab) =>
    context.go(routeForTab(tab));
