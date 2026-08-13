import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/nav_helpers.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/flowa_app_bar.dart';
import '../../data/reminders_notification_service.dart';
import '../../domain/models/reminder.dart';
import '../providers/reminders_provider.dart';
import '../widgets/reminder_card.dart';
import 'add_reminder_screen.dart';

/// Main reminders list screen.
///
/// Tab layout: Pending / Past / Completed.
/// Empty, loading, and error states are handled explicitly — no placeholders.
class RemindersListScreen extends ConsumerStatefulWidget {
  const RemindersListScreen({super.key});

  @override
  ConsumerState<RemindersListScreen> createState() =>
      _RemindersListScreenState();
}

class _RemindersListScreenState extends ConsumerState<RemindersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Request permissions on first enter — no-op if already granted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    final svc = ref.read(remindersNotificationServiceProvider);

    // Android 13+ POST_NOTIFICATIONS
    final hasNotif = await svc.requestNotificationPermission();

    if (!hasNotif && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Eslatmalar uchun bildirishnoma ruxsati kerak.',
          ),
          action: SnackBarAction(
            label: 'Sozlamalar',
            onPressed: () => svc.openExactAlarmSettings(),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    // Exact alarm (Android 12+)
    final canExact = await svc.canScheduleExact();
    if (!canExact && mounted) {
      _showExactAlarmDialog();
    }
  }

  void _showExactAlarmDialog() {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Aniq budilnik ruxsati',
          style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Eslatmalar belgilangan vaqtda kelishi uchun "Alarmlar va eslatmalar" '
          'ruxsatini yoqing. Aks holda, eslatmalar bir necha daqiqa kechikishi mumkin.',
          style: AppTextStyles.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Keyinroq',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(remindersNotificationServiceProvider)
                  .openExactAlarmSettings();
            },
            child: Text(
              'Ruxsat berish',
              style: TextStyle(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: FlowaAppBar(
        showBackButton: Navigator.canPop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Yangi eslatma',
            onPressed: () => RemindersSheet.show(context),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.zametka,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: Column(
        children: [
          // ── Tab bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: colors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: AppTextStyles.chip.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: AppTextStyles.chip,
                labelColor: Colors.white,
                unselectedLabelColor: colors.textSecondary,
                splashFactory: NoSplash.splashFactory,
                tabs: const [
                  Tab(text: 'Kutilmoqda'),
                  Tab(text: "O'tib ketdi"),
                  Tab(text: 'Bajarildi'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Tab views ─────────────────────────────────────────────────
          Expanded(
            child: remindersAsync.when(
              loading: () => const _LoadingState(),
              error: (e, _) => _ErrorState(error: e.toString()),
              data: (_) => TabBarView(
                controller: _tabController,
                children: [
                  _ReminderTabView(
                    listProvider: pendingRemindersProvider,
                    emptyIcon: Icons.alarm_rounded,
                    emptyTitle: 'Hali eslatma yo\'q',
                    emptySubtitle:
                        'Yangi eslatma qo\'shish uchun + tugmasini bosing',
                    isGrouped: true,
                  ),
                  _ReminderTabView(
                    listProvider: pastRemindersProvider,
                    emptyIcon: Icons.history_rounded,
                    emptyTitle: 'O\'tib ketgan eslatma yo\'q',
                    emptySubtitle: 'Barchasi o\'z vaqtida ko\'rildi',
                  ),
                  _ReminderTabView(
                    listProvider: completedRemindersProvider,
                    emptyIcon: Icons.check_circle_outline_rounded,
                    emptyTitle: 'Hali bajarilgan eslatma yo\'q',
                    emptySubtitle: 'Eslatmalarni bajargach bu yerda ko\'rinadi',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RemindersSheet.show(context),
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        elevation: 4,
        icon: ShaderMask(
          shaderCallback: (r) => colors.primaryGradient.createShader(r),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
        label: ShaderMask(
          shaderCallback: (r) => colors.primaryGradient.createShader(r),
          child: Text(
            'Eslatma qo\'shish',
            style: AppTextStyles.label.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── Tab content ───────────────────────────────────────────────────────────

class _ReminderTabView extends ConsumerWidget {
  const _ReminderTabView({
    required this.listProvider,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.isGrouped = false,
  });

  final Provider<List<Reminder>> listProvider;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool isGrouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(listProvider);

    if (items.isEmpty) {
      return _EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    if (!isGrouped) {
      return ListView.builder(
        key: PageStorageKey(listProvider.runtimeType),
        padding: const EdgeInsets.only(bottom: 100, top: 4),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final reminder = items[i];
          return ReminderCard(
            key: ValueKey(reminder.id),
            reminder: reminder,
            index: i,
          );
        },
      );
    }

    final groups = _groupReminders(items);
    return ListView.builder(
      key: PageStorageKey(listProvider.runtimeType),
      padding: const EdgeInsets.only(bottom: 100, top: 4),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                group.title,
                style: AppTextStyles.h3.copyWith(
                  color: context.colors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            ...group.items.asMap().entries.map((entry) {
              return ReminderCard(
                key: ValueKey(entry.value.id),
                reminder: entry.value,
                index: entry.key,
              );
            }),
          ],
        );
      },
    );
  }

  List<_ReminderGroup> _groupReminders(List<Reminder> reminders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    final todayList = <Reminder>[];
    final tomorrowList = <Reminder>[];
    final thisWeekList = <Reminder>[];
    final laterList = <Reminder>[];

    for (final r in reminders) {
      final dt = r.dateTime;
      final date = DateTime(dt.year, dt.month, dt.day);
      if (date.isBefore(tomorrow)) {
        todayList.add(r);
      } else if (date == tomorrow) {
        tomorrowList.add(r);
      } else if (date.isBefore(nextWeek)) {
        thisWeekList.add(r);
      } else {
        laterList.add(r);
      }
    }

    final groups = <_ReminderGroup>[];
    if (todayList.isNotEmpty) groups.add(_ReminderGroup('Bugun', todayList));
    if (tomorrowList.isNotEmpty) groups.add(_ReminderGroup('Ertaga', tomorrowList));
    if (thisWeekList.isNotEmpty) groups.add(_ReminderGroup('Bu hafta', thisWeekList));
    if (laterList.isNotEmpty) groups.add(_ReminderGroup('Keyinroq', laterList));
    return groups;
  }
}

class _ReminderGroup {
  final String title;
  final List<Reminder> items;
  _ReminderGroup(this.title, this.items);
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedOpacity(
      duration: AppMotion.fade,
      opacity: 1.0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.tintSage,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: colors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: context.colors.primary,
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'Ma\'lumotlarni yuklashda xato',
              style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => ref.invalidate(remindersProvider),
              child: Text(
                'Qayta urinish',
                style: TextStyle(color: colors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

