import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/beta_ticker_banner.dart';

/// Entry sign-in screen for Odat with Telegram auth.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _agreedToPrivacy = true;

  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF5BC8FA), width: 2)),
        ),
        child: Column(
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
                Icon(Icons.security_rounded, color: Color(0xFF5BC8FA), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'MAXFIYLIK VA XAVFSIZLIK RUXSATNOMASI',
                    style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPrivacySection(
                      '1. Nima uchun hisob kerak?',
                      'Odat ilovasida rivojlanish statistikangiz, ballaringiz va do‘stlar bilan musobaqalaringiz xavfsiz saqlanishi uchun Google yoki Telegram orqali kirish kifoya.',
                    ),
                    _buildPrivacySection(
                      '2. Ilovalarni bloklash xavfsizligi',
                      'Fokus rejimida chalg‘ituvchi ilovalarni to‘xtatish uchun so‘raladigan maxsus ruxsatlar (Accessibility / Usage Access) faqat qurilmangizning o‘zida ishlaydi. Hech qanday shaxsiy yozishmalar yoki parollar o‘qilmaydi va serverga yuborilmaydi.',
                    ),
                    _buildPrivacySection(
                      '3. Ma’lumotlar daxlsizligi',
                      'Biz foydalanuvchilarning shaxsiy ma’lumotlarini aslo uchinchi shaxslarga sotmaymiz va reklama tarmoqlariga bermaymiz.',
                    ),
                    _buildPrivacySection(
                      '4. To‘liq Maxfiylik Siyosati',
                      'Barcha qonuniy shartlar bilan to‘liq tanishish uchun quyidagi rasmiy havolani ochishingiz mumkin:',
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => launchUrl(
                        Uri.parse('https://flowa-4fca9.web.app/privacy.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '🔗 https://flowa-4fca9.web.app/privacy.html',
                          style: TextStyle(
                            color: Color(0xFF5BC8FA),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5BC8FA),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _agreedToPrivacy = true);
                },
                child: const Text('ROZIMAN VA TUSHUNDIM', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  void _onTelegramTap() {
    if (!_agreedToPrivacy) {
      _snack('Davom etish uchun maxfiylik siyosatiga rozilik bildiring');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _TelegramWaitingBottomSheet(),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BetaTickerBanner(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surface,
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow,
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icon/flowa_icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Odat',
                              style: AppTextStyles.display
                                  .copyWith(color: colors.primary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9100).withValues(alpha: 0.2),
                                border: Border.all(color: const Color(0xFFFF9100), width: 1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BETA',
                                style: TextStyle(
                                  color: Color(0xFFFFB300),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'signin.title'.tr(),
                          style: AppTextStyles.h1
                              .copyWith(color: colors.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'signin.subtitle'.tr(),
                          style: AppTextStyles.body
                              .copyWith(color: colors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                  // Privacy Consent Checkbox
                  GestureDetector(
                    onTap: () => setState(() => _agreedToPrivacy = !_agreedToPrivacy),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _agreedToPrivacy,
                          activeColor: const Color(0xFF5BC8FA),
                          checkColor: Colors.black,
                          onChanged: (val) => setState(() => _agreedToPrivacy = val ?? false),
                        ),
                        Flexible(
                          child: GestureDetector(
                            onTap: _showPrivacyPolicyModal,
                            child: Text(
                              'signin.agree_and_accept'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF5BC8FA),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Telegram button
                  _TelegramButton(
                    label: 'signin.telegram'.tr(),
                    onPressed: _onTelegramTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),
);
  }
}

class _TelegramButton extends StatelessWidget {
  const _TelegramButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Material(
      color: const Color(0xFF26A5E4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3326A5E4),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelegramWaitingBottomSheet extends ConsumerStatefulWidget {
  const _TelegramWaitingBottomSheet();

  @override
  ConsumerState<_TelegramWaitingBottomSheet> createState() =>
      __TelegramWaitingBottomSheetState();
}

class __TelegramWaitingBottomSheetState
    extends ConsumerState<_TelegramWaitingBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String? _token;
  bool _initializing = true;
  bool _isTimeout = false;
  bool _isSigningIn = false;
  String? _errorMessage;
  int _remainingSeconds = 300; // 5 minutes

  Timer? _countdownTimer;
  StreamSubscription? _streamSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startFlow();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _startFlow() async {
    setState(() {
      _initializing = true;
      _isTimeout = false;
      _isSigningIn = false;
      _errorMessage = null;
      _remainingSeconds = 300;
    });

    _countdownTimer?.cancel();
    _streamSub?.cancel();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final token = await authRepo.createTelegramLoginRequest();
      if (!mounted) return;

      setState(() {
        _token = token;
        _initializing = false;
      });

      await _openTelegramLink(token);
      _startTimer();

      _streamSub = authRepo.listenToLoginRequest(token).listen(
        (snapshot) async {
          if (!mounted || _isSigningIn) return;
          final data = snapshot.data();
          if (data == null) return;

          final status = data['status'] as String?;
          if (status == 'approved') {
            final customToken = data['customToken'] as String?;
            if (customToken != null && customToken.isNotEmpty) {
              await _handleAutoSignIn(customToken);
            }
          } else if (status == 'expired') {
            _onTimeout();
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Tasdiqlash holatini olishda xatolik: $err';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _openTelegramLink(String token) async {
    final url = Uri.parse('https://t.me/odat_fenix_bot?start=login_$token');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignored if launcher fails — manual button provided in UI
    }
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    _countdownTimer?.cancel();
    _streamSub?.cancel();
    if (mounted) {
      setState(() {
        _isTimeout = true;
        _remainingSeconds = 0;
      });
    }
  }

  Future<void> _handleAutoSignIn(String customToken) async {
    setState(() => _isSigningIn = true);
    _countdownTimer?.cancel();
    _streamSub?.cancel();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithCustomToken(customToken, loginToken: _token);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _formatDuration(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top bar with drag handle & close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                onPressed: () {
                  _countdownTimer?.cancel();
                  _streamSub?.cancel();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_initializing) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF26A5E4)),
            ),
            const SizedBox(height: 24),
            Text(
              'Telegram tayyorlanmoqda...',
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 32),
          ] else if (_isTimeout) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_off_rounded,
                color: Colors.orangeAccent,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Vaqt tugadi, qayta urinib ko\'ring',
              style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '5 daqiqa ichida Telegram botda kirish tasdiqlanmadi. Yangi so\'rov yuboring.',
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startFlow,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Qayta urinib ko\'rish',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26A5E4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _countdownTimer?.cancel();
                _streamSub?.cancel();
                Navigator.of(context).pop();
              },
              child: Text(
                'Bekor qilish',
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
            ),
          ] else if (_isSigningIn) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF26A5E4)),
            ),
            const SizedBox(height: 24),
            Text(
              'Tizimga kirilmoqda...',
              style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 32),
          ] else ...[
            // Pulse Animated Telegram Logo
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF26A5E4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF26A5E4).withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Telegram\'da tasdiqlang...',
              style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Botda \'Kirish\' tugmasini bosing',
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Countdown timer badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Vaqt: ${_formatDuration(_remainingSeconds)}',
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: AppTextStyles.caption.copyWith(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            // Re-open Telegram link button if app didn't open
            if (_token != null)
              OutlinedButton.icon(
                onPressed: () => _openTelegramLink(_token!),
                icon: const Icon(
                  Icons.telegram_rounded,
                  color: Color(0xFF26A5E4),
                ),
                label: const Text('Telegram\'ni qayta ochish'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF26A5E4),
                  side: const BorderSide(color: Color(0xFF26A5E4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Bekor qilish button
            TextButton(
              onPressed: () {
                _countdownTimer?.cancel();
                _streamSub?.cancel();
                Navigator.of(context).pop();
              },
              child: Text(
                'Bekor qilish',
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

