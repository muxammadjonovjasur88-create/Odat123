import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/task.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../starting_soon/presentation/starting_soon_watcher.dart';
import '../../streak/presentation/streak_reminder_scheduler.dart';
import '../../notifications/data/notification_service.dart';
import '../../intro/presentation/permissions_onboarding_sheet.dart';
import '../../subscription/presentation/widgets/home_promo_carousel.dart';
import 'daily_quests_widget.dart';

import 'package:flutter/services.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../parent_mode/data/child_location_service.dart';

/// Screen 06 / 07 — the daily plan home.
class DailyPlanScreen extends ConsumerStatefulWidget {
  const DailyPlanScreen({super.key});

  @override
  ConsumerState<DailyPlanScreen> createState() => _DailyPlanScreenState();
}

class _DailyPlanScreenState extends ConsumerState<DailyPlanScreen> {
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showStartupPermissionsSheet(context);
      ref.read(notificationServiceProvider).checkAndRequestPermissions(context);

      // Start real-time GPS location tracking for child
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      final profile = ref.read(userProfileProvider).asData?.value;
      if (uid != null && (profile?.appRole != 'family' || profile?.familyRole != 'parent')) {
        ref.read(childLocationServiceProvider).startTracking(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final tasksAsync = ref.watch(tasksForDayProvider(today));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Ilovadan chiqish uchun yana bir bor bosing',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF121826),
            ),
          );
        } else {
          try {
            const MethodChannel('flowa/blocking').invokeMethod('moveTaskToBack');
          } catch (_) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E17),
        appBar: const FlowaAppBar(),
        bottomNavigationBar: AppBottomNav(
          current: AppNavTab.dashboard,
          onSelected: (tab) => goToTab(context, tab),
        ),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              _Content(tasks: tasksAsync.value ?? const []),
              // Invisible: opens "Starting Soon" ~5 min before a task begins.
              const StartingSoonWatcher(),
              // Invisible: keeps the evening streak reminder in sync.
              const StreakReminderScheduler(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final user = ref.watch(userProfileProvider).asData?.value;
    final now = DateTime.now();
    final months = [
      '', 'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
      'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
    ];
    final dateStr = '${now.day}-${months[now.month].toUpperCase()}';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Notion-style Minimal Workspace Header ──────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                'BUGUN, $dateStr',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user?.name != null ? 'Salom, ${user!.name}' : 'Bugungi Reja & Intizom',
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      // Streak Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121826),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E283D)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 5),
                            Text(
                              '${user?.streak ?? 0} kun',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: HomePromoCarousel(),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: DailyQuestsWidget(),
                ),
                SizedBox(height: 24 + bottomInset + 80),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({
    super.key,
    required this.percent,
  });

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1E283D),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'home.daily_progress'.tr(),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '${(percent * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GradientProgressBar(
            percent: percent,
            height: 8,
          ),
        ],
      ),
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({
    required this.percent,
    required this.height,
  });

  final double percent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final activeWidth = constraints.maxWidth * clamped;
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: activeWidth,
              height: height,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          );
        },
      ),
    );
  }
}


