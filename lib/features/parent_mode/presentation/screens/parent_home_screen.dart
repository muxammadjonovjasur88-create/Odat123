import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/locale_store.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../../domain/family_goal_models.dart';
import '../../domain/family_models.dart';
import '../../domain/family_place_models.dart';
import '../providers/family_goals_provider.dart';
import '../providers/family_places_provider.dart';
import '../providers/family_providers.dart';
import '../widgets/add_child_dialog.dart';
import '../widgets/add_family_place_dialog.dart';
import '../widgets/create_parent_goal_dialog.dart';
import '../widgets/parent_ai_consultant_dialog.dart';
import '../widgets/send_envelope_gift_dialog.dart';

// ─── Color palette ─────────────────────────────────────────────────────
const _bg = Color(0xFF080B14);
const _card = Color(0xFF0D1220);
const _cardBorder = Color(0xFF1C2540);
const _green = Color(0xFF3B9BFF);
const _cyan = Color(0xFF00BCD4);
const _amber = Color(0xFFFFB300);
const _purple = Color(0xFF7B2FFF);
// ────────────────────────────────────────────────────────────────────────

class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0; // 0:Asosiy  1:Xarita  2:Hisobot  3:Maqsad
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────
  String get _childName {
    final live = ref.watch(childLiveStatusProvider).asData?.value;
    return live?.name ?? '';
  }

  bool get _hasChild {
    final status = ref.watch(childLiveStatusProvider);
    if (status.isLoading) return true; // prevent flashing add button while loading
    return status.value != null;
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildAppBar()],
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHomeTab(),
                  _buildMapTab(),
                  _buildReportTab(),
                  _buildGoalsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _bg,
      elevation: 0,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_green, _cyan],
              ),
            ),
            child: const Icon(Icons.supervisor_account_rounded,
                color: _bg, size: 20),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ODAT PARENTS',
                style: TextStyle(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                _hasChild ? _childName : 'parent_home.app_bar_subtitle'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Add child button
        if (!_hasChild)
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded,
                color: _green, size: 22),
            tooltip: 'parent_home.tooltip_add_child'.tr(),
            onPressed: () {
              HapticFeedback.lightImpact();
              showDialog(
                  context: context, builder: (_) => const AddChildDialog());
            },
          ),
        // Settings menu
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showParentSettingsSheet(context);
          },
        ),
        SizedBox(width: 4),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  TAB BAR
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      (Icons.home_rounded, 'parent_home.tab_main'.tr()),
      (Icons.map_rounded, 'parent_home.tab_map'.tr()),
      (Icons.bar_chart_rounded, 'parent_home.tab_report'.tr()),
      (Icons.track_changes_rounded, 'parent_home.tab_goal'.tr()),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tab == i;
          final (icon, label) = tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _tabController.animateTo(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? _green.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? _green.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        color: selected ? _green : Colors.white38, size: 20),
                    SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? _green : Colors.white38,
                        fontSize: 10.5,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  PARENT SETTINGS SHEET
  // ─────────────────────────────────────────────────────────────────────
  void _showParentSettingsSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _ParentSettingsSheet(
        onSwitchToPersonal: () async {
          Navigator.pop(sheetCtx);
          final uid = ref.read(authStateProvider).asData?.value?.uid;
          if (uid != null) {
            await ref.read(userRepositoryProvider).updateRole(
              uid,
              appRole: 'personal',
            );
          }
          if (ctx.mounted) ctx.go(AppRoutes.dailyPlan);
        },
        onSignOut: () {
          Navigator.pop(sheetCtx);
          ref.read(authRepositoryProvider).signOut();
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //  TAB 0 — ASOSIY
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    final liveAsync = ref.watch(childLiveStatusProvider);
    final pendingAsync = ref.watch(pendingExtraTimeRequestsProvider);

    return RefreshIndicator(
      color: _green,
      backgroundColor: _card,
      onRefresh: () async {
        ref.invalidate(childLiveStatusProvider);
        ref.invalidate(pendingExtraTimeRequestsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ── Child Status Card ──────────────────────────────
          liveAsync.when(
            data: (child) => child == null
                ? _NoChildCard(
                    onAddChild: () => showDialog(
                        context: context,
                        builder: (ctx) => const AddChildDialog()),
                  )
                : _ChildStatusCard(child: child),
            loading: () => const _LoadingCard(),
            error: (e, s) => _NoChildCard(
              onAddChild: () => showDialog(
                  context: context,
                  builder: (ctx) => const AddChildDialog()),
            ),
          ),
          SizedBox(height: 16),

          // ── Extra Time Requests ─────────────────────────────
          pendingAsync.when(
            data: (reqs) => reqs.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: reqs
                        .map((r) => _ExtraTimeRequestCard(
                              request: r,
                              onApprove: () =>
                                  setState(() {}),
                              onDecline: () =>
                                  setState(() {}),
                            ))
                        .toList(),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),

          // ── Quick Actions ───────────────────────────────────
          if (_hasChild) ...[
            SizedBox(height: 4),
            _SectionTitle(
              label: 'parent_home.quick_actions'.tr(),
              icon: Icons.bolt_rounded,
              color: _amber,
            ),
            SizedBox(height: 10),
            Row(
              children: [
                _QuickActionCard(
                  icon: Icons.card_giftcard_rounded,
                  color: _amber,
                  label: 'parent_home.action_gift'.tr(),
                  onTap: () => showSendEnvelopeGiftDialog(
                      context, childName: _childName),
                ),
                SizedBox(width: 10),
                _QuickActionCard(
                  icon: Icons.auto_awesome_rounded,
                  color: _cyan,
                  label: 'parent_home.action_ai'.tr(),
                  onTap: () => showParentAiConsultantDialog(context,
                      childName: _childName),
                ),
                SizedBox(width: 10),
                _QuickActionCard(
                  icon: Icons.map_rounded,
                  color: _green,
                  label: 'parent_home.action_map'.tr(),
                  onTap: () {
                    _tabController.animateTo(1);
                  },
                ),
                SizedBox(width: 10),
                _QuickActionCard(
                  icon: Icons.track_changes_rounded,
                  color: _purple,
                  label: 'parent_home.action_goal'.tr(),
                  onTap: () {
                    _tabController.animateTo(3);
                  },
                ),
              ],
            ),
          ],

          // ── Goals Preview ────────────────────────────────────
          if (_hasChild) ...[
            SizedBox(height: 20),
            _SectionTitle(
              label: 'parent_home.active_goals'.tr(),
              icon: Icons.track_changes_rounded,
              color: _purple,
              actionLabel: 'parent_home.see_all'.tr(),
              onAction: () => _tabController.animateTo(3),
            ),
            SizedBox(height: 10),
            _GoalsPreview(),
          ],

          SizedBox(height: 28),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //  TAB 1 — XARITA
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildMapTab() {
    final places = ref.watch(familyPlacesProvider);
    final events = ref.watch(todayPlaceEventsProvider).value ?? [];
    final liveAsync = ref.watch(childLiveStatusProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Live location HUD
        liveAsync.when(
          data: (child) => child == null
              ? const _MapNoConnectionCard()
              : _LiveMapCard(child: child),
          loading: () => const _LoadingCard(),
          error: (e, s) => const _MapNoConnectionCard(),
        ),
        SizedBox(height: 20),

        // Safe Zones
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(
              label: 'parent_home.safe_zones'.tr(),
              icon: Icons.shield_rounded,
              color: _green,
            ),
            BouncyScale(
              onTap: () {
                HapticFeedback.lightImpact();
                showDialog(
                    context: context,
                    builder: (_) => const AddFamilyPlaceDialog());
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, color: _green, size: 15),
                    SizedBox(width: 4),
                    Text('parent_home.add_place'.tr(),
                        style: const TextStyle(
                            color: _green,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        if (places.isEmpty)
          _EmptyState(
            icon: Icons.location_off_rounded,
            title: 'parent_home.no_places_title'.tr(),
            subtitle: 'parent_home.no_places_subtitle'.tr().replaceAll('\\n', '\n'),
            actionLabel: 'parent_home.add_place'.tr(),
            onAction: () => showDialog(
                context: context, builder: (_) => const AddFamilyPlaceDialog()),
          )
        else
          ...places.map((p) => _SafeZoneCard(
                place: p,
                onDelete: () =>
                    ref.read(familyPlacesProvider.notifier).removePlace(p.id),
                onToggleArrival: (v) => ref
                    .read(familyPlacesProvider.notifier)
                    .toggleArrivalAlert(p.id, v),
                onToggleDeparture: (v) => ref
                    .read(familyPlacesProvider.notifier)
                    .toggleDepartureAlert(p.id, v),
              )),

        // Today's timeline
        if (events.isNotEmpty) ...[
          SizedBox(height: 20),
          _SectionTitle(
              label: 'parent_home.todays_movement'.tr(), icon: Icons.history_rounded, color: _cyan),
          SizedBox(height: 10),
          _EventsTimeline(events: events),
        ],

        SizedBox(height: 28),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //  TAB 2 — HISOBOT
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildReportTab() {
    final verificationsAsync = ref.watch(recentStudyVerificationsProvider);
    final interestsAsync = ref.watch(learningInterestsProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // App Usage Section
        _SectionTitle(
            label: 'parent_home.app_time'.tr(), icon: Icons.phonelink_setup_rounded, color: _cyan),
        SizedBox(height: 10),
        _AppUsageCard(),
        SizedBox(height: 20),

        // AI Maslahat
        _SectionTitle(
            label: 'parent_home.action_ai'.tr(), icon: Icons.auto_awesome_rounded, color: _amber),
        SizedBox(height: 10),
        _AiConsultCard(
          childName: _childName,
          onTap: () => showParentAiConsultantDialog(context, childName: _childName),
        ),
        SizedBox(height: 20),

        // Study verifications
        verificationsAsync.when(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                    label: 'parent_home.ai_learning_results'.tr(),
                    icon: Icons.school_rounded,
                    color: _amber),
                SizedBox(height: 10),
                ...list.map((v) => _StudyVerificationCard(ver: v)),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
        ),

        // Interests
        interestsAsync.when(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                _SectionTitle(
                    label: 'parent_home.interests_analysis'.tr(),
                    icon: Icons.psychology_rounded,
                    color: _cyan),
                SizedBox(height: 10),
                _InterestsCard(interests: list),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
        ),

        if (!_hasChild)
          _EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'parent_home.no_data_title'.tr(),
            subtitle: 'parent_home.no_data_subtitle'.tr().replaceAll('\\n', '\n'),
            actionLabel: 'parent_home.tooltip_add_child'.tr(),
            onAction: () => showDialog(
                context: context, builder: (_) => const AddChildDialog()),
          ),

        SizedBox(height: 28),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //  TAB 3 — MAQSAD
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildGoalsTab() {
    final goals = ref.watch(familyGoalsProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Create new goal CTA
        _CreateGoalBanner(
          onTap: () => showDialog(
              context: context, builder: (_) => const CreateParentGoalDialog()),
        ),
        SizedBox(height: 20),

        _SectionTitle(
            label: 'parent_home.assigned_goals'.tr(),
            icon: Icons.track_changes_rounded,
            color: _purple),
        SizedBox(height: 10),

        if (goals.isEmpty)
          _EmptyState(
            icon: Icons.track_changes_outlined,
            title: 'parent_home.no_goals_title'.tr(),
            subtitle: 'parent_home.no_goals_subtitle'.tr().replaceAll('\\n', '\n'),
            actionLabel: 'parent_home.new_goal'.tr(),
            onAction: () => showDialog(
                context: context, builder: (_) => const CreateParentGoalDialog()),
          )
        else
          ...goals.map((g) => _GoalCard(goal: g)),

        SizedBox(height: 28),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// LANGUAGE TOGGLE BUTTON
// ═════════════════════════════════════════════════════════════════════════
class _LanguageToggleButton extends StatefulWidget {
  @override
  State<_LanguageToggleButton> createState() => _LanguageToggleButtonState();
}

class _LanguageToggleButtonState extends State<_LanguageToggleButton> {
  final List<Map<String, String>> _langs = const [
    {'code': 'uz', 'flag': '🇺🇿', 'name': 'UZ'},
    {'code': 'ru', 'flag': '🇷🇺', 'name': 'RU'},
    {'code': 'en', 'flag': '🇬🇧', 'name': 'EN'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentCode = LocaleStore.effectiveCode();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showLangSheet(context, currentCode);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _langs.firstWhere((l) => l['code'] == currentCode,
                  orElse: () => _langs.first)['flag']!,
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(width: 4),
            Text(
              currentCode.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  void _showLangSheet(BuildContext ctx, String current) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'parent_home.language_select'.tr(),
              style: const TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 16),
            ..._langs.map((lang) {
              final isSelected = lang['code'] == current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ctx.setLocale(Locale(lang['code']!));
                    await LocaleStore.save(lang['code']!);
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _green.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? _green.withValues(alpha: 0.5)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(lang['flag']!,
                            style: const TextStyle(fontSize: 24)),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang['name']!,
                              style: TextStyle(
                                color:
                                    isSelected ? _green : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              lang['code'] == 'uz'
                                  ? 'O\'zbekcha (Lotin)'
                                  : lang['code'] == 'ru'
                                      ? 'Русский язык'
                                      : 'English',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: _green, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
  });
  final String label;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

// ── Child Status Card ────────────────────────────────────────────────
class _ChildStatusCard extends StatelessWidget {
  const _ChildStatusCard({required this.child});
  final ChildLiveStatus child;

  @override
  Widget build(BuildContext context) {
    final isLowBat = child.batteryLevel < 20;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _green.withValues(alpha: 0.12),
            _card,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _green.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: _green.withValues(alpha: 0.08), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_green, _cyan]),
                ),
                child: Center(
                  child: Icon(Icons.face_rounded, color: _bg, size: 30),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          child.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900),
                        ),
                        SizedBox(width: 8),
                        // Online indicator
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: child.isOnline
                                ? _green
                                : Colors.white38,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          child.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: child.isOnline ? _green : Colors.white38,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: _cyan, size: 13),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${child.locationName} • ${child.locationUpdatedAtStr}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Battery
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLowBat
                        ? Colors.redAccent
                        : _green.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      child.isCharging
                          ? Icons.battery_charging_full_rounded
                          : Icons.battery_full_rounded,
                      color: isLowBat ? Colors.redAccent : _green,
                      size: 15,
                    ),
                    SizedBox(width: 3),
                    Text(
                      '${child.batteryLevel}%',
                      style: TextStyle(
                        color: isLowBat ? Colors.redAccent : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Metrics
          Row(
            children: [
              _MetricBox(
                icon: Icons.phonelink_setup_rounded,
                iconColor: _cyan,
                label: 'parent_home.screen_time'.tr(),
                value: child.formattedScreenTime,
              ),
              SizedBox(width: 8),
              _MetricBox(
                icon: Icons.school_rounded,
                iconColor: _amber,
                label: 'parent_home.study'.tr(),
                value: child.formattedStudyTime,
              ),
              SizedBox(width: 8),
              _MetricBox(
                icon: Icons.verified_rounded,
                iconColor: _green,
                label: 'parent_home.discipline'.tr(),
                value: '${child.disciplineScore}',
              ),
            ],
          ),
          // Progress bar
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: child.dailyProgressPercent / 100,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(_green),
                    minHeight: 6,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'parent_home.tasks_count'.tr(namedArgs: {'completed': '${child.todayTasksCompleted}', 'total': '${child.todayTasksTotal}'}),
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 16),
            SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 9.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── No Child Card ────────────────────────────────────────────────────
class _NoChildCard extends StatelessWidget {
  const _NoChildCard({required this.onAddChild});
  final VoidCallback onAddChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withValues(alpha: 0.1),
              border: Border.all(color: _green.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: _green, size: 34),
          ),
          SizedBox(height: 16),
          Text(
            'parent_home.no_child_title'.tr(),
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'parent_home.no_child_subtitle'.tr().replaceAll('\\n', '\n'),
            style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.4),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onAddChild,
            icon: const Icon(Icons.add_rounded, size: 18, color: _bg),
            label: Text('parent_home.btn_add_child'.tr(),
                style: TextStyle(
                    color: _bg, fontWeight: FontWeight.w900, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading Card ─────────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Center(
        child: CircularProgressIndicator(color: _green, strokeWidth: 2),
      ),
    );
  }
}

// ── Extra Time Request Card ──────────────────────────────────────────
class _ExtraTimeRequestCard extends StatelessWidget {
  const _ExtraTimeRequestCard({
    required this.request,
    required this.onApprove,
    required this.onDecline,
  });
  final ExtraTimeRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [_amber.withValues(alpha: 0.12), _card]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _amber.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _amber.withValues(alpha: 0.2)),
                child: const Icon(Icons.timer_outlined, color: _amber, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('parent_home.extra_time_req'.tr(),
                        style: TextStyle(
                            color: _amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                    Text(
                      '${request.childName}: ${request.appName} (+${request.requestedMinutes} daqiqa)',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('parent_home.btn_decline'.tr(),
                      style: TextStyle(
                          color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'parent_home.btn_allow_mins'.tr(namedArgs: {'mins': '${request.requestedMinutes}'}),
                    style: const TextStyle(
                        color: _bg, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BouncyScale(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Goals Preview ─────────────────────────────────────────────────────
class _GoalsPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(familyGoalsProvider);
    if (goals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white38, size: 18),
            SizedBox(width: 10),
            Text('parent_home.no_goals_yet'.tr(),
                style: TextStyle(color: Colors.white38, fontSize: 12.5)),
          ],
        ),
      );
    }
    return Column(
      children: goals.take(3).map((g) => _GoalCard(goal: g)).toList(),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final FamilyGoal goal;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (goal.status) {
      case FamilyGoalStatus.pending:
        statusColor = _amber;
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = 'parent_home.status_pending'.tr();
        break;
      case FamilyGoalStatus.accepted:
        statusColor = _green;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'parent_home.status_accepted'.tr();
        break;
      case FamilyGoalStatus.completed:
        statusColor = _cyan;
        statusIcon = Icons.emoji_events_rounded;
        statusLabel = 'parent_home.status_completed'.tr();
        break;
      case FamilyGoalStatus.declined:
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'parent_home.status_declined'.tr();
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.15),
            ),
            child: Icon(statusIcon, color: statusColor, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(
                  '${goal.scheduledTime} • ${goal.targetValue} ${goal.unit} • +${goal.rewardCoins} FC',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ── Live Map Card ─────────────────────────────────────────────────────
class _LiveMapCard extends ConsumerWidget {
  const _LiveMapCard({required this.child});
  final ChildLiveStatus child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveLoc = ref.watch(childLiveLocationStreamProvider).value;
    final lat = (liveLoc?['lat'] as num?)?.toDouble();
    final lng = (liveLoc?['lng'] as num?)?.toDouble();
    final isOnline = liveLoc?['isOnline'] == true;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(AppRoutes.parentLocation);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _green.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.08), blurRadius: 20)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Map area
              Container(
                height: 190,
                color: const Color(0xFF0A1628),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer geofence ring
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _green.withValues(alpha: 0.05),
                        border: Border.all(
                            color: _green.withValues(alpha: 0.2), width: 1),
                      ),
                    ),
                    // Inner geofence ring
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _green.withValues(alpha: 0.1),
                      ),
                    ),
                    // Child pin
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _green,
                            boxShadow: [
                              BoxShadow(
                                  color: _green.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  spreadRadius: 3),
                            ],
                          ),
                          child: const Icon(Icons.face_rounded, color: _bg, size: 22),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _green.withValues(alpha: 0.5)),
                          ),
                          child: Text(child.name,
                              style: const TextStyle(
                                  color: _green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    // Live badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _bg.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isOnline ? const Color(0xFF00FF88) : _green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: isOnline ? const Color(0xFF00FF88) : _green),
                            ),
                            SizedBox(width: 5),
                            Text(isOnline ? 'JONLI GPS' : child.locationUpdatedAtStr,
                                style: TextStyle(
                                    color: isOnline ? const Color(0xFF00FF88) : _green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    // Open full map badge
                    Positioned(
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xCC08121E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_rounded, color: _green, size: 13),
                            SizedBox(width: 5),
                            Text(
                              'parent_home.open_full_map'.tr(),
                              style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom info
              Container(
                color: _card,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: _cyan, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.locationName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700),
                          ),
                          if (lat != null && lng != null)
                            Text(
                              '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                              style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (child.batteryLevel < 20
                                ? Colors.redAccent
                                : _green)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (child.batteryLevel < 20
                                  ? Colors.redAccent
                                  : _green)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            child.isCharging
                                ? Icons.battery_charging_full_rounded
                                : Icons.battery_full_rounded,
                            color: child.batteryLevel < 20
                                ? Colors.redAccent
                                : _green,
                            size: 13,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '${child.batteryLevel}%',
                            style: TextStyle(
                              color: child.batteryLevel < 20
                                  ? Colors.redAccent
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Map No Connection Card ────────────────────────────────────────────
class _MapNoConnectionCard extends StatelessWidget {
  const _MapNoConnectionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_rounded, color: Colors.white38, size: 36),
          SizedBox(height: 10),
          Text('parent_home.no_gps_title'.tr(),
              style:
                  TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
          Text('parent_home.no_gps_subtitle'.tr(),
              style: TextStyle(color: Colors.white38, fontSize: 11.5)),
        ],
      ),
    );
  }
}

// ── Safe Zone Card ────────────────────────────────────────────────────
class _SafeZoneCard extends StatelessWidget {
  const _SafeZoneCard({
    required this.place,
    required this.onDelete,
    required this.onToggleArrival,
    required this.onToggleDeparture,
  });
  final FamilyPlace place;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleArrival;
  final ValueChanged<bool> onToggleDeparture;

  static const _iconMap = {
    'home': Icons.home_rounded,
    'school': Icons.school_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'precision_manufacturing': Icons.precision_manufacturing_rounded,
    'store': Icons.store_rounded,
    'local_hospital': Icons.local_hospital_rounded,
    'mosque': Icons.mosque_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[place.iconName] ?? Icons.place_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _green, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${place.address} • ${place.radiusMeters.round()}m',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white24, size: 20),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.login_rounded, size: 13, color: Colors.white38),
              SizedBox(width: 4),
              Expanded(
                child: Text('parent_home.alert_on_arrival'.tr(),
                    style: TextStyle(color: Colors.white54, fontSize: 11.5)),
              ),
              Switch.adaptive(
                value: place.notifyOnArrival,
                onChanged: onToggleArrival,
                activeThumbColor: _green,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              SizedBox(width: 8),
              const Icon(Icons.logout_rounded, size: 13, color: Colors.white38),
              SizedBox(width: 4),
              Expanded(
                child: Text('parent_home.alert_on_departure'.tr(),
                    style: TextStyle(color: Colors.white54, fontSize: 11.5)),
              ),
              Switch.adaptive(
                value: place.notifyOnDeparture,
                onChanged: onToggleDeparture,
                activeThumbColor: _cyan,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Events Timeline ───────────────────────────────────────────────────
class _EventsTimeline extends StatelessWidget {
  const _EventsTimeline({required this.events});
  final List<PlaceEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: events.map((ev) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(ev.timeStr,
                    style: const TextStyle(
                        color: _cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ev.isArrival
                        ? _green.withValues(alpha: 0.2)
                        : _cyan.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    ev.isArrival
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 11,
                    color: ev.isArrival ? _green : _cyan,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${ev.placeName} — ${ev.isArrival ? "Yetib keldi" : "Chiqdi"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Text('${ev.batteryLevel}%',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10.5)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── App Usage Card ────────────────────────────────────────────────────
class _AppUsageCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasChild = ref.watch(childLiveStatusProvider).asData?.value != null;

    if (!hasChild) {
      return _EmptyState(
        icon: Icons.phonelink_setup_rounded,
        title: 'parent_home.no_app_time_title'.tr(),
        subtitle: 'parent_home.no_app_time_subtitle'.tr().replaceAll('\\n', '\n'),
      );
    }

    final usageAsync = ref.watch(childAppUsageProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: usageAsync.when(
        data: (stats) {
          if (stats.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Hozircha ilova vaqti haqida ma\'lumot yo\'q. Bolaning qurilmasida Usage Access ruxsati berilganligiga ishonch hosil qiling.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white38, size: 15),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'parent_home.time_spent_in_apps'.tr(),
                      style: TextStyle(color: Colors.white54, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              ...stats.map((stat) {
                // Determine a color based on category or just a default vibrant color
                Color barColor = _purple;
                if (stat.category == 'social') barColor = const Color(0xFFE1306C);
                if (stat.category == 'games') barColor = _amber;
                if (stat.category == 'education') barColor = _green;

                return _AppUsageBar(
                  appName: stat.appName,
                  usageMin: stat.usageMinutes,
                  limitMin: stat.limitMinutes,
                  color: barColor,
                );
              }),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('Xatolik: $e', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }
}

class _AppUsageBar extends StatelessWidget {
  const _AppUsageBar({
    required this.appName,
    required this.usageMin,
    required this.limitMin,
    required this.color,
  });
  final String appName;
  final int usageMin;
  final int limitMin;
  final Color color;

  String _fmt(int m) {
    if (m < 60) return '${m}d';
    return '${m ~/ 60}s ${m % 60 > 0 ? '${m % 60}d' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final ratio =
        limitMin > 0 ? (usageMin / limitMin).clamp(0.0, 1.0) : 0.6;
    final isOver = limitMin > 0 && usageMin > limitMin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(appName,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(
                    isOver ? Colors.redAccent : color),
                minHeight: 6,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            _fmt(usageMin),
            style: TextStyle(
              color: isOver ? Colors.redAccent : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Consult Card ───────────────────────────────────────────────────
class _AiConsultCard extends StatelessWidget {
  const _AiConsultCard({required this.childName, required this.onTap});
  final String childName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_amber.withValues(alpha: 0.12), _card],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _amber.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: _amber, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('parent_home.ai_consultant'.tr(),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  Text(
                    childName.isNotEmpty
                        ? 'parent_home.ask_about_child'.tr(namedArgs: {'name': childName})
                        : 'parent_home.ask_about_child_fallback'.tr(),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _amber, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Study Verification Card ───────────────────────────────────────────
class _StudyVerificationCard extends StatelessWidget {
  const _StudyVerificationCard({required this.ver});
  final AiStudyVerification ver;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: _amber, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ver.subject,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                Text(ver.topic,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11.5)),
              ],
            ),
          ),
          Text(
            '${ver.score}/${ver.totalQuestions}',
            style: const TextStyle(
                color: _green, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// ── Interests Card ────────────────────────────────────────────────────
class _InterestsCard extends StatelessWidget {
  const _InterestsCard({required this.interests});
  final List<LearningInterest> interests;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: interests.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.category,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                    Text(item.trendStr,
                        style: const TextStyle(
                            color: _green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: item.percentage / 100,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(_cyan),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Create Goal Banner ────────────────────────────────────────────────
class _CreateGoalBanner extends StatelessWidget {
  const _CreateGoalBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _purple.withValues(alpha: 0.25),
              _card,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _purple.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _purple.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.add_task_rounded, color: _purple, size: 26),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('parent_home.new_goal'.tr(),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text(
                    'parent_home.new_goal_subtitle'.tr(),
                    style: TextStyle(
                        color: Colors.white54, fontSize: 11.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _purple, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 42),
          SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(subtitle,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
              textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(actionLabel!,
                  style: const TextStyle(
                      color: _green, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// PARENT SETTINGS SHEET
// Full-featured bottom sheet: language, switch mode, sign out
// ═════════════════════════════════════════════════════════════════════════
class _ParentSettingsSheet extends StatefulWidget {
  const _ParentSettingsSheet({
    required this.onSwitchToPersonal,
    required this.onSignOut,
  });

  final VoidCallback onSwitchToPersonal;
  final VoidCallback onSignOut;

  @override
  State<_ParentSettingsSheet> createState() => _ParentSettingsSheetState();
}

class _ParentSettingsSheetState extends State<_ParentSettingsSheet> {
  final List<Map<String, String>> _langs = const [
    {'code': 'uz', 'flag': '🇺🇿', 'name': "O'zbekcha"},
    {'code': 'ru', 'flag': '🇷🇺', 'name': 'Русский'},
    {'code': 'en', 'flag': '🇬🇧', 'name': 'English'},
  ];

  bool _showLangPicker = false;

  @override
  Widget build(BuildContext context) {
    final currentCode = context.locale.languageCode;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, color: _green, size: 18),
                ),
                SizedBox(width: 12),
                Text(
                  'parent_home.parent_settings'.tr(),
                  style: TextStyle(
                    color: _green,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
          SizedBox(height: 8),

          // ── Language Section ──────────────────────────────────────
          _SettingsTile(
            icon: Icons.language_rounded,
            iconColor: _cyan,
            title: 'parent_home.select_language'.tr(),
            subtitle: _langs.firstWhere(
                  (l) => l['code'] == currentCode,
                  orElse: () => _langs.first,
                )['name']!,
            trailing: Icon(
              _showLangPicker
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white38,
              size: 20,
            ),
            onTap: () => setState(() => _showLangPicker = !_showLangPicker),
          ),

          if (_showLangPicker) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: _langs.map((lang) {
                  final isSelected = lang['code'] == currentCode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await context.setLocale(Locale(lang['code']!));
                        await LocaleStore.save(lang['code']!);
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _green.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _green.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(lang['flag']!,
                                style: const TextStyle(fontSize: 20)),
                            SizedBox(width: 12),
                            Text(
                              lang['name']!,
                              style: TextStyle(
                                color: isSelected ? _green : Colors.white70,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(Icons.check_rounded,
                                  color: _green, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),

          // ── Switch to Personal ODAT ───────────────────────────────
          _SettingsTile(
            icon: Icons.swap_horiz_rounded,
            iconColor: _amber,
            title: 'Oddiy ODAT ga o\'tish',
            subtitle: 'Shaxsiy rejimga qaytish (bola rejimi)',
            onTap: () {
              HapticFeedback.heavyImpact();
              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  backgroundColor: _card,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Text(
                    'Rejimni almashtirish',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  content: Text(
                    'Shaxsiy ODAT ga o\'tmoqchimisiz?\nOta-ona panelidan chiqasiz.',
                    style: TextStyle(color: Colors.white60, fontSize: 13.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx),
                      child: Text('Bekor qilish',
                          style: TextStyle(color: Colors.white38)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _amber,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(dCtx);
                        widget.onSwitchToPersonal();
                      },
                      child: Text('Ha, o\'tish',
                          style: TextStyle(
                              color: _bg, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              );
            },
          ),

          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),

          // ── Sign Out ─────────────────────────────────────────────
          _SettingsTile(
            icon: Icons.logout_rounded,
            iconColor: Colors.redAccent,
            title: 'Akkauntdan chiqish',
            subtitle: 'ODAT dan to\'liq chiqish',
            onTap: () {
              HapticFeedback.heavyImpact();
              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  backgroundColor: _card,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Text(
                    'parent_home.logout'.tr(),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  content: Text(
                    'Akkauntdan chiqmoqchimisiz?',
                    style: TextStyle(color: Colors.white60, fontSize: 13.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx),
                      child: Text('Bekor qilish',
                          style: TextStyle(color: Colors.white38)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(dCtx);
                        widget.onSignOut();
                      },
                      child: Text('parent_home.logout'.tr(),
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11.5)),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.arrow_forward_ios_rounded,
                    color: iconColor.withValues(alpha: 0.6), size: 14),
          ],
        ),
      ),
    );
  }
}
