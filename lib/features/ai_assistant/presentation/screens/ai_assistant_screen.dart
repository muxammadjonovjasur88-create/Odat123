import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/constants/app_category.dart';
import '../../../../core/models/task.dart';
import '../../../../core/router/nav_helpers.dart';
import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/task_repository.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../domain/models/ai_chat_message.dart';
import '../../data/ai_assistant_service.dart';
import '../../../reminders/data/reminders_repository.dart';
import '../../../reminders/data/reminders_notification_service.dart';
import '../../../reminders/domain/models/reminder.dart';
import '../../../reminders/presentation/providers/reminders_provider.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isProcessing = false;
  bool _isLoadingHistory = true;
  File? _selectedImage;

  late AnimationController _pulseController;
  final List<AiChatMessage> _messages = [];

  static const int _kMaxFreeDailyPhotos = 2;
  static const int _kMaxFreeDailyVoices = 3;

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  Future<int> _getPhotoCountToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ai_photo_count_${_getTodayKey()}') ?? 0;
  }

  Future<void> _incrementPhotoCountToday() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('ai_photo_count_${_getTodayKey()}') ?? 0;
    await prefs.setInt('ai_photo_count_${_getTodayKey()}', current + 1);
  }

  Future<int> _getVoiceCountToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ai_voice_count_${_getTodayKey()}') ?? 0;
  }

  Future<void> _incrementVoiceCountToday() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('ai_voice_count_${_getTodayKey()}') ?? 0;
    await prefs.setInt('ai_voice_count_${_getTodayKey()}', current + 1);
  }

  void _showProSubscriptionModal(BuildContext context) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF090B18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFFFFB703), width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFB703), Color(0xFFFF4500)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x66FFB703), blurRadius: 16)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'ODAT PRO OBUNASI',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Cheklovlarsiz Rivojlaning! 🚀',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Kunlik bepul limit tugadi. PRO obunani faollashtiring va barcha imkoniyatlardan cheksiz foydalaning!',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF161F36), Color(0xFF0F1728)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x44FFB703)),
              ),
              child: Column(
                children: [
                  _buildProFeatureRow('🎵', 'Bepul musiqa, kitoblar va audiokitoblar'),
                  const SizedBox(height: 12),
                  _buildProFeatureRow('🎙️', 'Cheksiz ovozli chat va AI bilan suhbat'),
                  const SizedBox(height: 12),
                  _buildProFeatureRow('🖼️', 'Cheksiz rasm tahlili va yuklash'),
                  const SizedBox(height: 12),
                  _buildProFeatureRow('🎁', 'Har kuni +20 ta Fenix Coin va +1000 PTS bonus'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/paywall');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: Colors.black,
                  elevation: 10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 22),
                label: const Text(
                  'PRO OBUNAGA O‘TISH ✨',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProFeatureRow(String icon, String text) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        const Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 18),
      ],
    );
  }

  Future<void> _pickImage() async {
    final profile = ref.read(userProfileProvider).asData?.value;
    final isPremium = profile?.isPremium ?? false;
    if (!isPremium) {
      final photoCount = await _getPhotoCountToday();
      if (photoCount >= _kMaxFreeDailyPhotos) {
        if (mounted) _showProSubscriptionModal(context);
        return;
      }
    }

    if (!mounted) return;
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF090B18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ai.upload_image'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF4AADDC)),
                title: Text('ai.camera_source'.tr(), style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF3A7FCC)),
                title: Text('ai.gallery_source'.tr(), style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid != null) {
      final aiService = ref.read(aiAssistantServiceProvider);
      final history = await aiService.loadWeeklyMessages(uid);
      if (mounted) {
        setState(() {
          _messages.clear();
          if (history.isEmpty) {
            _messages.add(
              AiChatMessage(
                id: 'init_msg',
                text: 'ai_assistant.welcome'.tr(),
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          } else {
            _messages.addAll(history);
          }
          _isLoadingHistory = false;
        });
        _scrollToBottom();
        return;
      }
    }

    if (mounted) {
      setState(() {
        if (_messages.isEmpty) {
          _messages.add(
            AiChatMessage(
              id: 'init_msg',
              text: 'ai_assistant.welcome'.tr(),
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        }
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (val) => debugPrint('⚠️ Speech error: $val'),
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
            }
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('SpeechToText init error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    final profile = ref.read(userProfileProvider).asData?.value;
    final isPremium = profile?.isPremium ?? false;
    if (!isPremium) {
      final voiceCount = await _getVoiceCountToday();
      if (voiceCount >= _kMaxFreeDailyVoices) {
        if (mounted) _showProSubscriptionModal(context);
        return;
      }
    }

    if (!_speechEnabled) {
      final available = await _speech.initialize();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ai_assistant.mic_permission_denied'.tr())),
          );
        }
        return;
      }
    }

    HapticFeedback.heavyImpact();
    setState(() => _isListening = true);

    String localeId = 'uz_UZ';
    if (mounted) {
      final lang = context.locale.languageCode;
      if (lang == 'ru') {
        localeId = 'ru_RU';
      } else if (lang == 'en') {
        localeId = 'en_US';
      }
    }

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
        localeId: localeId,
      ),
      onResult: (result) {
        _textController.text = result.recognizedWords;
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _stopListeningAndSend(result.recognizedWords, isVoice: true);
        }
      },
    );
  }

  Future<void> _stopListeningAndSend(String text, {bool isVoice = false}) async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (text.trim().isNotEmpty) {
      _sendMessage(text.trim(), isVoice: isVoice);
    }
  }

  Future<void> _sendMessage(String text, {bool isVoice = false}) async {
    if (text.trim().isEmpty) return;

    String? base64Img;
    if (_selectedImage != null) {
      try {
        final bytes = await _selectedImage!.readAsBytes();
        base64Img = base64Encode(bytes);
        _incrementPhotoCountToday();
      } catch (e) {
        debugPrint('⚠️ Error encoding image: $e');
      }
    }

    if (isVoice) {
      _incrementVoiceCountToday();
    }

    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      isVoice: isVoice,
      imageBase64: base64Img,
    );

    setState(() {
      _messages.add(userMsg);
      _isProcessing = true;
      _textController.clear();
      _selectedImage = null;
    });
    _scrollToBottom();

    final uid = ref.read(authStateProvider).asData?.value?.uid;
    final profile = ref.read(userProfileProvider).asData?.value;

    if (uid != null) {
      ref.read(aiAssistantServiceProvider).saveMessageToFirestore(uid, userMsg);
    }

    final today = DateUtils.dateOnly(DateTime.now());
    List<Task> todayTasks = [];
    if (uid != null) {
      final stream = ref.read(taskRepositoryProvider).watchTasksForDay(uid, today);
      todayTasks = (await stream.first);
    }

    final aiService = ref.read(aiAssistantServiceProvider);
    final langCode = mounted ? context.locale.languageCode : 'uz';
    final response = await aiService.processMessage(
      userText: text,
      todayTasks: todayTasks,
      profile: profile,
      isVoice: isVoice,
      languageCode: langCode,
      previousMessages: _messages,
      userImageBase64: base64Img,
    );

    if (uid != null) {
      aiService.saveMessageToFirestore(uid, response);
    }

    if (mounted) {
      setState(() {
        _messages.add(response);
        _isProcessing = false;
      });
      _scrollToBottom();
      HapticFeedback.lightImpact();

      // Automatically sync all suggested tasks / reminders to Calendar & Active Goals
      if (response.suggestedTasks.isNotEmpty) {
        _addAllTasksToDailyPlan(response.suggestedTasks);
      }
    }
  }

  Future<void> _addTaskToDailyPlan(AiSuggestedTask suggested, {bool showToast = true}) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    final parts = suggested.timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final min = (parts.length > 1 ? int.tryParse(parts[1]) : 0) ?? 0;
    final startMinute = hour * 60 + min;

    DateTime targetDate = DateUtils.dateOnly(DateTime.now());
    if (suggested.dateStr != null && suggested.dateStr!.isNotEmpty) {
      final parsed = DateTime.tryParse(suggested.dateStr!);
      if (parsed != null) targetDate = DateUtils.dateOnly(parsed);
    } else {
      // If it's a recurring daily/general task and the time has already passed today,
      // schedule the first occurrence for tomorrow to prevent it from being immediately overdue.
      final now = DateTime.now();
      if (startMinute <= now.hour * 60 + now.minute) {
        targetDate = targetDate.add(const Duration(days: 1));
      }
    }

    // 1. Add to Tasks
    try {
      final task = Task(
        id: '',
        title: suggested.title,
        category: suggested.goalType == 'exercise' ? AppCategory.sport : AppCategory.study,
        date: targetDate,
        startMinute: startMinute,
        durationMinutes: suggested.durationMinutes,
        points: 20,
      );
      await ref.read(taskRepositoryProvider).addTask(uid, task);
    } catch (e) {
      debugPrint('⚠️ Error adding task: $e');
    }

    // 2. Schedule Reminders and add to Faol Maqsadlar / Eslatmalar
    final now = DateTime.now();
    var scheduledDate = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, min);
    if (suggested.dateStr == null && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final repeatEnum = (suggested.isDaily || suggested.isEvery2Days || suggested.isEvery3Days)
        ? RepeatType.daily
        : (suggested.isWeekly ? RepeatType.weekly : RepeatType.once);

    final goalTypeStr = suggested.goalType; // 'focus', 'exercise', 'note'

    try {
      await ref.read(remindersProvider.notifier).add(
        title: suggested.title,
        dateTime: scheduledDate,
        repeatType: repeatEnum,
        goalType: goalTypeStr,
        durationMinutes: suggested.durationMinutes,
      );
    } catch (e) {
      debugPrint('⚠️ Error scheduling notification via provider: $e');
      try {
        final reminder = await RemindersRepository.instance.add(
          title: suggested.title,
          dateTime: scheduledDate,
          repeatType: repeatEnum,
          goalType: goalTypeStr,
          durationMinutes: suggested.durationMinutes,
        );
        await RemindersNotificationService.instance.schedule(reminder);
      } catch (err) {
        debugPrint('⚠️ Error in fallback reminder add: $err');
      }
    }

    if (showToast && mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3A7FCC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '«${suggested.title}» (${suggested.timeStr}) eslatmalarga qo‘shildi! ⏰',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _addAllTasksToDailyPlan(List<AiSuggestedTask> tasks) async {
    if (tasks.isEmpty) return;
    HapticFeedback.heavyImpact();

    for (final task in tasks) {
      await _addTaskToDailyPlan(task, showToast: false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3A7FCC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.alarm_on_rounded, color: Colors.black, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Barcha ${tasks.length} ta eslatma jadvalga muvaffaqiyatli saqlandi! 🚀⏰',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    void handleBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/daily');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF04050D),
        bottomNavigationBar: AppBottomNav(
          current: AppNavTab.ai,
          onSelected: (tab) => goToTab(context, tab),
        ),
        appBar: AppBar(
          backgroundColor: const Color(0xFF090B18),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
            onPressed: handleBack,
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ai_assistant.title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'ai_assistant.subtitle'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF4AADDC),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Chat Messages List
              Expanded(
                child: _isLoadingHistory
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4AADDC)),
                      )
                    : RepaintBoundary(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return _buildMessageItem(msg);
                          },
                        ),
                      ),
              ),

              if (_isProcessing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4AADDC)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ai_assistant.thinking'.tr(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 4),

              if (_selectedImage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF090B18),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF4AADDC), width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Rasm yuklandi. Masalangizni yozib yuboring va AI masalani tushuntirib, siz bilan test savol-javob qiladi! 📚✨',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

              // Input Bar
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF090B18),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x444AADDC), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4AADDC).withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF4AADDC), size: 24),
                      onPressed: _pickImage,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: _isListening ? 'ai_assistant.voice_listening'.tr() : 'ai_assistant.input_hint'.tr(),
                          hintStyle: TextStyle(
                            color: _isListening ? const Color(0xFF3A7FCC) : Colors.white38,
                            fontSize: 13,
                            fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onSubmitted: (val) => _sendMessage(val),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Telegram-style Hold-To-Talk Microphone Button
                    GestureDetector(
                      onTapDown: (_) {
                        HapticFeedback.heavyImpact();
                        _startListening();
                      },
                      onTapUp: (_) {
                        HapticFeedback.mediumImpact();
                        _stopListeningAndSend(_textController.text, isVoice: true);
                      },
                      onTapCancel: () {
                        _speech.stop();
                        if (mounted) setState(() => _isListening = false);
                      },
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = _isListening ? 1.0 + (_pulseController.value * 0.18) : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isListening
                                      ? [const Color(0xFF3A7FCC), const Color(0xFF3A7FCC)]
                                      : [const Color(0xFF0088CC), const Color(0xFF4AADDC)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _isListening
                                        ? const Color(0xFF3A7FCC).withValues(alpha: 0.5)
                                        : const Color(0xFF0088CC).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none_rounded,
                                color: _isListening ? Colors.black : Colors.white,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Send Button
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF3A7FCC), size: 24),
                      onPressed: () => _sendMessage(_textController.text),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
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

  Widget _buildMessageItem(AiChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF0055FF) : const Color(0xFF090B18),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(2) : const Radius.circular(18),
            bottomLeft: !msg.isUser ? const Radius.circular(2) : const Radius.circular(18),
          ),
          border: Border.all(
            color: msg.isUser ? const Color(0x334AADDC) : const Color(0x22FFFFFF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isVoice)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, size: 14, color: msg.isUser ? Colors.white70 : const Color(0xFF4AADDC)),
                    const SizedBox(width: 4),
                    Text(
                      'ai_assistant.voice_badge'.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: msg.isUser ? Colors.white70 : const Color(0xFF4AADDC),
                      ),
                    ),
                  ],
                ),
              ),
            if (msg.imageBase64 != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(msg.imageBase64!),
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
            ),

            // Render Suggested Tasks / Schedule inside the message
            if (msg.suggestedTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E17),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4AADDC), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📅', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              'KUNLIK JADVAL (${msg.suggestedTasks.length} ta)',
                              style: const TextStyle(
                                color: Color(0xFF4AADDC),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x33FFB703),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '⏰ 1h & 10m oldin',
                            style: TextStyle(color: Color(0xFFFFB703), fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    for (final task in msg.suggestedTasks)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090B18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x22FFFFFF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x334AADDC),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.timeStr,
                                style: const TextStyle(
                                  color: Color(0xFF4AADDC),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: task.goalType == 'exercise'
                                    ? const Color(0x3300FF88)
                                    : (task.goalType == 'note' ? const Color(0x33FFB703) : const Color(0x337B2FFF)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                task.goalTypeBadge,
                                style: TextStyle(
                                  color: task.goalType == 'exercise'
                                      ? const Color(0xFF3A7FCC)
                                      : (task.goalType == 'note' ? const Color(0xFFFFB703) : const Color(0xFF6B25CC)),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (task.repeatType != 'once') ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0x22FFFFFF),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  task.repeatTypeBadge,
                                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF3A7FCC), size: 22),
                              onPressed: () => _addTaskToDailyPlan(task),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () => _addAllTasksToDailyPlan(msg.suggestedTasks),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4AADDC),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.alarm_add_rounded, size: 18),
                        label: const Text(
                          'BARCHASINI ESLATMALARGA QO‘SHISH 🚀',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
