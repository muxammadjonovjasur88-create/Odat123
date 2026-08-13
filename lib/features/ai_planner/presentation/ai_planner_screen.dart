import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_category.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../data/ai_assistant_service.dart';
import '../domain/planned_task.dart';
import '../domain/weekly_analytics.dart';
import 'ai_planner_controller.dart';
import 'providers/weekly_analytics_provider.dart';

class _AiChatMessage {
  _AiChatMessage({
    required this.text,
    required this.isAi,
    required this.time,
    this.suggestedTask,
  });

  final String text;
  final bool isAi;
  final String time;
  final PlannedTask? suggestedTask;
  bool isTaskAccepted = false;
  bool isTaskDeclined = false;
}

/// Production-ready AI Assistant Screen matching the Dark/Neon theme.
/// Features Real Weekly Analytics (Haftalik tahlil), Real AI Chat Interface (Gemini Cloud Function),
/// and Task Suggestion cards with Accept / Decline flow.
class AiPlannerScreen extends ConsumerStatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  ConsumerState<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends ConsumerState<AiPlannerScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _editing = false;
  bool _isAiThinking = false;

  late final List<_AiChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _messages = [
      _AiChatMessage(
        text:
            "Salom! Men sizning Shaxsiy Zen Yordamchingizman. Haftalik natijalaringiz haqida so'rashingiz yoki yangi reja qo'shishingiz mumkin.",
        isAi: true,
        time: timeStr,
      ),
    ];
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isAiThinking) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(
        _AiChatMessage(
          text: text,
          isAi: false,
          time: timeStr,
        ),
      );
      _inputController.clear();
      _isAiThinking = true;
    });

    _scrollToBottom();

    try {
      final response = await ref.read(aiAssistantServiceProvider).ask(text);
      if (!mounted) return;

      setState(() {
        _isAiThinking = false;
        _messages.add(
          _AiChatMessage(
            text: response.reply,
            isAi: true,
            time: timeStr,
            suggestedTask: response.suggestedTask,
          ),
        );
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiThinking = false;
        _messages.add(
          _AiChatMessage(
            text:
                "Hozir javob bera olmayapman, birozdan keyin qayta urinib ko'ring.",
            isAi: true,
            time: timeStr,
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _acceptSuggestedTask(_AiChatMessage msg) async {
    final planned = msg.suggestedTask;
    if (planned == null) return;

    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vazifa qo\'shish uchun tizimga kiring.')),
      );
      return;
    }

    final newTask = planned.toTask();

    try {
      await ref.read(taskRepositoryProvider).addTask(uid, newTask);
      if (!mounted) return;

      setState(() {
        msg.isTaskAccepted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${planned.title}" kunlik rejangizga qo\'shildi!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vazifani saqlashda xato yuz berdi.')),
      );
    }
  }

  void _declineSuggestedTask(_AiChatMessage msg) {
    setState(() {
      msg.isTaskDeclined = true;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _acceptAllPlannerTasks() async {
    final ok = await ref.read(aiPlannerControllerProvider.notifier).acceptAll();
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('aiplan.schedule_set'.tr())));
      context.go(AppRoutes.dailyPlan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiPlannerControllerProvider);
    final analytics = ref.watch(weeklyAnalyticsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: const FlowaAppBar(),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.ai,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Section 1 (Top): Weekly Analytics ───────────────────────────
            _WeeklyAnalyticsSection(analytics: analytics),

            // ── Section 2 (Middle): AI Chat Interface ──────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length +
                    (_isAiThinking ? 1 : 0) +
                    (aiState.status != AiPlanStatus.idle ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    final msg = _messages[index];
                    return msg.isAi
                        ? _AiMessageBubble(
                            message: msg,
                            onAcceptTask: () => _acceptSuggestedTask(msg),
                            onDeclineTask: () => _declineSuggestedTask(msg),
                          )
                        : _UserMessageBubble(message: msg);
                  }

                  final typingIndex = _messages.length;
                  if (_isAiThinking && index == typingIndex) {
                    return const _TypingIndicatorBubble();
                  }

                  // AI Planner generated result block
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _AiGeneratedResult(
                      state: aiState,
                      editing: _editing,
                      onAccept: _acceptAllPlannerTasks,
                      onToggleEdit: () => setState(() => _editing = !_editing),
                      onRemove: (i) => ref
                          .read(aiPlannerControllerProvider.notifier)
                          .removeAt(i),
                      onRegenerate: () => ref
                          .read(aiPlannerControllerProvider.notifier)
                          .regenerate(),
                    ),
                  );
                },
              ),
            ),

            // ── Section 3 (Bottom): Chat Input Field ───────────────────────
            _ChatInputField(
              controller: _inputController,
              isThinking: _isAiThinking,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section 1: Weekly Analytics Component ──────────────────────────────────
class _WeeklyAnalyticsSection extends StatelessWidget {
  const _WeeklyAnalyticsSection({required this.analytics});

  final WeeklyAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);
    const purple = Color(0xFFAA00FF);

    final days = ['Dush', 'Sesh', 'Chor', 'Pay', 'Jum', 'Shan', 'Yak'];
    final rates = analytics.rates;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A27),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cyan.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: cyan.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      size: 18,
                      color: cyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Haftalik tahlil',
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cyan.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '${analytics.completionPercentage}% Bajarildi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Real Chart progress bars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < days.length; i++)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          height: 48,
                          width: 12,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: (48 * (i < rates.length ? rates[i] : 0.0))
                              .clamp(4.0, 48.0),
                          width: 12,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [cyan, purple],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: cyan.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[i],
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFF9E9E9E),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section 2: AI Chat Bubbles ─────────────────────────────────────────────
class _AiMessageBubble extends StatelessWidget {
  const _AiMessageBubble({
    required this.message,
    required this.onAcceptTask,
    required this.onDeclineTask,
  });

  final _AiChatMessage message;
  final VoidCallback onAcceptTask;
  final VoidCallback onDeclineTask;

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cyan.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151A27),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: cyan.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormattedAiText(
                    text: message.text,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    cyanColor: cyan,
                  ),
                  if (message.suggestedTask != null) ...[
                    _TaskSuggestionCard(
                      task: message.suggestedTask!,
                      isAccepted: message.isTaskAccepted,
                      isDeclined: message.isTaskDeclined,
                      onAccept: onAcceptTask,
                      onDecline: onDeclineTask,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    message.time,
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF9E9E9E),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _TaskSuggestionCard extends StatelessWidget {
  const _TaskSuggestionCard({
    required this.task,
    required this.isAccepted,
    required this.isDeclined,
    required this.onAccept,
    required this.onDecline,
  });

  final PlannedTask task;
  final bool isAccepted;
  final bool isDeclined;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);

    IconData icon;
    switch (task.category) {
      case AppCategory.study:
        icon = Icons.school_rounded;
        break;
      case AppCategory.sport:
        icon = Icons.fitness_center_rounded;
        break;
      case AppCategory.work:
        icon = Icons.work_rounded;
        break;
      case AppCategory.wellness:
        icon = Icons.spa_rounded;
        break;
      case AppCategory.personal:
        icon = Icons.person_rounded;
        break;
    }

    final dateStr =
        '${task.date.year}-${task.date.month.toString().padLeft(2, '0')}-${task.date.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1420),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAccepted
              ? const Color(0xFF00E676)
              : (isDeclined
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : cyan.withValues(alpha: 0.4)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '📅 $dateStr  •  ⏰ ${formatHm24(task.startMinute)} (${task.durationMinutes} min)',
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF9E9E9E),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          if (isAccepted)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF00E676), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Vazifa jadvalga qo\'shildi',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF00E676),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (isDeclined)
            Text(
              'Bekor qilindi',
              style: AppTextStyles.caption.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Qabul qilish',
                    icon: Icons.check_rounded,
                    onPressed: onAccept,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Bekor qilish',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FormattedAiText extends StatelessWidget {
  const _FormattedAiText({
    required this.text,
    required this.style,
    required this.cyanColor,
  });

  final String text;
  final TextStyle style;
  final Color cyanColor;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        final isBullet = trimmed.startsWith('•') || trimmed.startsWith('-');
        final content = isBullet ? trimmed.substring(1).trim() : trimmed;

        return Padding(
          padding: EdgeInsets.only(bottom: 4, left: isBullet ? 6 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBullet)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cyanColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Expanded(
                child: _RichTextBold(
                  text: content,
                  style: style,
                  cyanColor: cyanColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RichTextBold extends StatelessWidget {
  const _RichTextBold({
    required this.text,
    required this.style,
    required this.cyanColor,
  });

  final String text;
  final TextStyle style;
  final Color cyanColor;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    if (parts.length == 1) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(
        TextSpan(
          text: parts[i],
          style: i.isOdd
              ? style.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cyanColor,
                )
              : style,
        ),
      );
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF151A27),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cyan.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Yozyapti...',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.message});

  final _AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);
    const purple = Color(0xFFAA00FF);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cyan.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                border: Border.all(
                  color: purple.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.time,
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF9E9E9E),
                      fontSize: 10,
                    ),
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

// ── Section 3: Chat Input Component ─────────────────────────────────────────
class _ChatInputField extends StatelessWidget {
  const _ChatInputField({
    required this.controller,
    required this.isThinking,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isThinking;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF151A27),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: cyan.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: !isThinking,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Xabar yozing...',
                  hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isThinking ? null : onSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cyan.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: isThinking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Generated Plan Block ────────────────────────────────────────────────
class _AiGeneratedResult extends StatelessWidget {
  const _AiGeneratedResult({
    required this.state,
    required this.editing,
    required this.onAccept,
    required this.onToggleEdit,
    required this.onRemove,
    required this.onRegenerate,
  });

  final AiPlanState state;
  final bool editing;
  final VoidCallback onAccept;
  final VoidCallback onToggleEdit;
  final ValueChanged<int> onRemove;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    if (state.status == AiPlanStatus.loading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF151A27),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const FlowaLoading(size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                state.progressText ?? 'aiplan.crafting'.tr(),
                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (state.status == AiPlanStatus.ready && state.plan.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151A27),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'aiplan.schedule_title'.tr(),
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < state.plan.length; i++) ...[
              _PlannedTaskRow(
                task: state.plan[i],
                editing: editing,
                onRemove: () => onRemove(i),
              ),
              if (i < state.plan.length - 1)
                const Divider(height: 16, color: Color(0xFF262F45)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'aiplan.accept_all'.tr(),
                    icon: Icons.check_circle_outline_rounded,
                    loading: state.accepting,
                    onPressed: state.accepting ? null : onAccept,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    editing ? Icons.check_rounded : Icons.edit_outlined,
                    color: const Color(0xFF00E5FF),
                  ),
                  onPressed: onToggleEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF9E9E9E)),
                  onPressed: onRegenerate,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _PlannedTaskRow extends StatelessWidget {
  const _PlannedTaskRow({
    required this.task,
    required this.editing,
    required this.onRemove,
  });

  final PlannedTask task;
  final bool editing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            formatHm24(task.startMinute),
            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                '${task.durationMinutes} min • ${task.category.label}',
                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
              ),
            ],
          ),
        ),
        if (editing)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
            onPressed: onRemove,
          ),
      ],
    );
  }
}
