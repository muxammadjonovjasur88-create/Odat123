import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/locale_store.dart';

/// Screen displayed after Intro video on fresh install for language selection.
class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  String _selectedCode = 'uz';
  bool _isNavigating = false;

  final List<Map<String, String>> _languages = [
    {
      'code': 'uz',
      'name': 'O‘zbekcha',
      'subname': 'Ona tili (Lotin)',
      'flag': '🇺🇿',
    },
    {
      'code': 'ru',
      'name': 'Русский',
      'subname': 'Русский язык',
      'flag': '🇷🇺',
    },
    {
      'code': 'en',
      'name': 'English',
      'subname': 'International',
      'flag': '🇬🇧',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedCode = LocaleStore.effectiveCode();
  }

  Future<void> _selectAndContinue(String code) async {
    if (_isNavigating) return;
    setState(() {
      _selectedCode = code;
      _isNavigating = true;
    });

    HapticFeedback.mediumImpact();
    await context.setLocale(Locale(code));
    await LocaleStore.save(code);

    if (mounted) {
      context.go(AppRoutes.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D17),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Brand Icon & Badge
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5BC8FA), Color(0xFF7B2FFF)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5BC8FA).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.language_rounded, color: Color(0xFF5BC8FA), size: 36),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Tilni Tanlang / Выберите язык / Select Language',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Dasturdan qulay foydalanish uchun o‘zingizga mos tilni tanlang',
                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // 3 Language Cards
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _languages.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    final code = lang['code']!;
                    final isSelected = _selectedCode == code;

                    return InkWell(
                      onTap: () => _selectAndContinue(code),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF131F38)
                              : const Color(0xFF0F1526),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF5BC8FA)
                                : Colors.white12,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF5BC8FA).withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B243B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF5BC8FA) : Colors.white12,
                                ),
                              ),
                              child: Center(
                                child: Text(lang['flag']!, style: const TextStyle(fontSize: 26)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang['name']!,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lang['subname']!,
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF5BC8FA) : Colors.white38,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFF5BC8FA) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF5BC8FA) : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Continue Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _selectAndContinue(_selectedCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5BC8FA),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 6,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Davom etish / Продолжить / Continue',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
