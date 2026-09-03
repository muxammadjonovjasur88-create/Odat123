import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_assistant/data/ai_assistant_service.dart';
import '../providers/family_providers.dart';

void showParentAiConsultantDialog(BuildContext context, {required String childName}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ParentAiConsultantSheet(childName: childName),
  );
}

class _ParentAiConsultantSheet extends ConsumerStatefulWidget {
  const _ParentAiConsultantSheet({required this.childName});
  final String childName;

  @override
  ConsumerState<_ParentAiConsultantSheet> createState() => _ParentAiConsultantSheetState();
}

class _ParentAiConsultantSheetState extends ConsumerState<_ParentAiConsultantSheet> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isAnalyzing = false;

  final List<Map<String, String>> _messages = [];

  final List<String> _quickQuestions = [
    'Hozir nima qilyapti va o‘zlashtirishi qanday?',
    'Qaysi sohalarga (kitob, sport, dars) qiziqishi yuqori?',
    'Bugungi intizom va fokus ko‘rsatkichlari qanday?',
    'Farzandimni qanday to‘g‘ri rag‘batlantirsam bo‘ladi?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'ai',
      'text': 'Assalomu alaykum! Men ODAT Parents AI maslahatchisiman. ${widget.childName}ning kundalik odatlari, o‘qishi, sport mashg‘ulotlari va qiziqishlari bo‘yicha istalgan savolingizga tahliliy javob beraman. 🌟',
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _askAi(String query) async {
    if (query.trim().isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _isAnalyzing = true;
      _queryController.clear();
    });

    _scrollToBottom();

    final status = ref.read(childLiveStatusProvider).asData?.value;
    final aiService = ref.read(aiAssistantServiceProvider);

    final aiReply = await aiService.generateParentAiConsultation(
      query: query,
      childName: widget.childName,
      disciplineScore: status?.disciplineScore ?? 50,
      completedTasks: status?.todayTasksCompleted ?? 0,
      totalTasks: status?.todayTasksTotal ?? 0,
      screenTime: status?.todayScreenTimeMinutes ?? 0,
    );

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': aiReply});
      _isAnalyzing = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF04050D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFF3A7FCC), width: 2)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF3A7FCC), Color(0xFF4AADDC)]),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF04050D), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PARENT AI KONSULTANT',
                      style: TextStyle(color: Color(0xFF3A7FCC), fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                    Text(
                      '${widget.childName} bo‘yicha aqlli tahlil va maslahat',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 20),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF0B3A26) : const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(18).copyWith(
                        bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(18),
                        bottomLeft: !isUser ? const Radius.circular(2) : const Radius.circular(18),
                      ),
                      border: Border.all(
                        color: isUser ? const Color(0xFF3A7FCC).withValues(alpha: 0.4) : const Color(0x334AADDC),
                      ),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isAnalyzing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3A7FCC)),
                  ),
                  SizedBox(width: 10),
                  Text('AI tahlil qilmoqda...', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),

          // Quick Suggestion Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickQuestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final q = _quickQuestions[idx];
                return GestureDetector(
                  onTap: () => _askAi(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x3300FF88)),
                    ),
                    child: Text(
                      q,
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Input Bar
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF090B18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x444AADDC)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: const InputDecoration(
                      hintText: 'Farzandingiz bo‘yicha savol bering...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 12.5),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _askAi,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF3A7FCC)),
                  onPressed: () => _askAi(_queryController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
