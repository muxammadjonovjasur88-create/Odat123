import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/utils/formatting.dart';
import '../../blocking/data/blocking_repository.dart';
import '../../deep_focus/data/focus_providers.dart';
import '../../deep_focus/data/focus_service.dart';
import '../../notifications/data/notification_service.dart';
import '../../premium/data/premium_providers.dart';
import '../data/ai_planner_service.dart';
import '../domain/planned_task.dart';

enum AiPlanStatus { idle, loading, ready, error, limitReached }

/// State for the AI planner flow: empty → generating → preview → accepting.
class AiPlanState {
  const AiPlanState({
    this.status = AiPlanStatus.idle,
    this.plan = const [],
    this.warnings = const [],
    this.progressText,
    this.goalText = '',
    this.days = 1,
    this.locale = 'en',
    this.errorMessage,
    this.accepting = false,
  });

  final AiPlanStatus status;
  final List<PlannedTask> plan;
  final List<String> warnings;
  final String? progressText;
  final String goalText;

  /// Number of days the current plan spans (1 = today only).
  final int days;

  /// BCP-47 language code of the app UI when the plan was requested.
  /// Stored so [AiPlannerController.regenerate] can reuse the same locale.
  final String locale;

  final String? errorMessage;
  final bool accepting;

  AiPlanState copyWith({
    AiPlanStatus? status,
    List<PlannedTask>? plan,
    List<String>? warnings,
    String? progressText,
    String? goalText,
    int? days,
    String? locale,
    String? errorMessage,
    bool? accepting,
    bool clearError = false,
  }) {
    return AiPlanState(
      status: status ?? this.status,
      plan: plan ?? this.plan,
      warnings: warnings ?? this.warnings,
      progressText: progressText ?? this.progressText,
      goalText: goalText ?? this.goalText,
      days: days ?? this.days,
      locale: locale ?? this.locale,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      accepting: accepting ?? this.accepting,
    );
  }
}

class AiPlannerController extends Notifier<AiPlanState> {
  @override
  AiPlanState build() => const AiPlanState();

  /// Generates a plan. [days] forces a planning span; when null, the span is
  /// detected from the goal text (e.g. "in 10 days"), defaulting to 1 day.
  /// [locale] is the BCP-47 language code (e.g. 'uz', 'ru', 'en') used to
  /// instruct Gemini to reply in the correct language.
  Future<void> generate(
    String goalText, {
    int? days,
    String locale = 'en',
  }) async {
    final text = goalText.trim();
    if (text.length < 3) {
      state = state.copyWith(
        status: AiPlanStatus.error,
        errorMessage: 'aiplan.error_too_short'.tr(),
      );
      return;
    }

    // Enforce the free daily AI-plan limit (no-op when premium is off or the
    // user is premium).
    if (!ref.read(canGenerateAiProvider)) {
      state = state.copyWith(
        status: AiPlanStatus.limitReached,
        clearError: true,
      );
      return;
    }

    final spanDays = (days ?? _parseSpanDays(text) ?? 1).clamp(1, 30);

    state = state.copyWith(
      status: AiPlanStatus.loading,
      goalText: text,
      days: spanDays,
      locale: locale,
      clearError: true,
      warnings: [],
      progressText: null,
    );

    final profile = ref.read(userProfileProvider).asData?.value;
    final today = DateUtils.dateOnly(DateTime.now());

    // Build busy-time ranges for EVERY day in the planning span, not just today.
    final busyTimesByDay = <String, List<Map<String, String>>>{};
    for (var i = 0; i < spanDays; i++) {
      final day = today.add(Duration(days: i));
      final existing =
          ref.read(tasksForDayProvider(day)).asData?.value ?? const [];
      if (existing.isNotEmpty) {
        busyTimesByDay[_isoDate(day)] = [
          for (final t in existing)
            {
              'start': formatHm24(t.startMinute),
              'end': formatHm24(t.startMinute + t.durationMinutes),
            },
        ];
      }
    }

    // Build a personalised user-context block from the live profile.
    final userContext = <String, String>{};
    if (profile != null) {
      if (profile.streak > 0) {
        userContext['Current streak'] = '${profile.streak} days';
      }
      if (profile.weeklyFocusMinutes > 0) {
        final h = profile.weeklyFocusMinutes ~/ 60;
        final m = profile.weeklyFocusMinutes % 60;
        userContext['Focus this week'] =
            h > 0 ? '${h}h ${m}min' : '${m}min';
      }
      if (profile.totalFocusMinutes > 0) {
        final totalH = (profile.totalFocusMinutes / 60).toStringAsFixed(0);
        userContext['Lifetime focus'] = '${totalH}h';
      }
      final goalTitle = profile.goalTitle?.trim();
      if (goalTitle != null && goalTitle.isNotEmpty) {
        userContext['Stated goal'] = goalTitle;
      }
      final goalWhy = profile.goalWhy?.trim();
      if (goalWhy != null && goalWhy.isNotEmpty) {
        userContext['Motivation'] = goalWhy;
      }
    }

    try {
      final planResult = await ref
          .read(aiPlannerServiceProvider)
          .generatePlan(
            goalText: text,
            focusType: profile?.focusType ?? 'Study',
            startDate: today,
            days: spanDays,
            busyTimesByDay: busyTimesByDay,
            userContext: userContext,
            locale: locale,
            onProgress: (msg) {
              state = state.copyWith(progressText: msg);
            },
          );
      state = state.copyWith(
        status: AiPlanStatus.ready,
        plan: planResult.tasks,
        warnings: planResult.warnings,
      );
      // Count this successful plan toward today's free quota (only while the
      // limit applies — i.e. premium on and the user is free).
      if (ref.read(premiumEnabledProvider) && !ref.read(isPremiumProvider)) {
        final uid = ref.read(authStateProvider).asData?.value?.uid;
        if (uid != null) {
          await ref.read(aiUsageRepositoryProvider).incrementToday(uid);
        }
      }
    } on AiPlannerException catch (e) {
      state = state.copyWith(
        status: AiPlanStatus.error,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: AiPlanStatus.error,
        errorMessage: 'aiplan.error_retry'.tr(),
      );
    }
  }

  Future<void> regenerate() => generate(
        state.goalText,
        days: state.days,
        locale: state.locale,
      );

  // ── helpers ──────────────────────────────────────────────────────────────

  static String _isoDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Detects the overall planning span from the goal text. With several goals
  /// ("100 words in 10 days AND a book in 2 weeks"), it takes the LONGEST span
  /// so the window covers every goal. Returns null when no span is mentioned.
  static int? _parseSpanDays(String text) {
    final t = text.toLowerCase();
    int? best;
    void consider(int? n) {
      if (n != null && (best == null || n > best!)) best = n;
    }

    for (final m in RegExp(
      r'(\d+)\s*(day|days|week|weeks|month|months)',
    ).allMatches(t)) {
      final n = int.tryParse(m.group(1)!) ?? 1;
      final unit = m.group(2)!;
      if (unit.startsWith('day')) {
        consider(n);
      } else if (unit.startsWith('week')) {
        consider(n * 7);
      } else if (unit.startsWith('month')) {
        consider(n * 30);
      }
    }
    if (t.contains('fortnight')) consider(14);
    if (RegExp(r'\b(a|next|this)\s+week\b').hasMatch(t)) consider(7);
    if (RegExp(r'\b(a|next|this)\s+month\b').hasMatch(t)) consider(30);
    // "N times a/per week" implies a recurring goal over at least a week.
    if (RegExp(r'times?\s+(a|per)\s+week').hasMatch(t)) consider(7);
    return best;
  }

  /// Removes a suggestion from the preview (used by "Edit").
  void removeAt(int index) {
    final next = [...state.plan]..removeAt(index);
    state = state.copyWith(plan: next);
  }

  /// Persists every previewed task to Firestore. Returns true on success.
  Future<bool> acceptAll() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null || state.plan.isEmpty) return false;

    state = state.copyWith(accepting: true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      final notifications = ref.read(notificationServiceProvider);
      final focusService = ref.read(focusServiceProvider);
      final blockingSettings = ref.read(blockingSettingsProvider).asData?.value;
      for (final planned in state.plan) {
        final task = planned.toTask();
        final id = await repo.addTask(uid, task);
        // Schedule each accepted task's 5-min-before reminder + background
        // focus session (auto-starts at its time, even if the app is closed).
        await notifications.scheduleTaskReminder(task);
        await scheduleBackgroundFocus(
          service: focusService,
          taskId: id,
          task: task,
          settings: blockingSettings,
        );
      }
      state = const AiPlanState();
      return true;
    } catch (_) {
      state = state.copyWith(
        accepting: false,
        errorMessage: 'aiplan.error_save'.tr(),
      );
      return false;
    }
  }

  void reset() => state = const AiPlanState();
}

final aiPlannerControllerProvider =
    NotifierProvider<AiPlannerController, AiPlanState>(AiPlannerController.new);
