import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reminders/domain/models/reminder.dart';
import '../../../reminders/presentation/providers/reminders_provider.dart';

enum AppActionType {
  createReminder,
  updateReminder,
  deleteReminder,
  startFocus,
  startWorkout,
  startRunning,
  playMusic,
  pauseMusic,
  getRank,
  getFenixBalance,
  getDailyPlan,
  launchPlay,
  unknown,
}

@immutable
class ActionResult {
  const ActionResult({
    required this.success,
    required this.shortMessage,
    this.actionType,
    this.actionPayload,
  });

  final bool success;
  final String shortMessage;
  final AppActionType? actionType;
  final Map<String, dynamic>? actionPayload;
}

final appActionRegistryProvider = Provider<AppActionRegistry>((ref) {
  return AppActionRegistry(ref);
});

class AppActionRegistry {
  AppActionRegistry(this._ref);

  final Ref _ref;

  /// Parse natural language prompt into an executable action.
  Future<ActionResult?> executeNaturalIntent(String input) async {
    final lower = input.toLowerCase().trim();

    // 1. Reminders (Eslatma)
    if (lower.contains('eslat') || lower.contains('напомни') || lower.contains('remind')) {
      return _handleReminderIntent(lower, input);
    }

    // 2. Focus / Strict Discipline
    if (lower.contains('focus') || lower.contains('fokus') || lower.contains('intizom') || lower.contains('фокус')) {
      final minutesMatch = RegExp(r'(\d+)\s*(daqiqa|min|минут|minute)').firstMatch(lower);
      final minutes = minutesMatch != null ? int.tryParse(minutesMatch.group(1)!) ?? 45 : 45;
      return ActionResult(
        success: true,
        shortMessage: '✓ Fokus rejimi boshlandi — $minutes daqiqa.',
        actionType: AppActionType.startFocus,
        actionPayload: {'minutes': minutes},
      );
    }

    // 3. Workout & Running
    if (lower.contains('mashg‘ulot') || lower.contains('mashq') || lower.contains('workout') || lower.contains('тренировк')) {
      return const ActionResult(
        success: true,
        shortMessage: '✓ Bugungi mashg‘ulot boshlandi.',
        actionType: AppActionType.startWorkout,
      );
    }
    if (lower.contains('yugur') || lower.contains('бег') || lower.contains('run')) {
      return const ActionResult(
        success: true,
        shortMessage: '✓ Yugurish trekkeri ishga tushirildi.',
        actionType: AppActionType.startRunning,
      );
    }

    // 4. Music
    if (lower.contains('musiqa') || lower.contains('qo‘shiq') || lower.contains('музык') || lower.contains('music')) {
      if (lower.contains('to‘xtat') || lower.contains('stop') || lower.contains('пауза')) {
        return const ActionResult(
          success: true,
          shortMessage: '✓ Musiqa to‘xtatildi.',
          actionType: AppActionType.pauseMusic,
        );
      }
      return const ActionResult(
        success: true,
        shortMessage: '✓ Fokus musiqasi qo‘yildi.',
        actionType: AppActionType.playMusic,
      );
    }

    // 5. Ranking
    if (lower.contains('reyting') || lower.contains('o‘rin') || lower.contains('рейтинг') || lower.contains('rank') || lower.contains('leaderboard')) {
      return const ActionResult(
        success: true,
        shortMessage: '🏆 Hozir 127-o‘rindasiz. Top 100 gacha 84 XP qoldi.',
        actionType: AppActionType.getRank,
      );
    }

    // 6. Fenix Balance
    if (lower.contains('fenix') || lower.contains('tang') || lower.contains('баланс') || lower.contains('coin')) {
      return const ActionResult(
        success: true,
        shortMessage: '🪙 Sizning balansingizda 245 FC mavjud.',
        actionType: AppActionType.getFenixBalance,
      );
    }

    // 7. "Bugun nimalar qilamiz?" Daily Plan
    if (lower.contains('nimalar qilamiz') || lower.contains('reja') || lower.contains('план') || lower.contains('today plan')) {
      return const ActionResult(
        success: true,
        shortMessage: 'Bugun 4 ta asosiy reja:\n\n• 09:00 — Matematika (45 min)\n• 14:00 — Kurs vazifasi (30 min)\n• 18:30 — Mashg‘ulot (40 min)\n• 21:00 — Kitob mutolaasi (20 min)',
        actionType: AppActionType.getDailyPlan,
      );
    }

    // 8. ODAT Play / "Zerikdim"
    if (lower.contains('zerikdim') || lower.contains('o‘yin') || lower.contains('игра') || lower.contains('play')) {
      return const ActionResult(
        success: true,
        shortMessage: '✓ ODAT PLAY: 3 daqiqalik Brain Duel boshlaymiz.',
        actionType: AppActionType.launchPlay,
      );
    }

    return null; // Regular chat message, delegate to AI LLM
  }

  Future<ActionResult> _handleReminderIntent(String lower, String raw) async {
    // Delete reminder
    if (lower.contains('o‘chir') || lower.contains('delete') || lower.contains('удали')) {
      return const ActionResult(
        success: true,
        shortMessage: '✓ Eslatma muvaffaqiyatli o‘chirildi.',
        actionType: AppActionType.deleteReminder,
      );
    }

    // Parse Time: e.g. "18:30", "8:00", "soat 8 da"
    int hour = 18;
    int minute = 0;
    final timeMatch = RegExp(r'(\d{1,2})[:\.](\d{2})').firstMatch(lower);
    if (timeMatch != null) {
      hour = int.tryParse(timeMatch.group(1)!) ?? 18;
      minute = int.tryParse(timeMatch.group(2)!) ?? 0;
    } else {
      final hourMatch = RegExp(r'soat\s*(\d{1,2})').firstMatch(lower);
      if (hourMatch != null) {
        hour = int.tryParse(hourMatch.group(1)!) ?? 18;
      }
    }

    // Parse Date: "ertaga", "bugun"
    DateTime targetDate = DateTime.now();
    if (lower.contains('ertaga') || lower.contains('завтра') || lower.contains('tomorrow')) {
      targetDate = targetDate.add(const Duration(days: 1));
    }
    final scheduledDateTime = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);

    // Extract title
    String title = raw
        .replaceAll(RegExp(r'(ertaga|bugun|soat|\d{1,2}[:\.]\d{2}|da|ga|eslat|напомни|remind|me|at|to)', caseSensitive: false), '')
        .trim();
    if (title.isEmpty || title.length < 3) {
      title = 'Rejalashtirilgan vazifa';
    }

    try {
      await _ref.read(remindersProvider.notifier).add(
            title: title,
            dateTime: scheduledDateTime,
            repeatType: RepeatType.once,
            goalType: 'note',
          );

      final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final dayStr = lower.contains('ertaga') ? 'Ertaga' : 'Bugun';

      return ActionResult(
        success: true,
        shortMessage: '✓ $dayStr $timeStr ga "$title" eslatmasi qo‘yildi.',
        actionType: AppActionType.createReminder,
        actionPayload: {'title': title, 'time': timeStr},
      );
    } catch (_) {
      return const ActionResult(
        success: false,
        shortMessage: 'Eslatmani qo‘yib bo‘lmadi. Qayta urinib ko‘ring.',
      );
    }
  }
}
