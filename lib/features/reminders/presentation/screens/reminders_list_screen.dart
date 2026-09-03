import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/nav_helpers.dart';
import '../../../../core/utils/ai_date_parser.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/flowa_app_bar.dart';
import '../../data/reminders_notification_service.dart';
import '../../domain/models/reminder.dart';
import '../providers/reminders_provider.dart';
import '../widgets/reminder_card.dart';
import 'add_reminder_screen.dart';

/// Main Goals & Focus Hub Screen with 1-Week Interactive Calendar & AI Scheduler.
class RemindersListScreen extends ConsumerStatefulWidget {
  const RemindersListScreen({super.key});

  @override
  ConsumerState<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends ConsumerState<RemindersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _selectedCategory = 'all';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    await svc.requestNotificationPermission();
  }

  List<DateTime> _getCurrentWeekDays() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  void _showAiMeetingSchedulerModal(BuildContext context) {
    final controller = TextEditingController();
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Color(0xFF090B18),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF4AADDC), width: 1.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFF4AADDC), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'AI Uchrashuv & Rejalashtiruvchi',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Uchrashuv yoki ishingiz haqida yozing (masalan: "Ertaga soat 15:00 da investor bilan uchrashuvim bor"). AI vaqtni avtomatik aniqlab kalendarga kiritadi.',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Uchrashuv haqida yozing...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF090B18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0x334AADDC))),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            setModalState(() => isProcessing = true);
                            try {
                              // Intelligent AI date & time parser
                              final parsed = AiDateParser.parse(text, fallbackBaseDate: _selectedDate);
                              final scheduledTime = parsed.scheduledDateTime;
                              final reminderTitle = parsed.cleanTitle;

                              await ref.read(remindersProvider.notifier).add(
                                    title: reminderTitle,
                                    dateTime: scheduledTime,
                                    repeatType: RepeatType.once,
                                  );

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                setState(() => _selectedDate = scheduledTime);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF3A7FCC),
                                    content: Text('Uchrashuv jadvalga qo‘shildi: ${DateFormat('dd-MMM HH:mm').format(scheduledTime)} 📅', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isProcessing = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4AADDC),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isProcessing
                        ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                        : const Text('JADVALGA QO‘SHISH ✨', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersProvider);
    final weekDays = _getCurrentWeekDays();
    final dayNames = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: FlowaAppBar(
        showBackButton: Navigator.canPop(context),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.zametka,
        onSelected: (tab) => goToTab(context, tab),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4AADDC),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'reminders.new_goal'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
        ),
        onPressed: () => RemindersSheet.show(context),
      ),
      body: Column(
        children: [
          // ── 1-WEEK CALENDAR GRAPHIC BAR (Tepada 1 Haftalik Grafik) ────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF090B18), Color(0xFF090B18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x334AADDC)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF4AADDC),
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF090B18),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090B18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x664AADDC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF4AADDC), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('MMMM yyyy', context.locale.languageCode).format(_selectedDate).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF4AADDC), size: 18),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4AADDC), size: 22),
                          tooltip: 'AI Uchrashuv & Rejalashtiruvchi',
                          onPressed: () => _showAiMeetingSchedulerModal(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF4AADDC), size: 20),
                          tooltip: 'Sana tanlash',
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFF4AADDC),
                                      onPrimary: Colors.black,
                                      surface: Color(0xFF090B18),
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final day = weekDays[index];
                    final isSelected = day.year == _selectedDate.year && day.month == _selectedDate.month && day.day == _selectedDate.day;
                    final isToday = day.year == DateTime.now().year && day.month == DateTime.now().month && day.day == DateTime.now().day;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedDate = day);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4AADDC)
                              : (isToday ? const Color(0x3300FF88) : Colors.transparent),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4AADDC)
                                : (isToday ? const Color(0xFF3A7FCC) : Colors.white12),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              dayNames[index],
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // ── Clean 3-Tab Bar (Faol maqsadlar / O'tib ketgan / Bajarilgan) ─────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF090B18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x224AADDC)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF4AADDC),
                  borderRadius: BorderRadius.circular(12),
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(text: 'reminders.tab_active'.tr()),
                  Tab(text: 'reminders.tab_past'.tr()),
                  Tab(text: 'reminders.tab_completed'.tr()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Tab Views ─────────────────────────────────────────────────
          Expanded(
            child: remindersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4AADDC))),
              error: (e, _) => Center(child: Text('Xatolik: $e', style: const TextStyle(color: Colors.red))),
              data: (_) => TabBarView(
                controller: _tabController,
                children: [
                  _GoalsTabView(
                    listProvider: pendingRemindersProvider,
                    selectedDate: _selectedDate,
                    filterCategory: _selectedCategory,
                    emptyIcon: Icons.track_changes_rounded,
                    emptyTitle: 'reminders.empty_active_title'.tr(),
                    emptySubtitle: 'reminders.empty_active_sub'.tr(),
                  ),
                  _GoalsTabView(
                    listProvider: pastRemindersProvider,
                    selectedDate: _selectedDate,
                    filterCategory: _selectedCategory,
                    emptyIcon: Icons.history_rounded,
                    emptyTitle: 'reminders.empty_past_title'.tr(),
                    emptySubtitle: 'reminders.empty_past_sub'.tr(),
                  ),
                  _GoalsTabView(
                    listProvider: completedRemindersProvider,
                    selectedDate: _selectedDate,
                    filterCategory: _selectedCategory,
                    emptyIcon: Icons.check_circle_outline_rounded,
                    emptyTitle: 'reminders.empty_completed_title'.tr(),
                    emptySubtitle: 'reminders.empty_completed_sub'.tr(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsTabView extends ConsumerWidget {
  const _GoalsTabView({
    required this.listProvider,
    required this.selectedDate,
    required this.filterCategory,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final Provider<List<Reminder>> listProvider;
  final DateTime selectedDate;
  final String filterCategory;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems = ref.watch(listProvider);

    final items = allItems.where((item) {
      if (filterCategory == 'focus' && !item.isFocusGoal) return false;
      if (filterCategory == 'exercise' && !item.isExerciseGoal) return false;
      if (filterCategory == 'note' && !item.isNoteGoal) return false;

      // Filter by selected date:
      if (item.repeatType == RepeatType.daily) return true;
      if (item.repeatType == RepeatType.weekly) {
        return item.dateTime.weekday == selectedDate.weekday;
      }
      // Once: only matches the specific day
      return item.dateTime.year == selectedDate.year &&
          item.dateTime.month == selectedDate.month &&
          item.dateTime.day == selectedDate.day;
    }).toList();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(emptyIcon, color: Colors.white24, size: 54),
              const SizedBox(height: 14),
              Text(
                emptyTitle,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ReminderCard(
          key: ValueKey(items[index].id),
          reminder: items[index],
          index: index,
        );
      },
    );
  }
}
