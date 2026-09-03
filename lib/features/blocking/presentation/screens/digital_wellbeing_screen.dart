import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../../data/digital_wellbeing_service.dart';
import '../../domain/app_usage_info.dart';
import '../providers/digital_wellbeing_provider.dart';
import 'app_limits_screen.dart';
import 'digital_detox_screen.dart';

class DigitalWellbeingScreen extends ConsumerStatefulWidget {
  const DigitalWellbeingScreen({super.key});

  @override
  ConsumerState<DigitalWellbeingScreen> createState() => _DigitalWellbeingScreenState();
}

class _DigitalWellbeingScreenState extends ConsumerState<DigitalWellbeingScreen> {
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await ref.read(digitalWellbeingServiceProvider).hasUsageAccess();
    if (mounted) setState(() => _hasPermission = granted);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(screenTimeSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)]),
              ),
              child: const Icon(Icons.phonelink_setup_rounded, color: Color(0xFF04050D), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'wellbeing.title'.tr(),
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF4AADDC)),
            onPressed: () => context.push(AppRoutes.blocking),
          ),
        ],
      ),
      body: !_hasPermission
          ? _buildPermissionBanner()
          : summaryAsync.when(
              data: (summary) => RefreshIndicator(
                color: const Color(0xFF4AADDC),
                onRefresh: () async {
                  ref.invalidate(screenTimeSummaryProvider);
                  ref.invalidate(todayAppUsageListProvider);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  children: [
                    // 1. Discipline Score Card
                    _buildDisciplineScoreCard(summary.disciplineScore),
                    const SizedBox(height: 16),

                    // 2. Screen Time Overview & Trend Card
                    _buildScreenTimeCard(summary),
                    const SizedBox(height: 16),

                    // 3. Quick Action Buttons (Digital Detox & App Limits)
                    _buildQuickActionsRow(),
                    const SizedBox(height: 20),

                    // 4. App Limits & Usage Section
                    _buildAppUsageSection(summary.topApps),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF4AADDC)),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 42),
                      const SizedBox(height: 12),
                      Text(
                        'wellbeing.error_load'.tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(screenTimeSummaryProvider),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF141F36)),
                        child: Text('retry'.tr()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPermissionBanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF121B2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF4AADDC).withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x224AADDC),
                ),
                child: const Icon(Icons.security_rounded, color: Color(0xFF4AADDC), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'wellbeing.permission_title'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'wellbeing.permission_desc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(digitalWellbeingServiceProvider).openUsageAccessSettings();
                  await Future.delayed(const Duration(seconds: 1));
                  _checkPermission();
                },
                icon: const Icon(Icons.settings_rounded, color: Color(0xFF04050D), size: 18),
                label: Text(
                  'wellbeing.grant_permission'.tr(),
                  style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4AADDC),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisciplineScoreCard(int score) {
    Color scoreColor;
    String statusKey;
    if (score >= 80) {
      scoreColor = const Color(0xFF3A7FCC);
      statusKey = 'wellbeing.score_excellent';
    } else if (score >= 60) {
      scoreColor = const Color(0xFF4AADDC);
      statusKey = 'wellbeing.score_good';
    } else {
      scoreColor = const Color(0xFFFFB703);
      statusKey = 'wellbeing.score_needs_work';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF090B18),
            scoreColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scoreColor.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(color: scoreColor.withValues(alpha: 0.12), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          // Circular Score Gauge
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF04050D),
              border: Border.all(color: scoreColor, width: 3),
              boxShadow: [
                BoxShadow(color: scoreColor.withValues(alpha: 0.4), blurRadius: 10),
              ],
            ),
            child: Center(
              child: Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'wellbeing.discipline_score'.tr(),
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusKey.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'wellbeing.score_hint'.tr(),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTimeCard(ScreenTimeSummary summary) {
    final isReduced = summary.isReducedVsYesterday;
    final diffMin = summary.diffVsYesterday.abs();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x334AADDC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'wellbeing.screen_time_today'.tr(),
                style: const TextStyle(
                  color: Color(0xFF4AADDC),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReduced ? const Color(0x224AADDC) : const Color(0x22FF5252),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReduced ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: isReduced ? const Color(0xFF3A7FCC) : const Color(0xFFFF5252),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${diffMin}m',
                      style: TextStyle(
                        color: isReduced ? const Color(0xFF3A7FCC) : const Color(0xFFFF5252),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary.formattedTotalTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Categories Breakdown Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _categoryPill(Icons.people_rounded, 'wellbeing.cat_social'.tr(), summary.categoryMinutes[AppCategory.social] ?? 0, const Color(0xFF4AADDC)),
              _categoryPill(Icons.play_circle_filled_rounded, 'wellbeing.cat_video'.tr(), summary.categoryMinutes[AppCategory.entertainment] ?? 0, const Color(0xFFFFB703)),
              _categoryPill(Icons.sports_esports_rounded, 'wellbeing.cat_games'.tr(), summary.categoryMinutes[AppCategory.games] ?? 0, const Color(0xFFFF5252)),
              _categoryPill(Icons.work_rounded, 'wellbeing.cat_work'.tr(), summary.categoryMinutes[AppCategory.productivity] ?? 0, const Color(0xFF3A7FCC)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryPill(IconData icon, String title, int minutes, Color color) {
    if (minutes == 0) return const SizedBox.shrink();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final timeStr = h > 0 ? '${h}s ${m}m' : '${m}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text('$title: $timeStr', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        // Digital Detox Button
        Expanded(
          child: BouncyScale(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DigitalDetoxScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4AADDC), Color(0xFF4AADDC)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x334AADDC), blurRadius: 12)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.do_not_disturb_on_rounded, color: Color(0xFF04050D), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'wellbeing.digital_detox'.tr(),
                    style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // App Limits Manager Button
        Expanded(
          child: BouncyScale(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppLimitsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF090B18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFF3A7FCC), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'wellbeing.app_limits'.tr(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppUsageSection(List<AppUsageInfo> apps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'wellbeing.most_used_apps'.tr(),
              style: const TextStyle(
                color: Color(0xFF8B9BB4),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppLimitsScreen()),
                );
              },
              child: Text(
                'wellbeing.set_limit'.tr(),
                style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (apps.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF090B18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'wellbeing.no_apps_yet'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final app = apps[index];
              return _buildAppUsageTile(app);
            },
          ),
      ],
    );
  }

  Widget _buildAppUsageTile(AppUsageInfo app) {
    final h = app.usageMinutes ~/ 60;
    final m = app.usageMinutes % 60;
    final timeStr = h > 0 ? '${h}s ${m}d' : '$m daqiqa';

    final hasLimit = app.hasLimit;
    final isExceeded = app.isLimitExceeded;
    final progress = app.limitProgress;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExceeded
              ? const Color(0xFFFF5252)
              : (hasLimit ? const Color(0xFF4AADDC).withValues(alpha: 0.3) : Colors.white10),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // App Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: app.iconBytes != null && app.iconBytes!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          app.iconBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.android_rounded, color: Colors.white70),
                        ),
                      )
                    : const Icon(Icons.android_rounded, color: Colors.white70),
              ),
              const SizedBox(width: 12),

              // App Name and Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLimit
                          ? '$timeStr / ${app.dailyLimitMinutes} daqiqa'
                          : timeStr,
                      style: TextStyle(
                        color: isExceeded ? const Color(0xFFFF5252) : Colors.white54,
                        fontSize: 11,
                        fontWeight: isExceeded ? FontWeight.w900 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              // Limit Status Badge
              if (hasLimit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExceeded ? const Color(0x22FF5252) : const Color(0x224AADDC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isExceeded ? 'wellbeing.limit_exceeded'.tr() : '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: isExceeded ? const Color(0xFFFF5252) : const Color(0xFF4AADDC),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),

          if (hasLimit) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isExceeded ? const Color(0xFFFF5252) : const Color(0xFF4AADDC),
                ),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
