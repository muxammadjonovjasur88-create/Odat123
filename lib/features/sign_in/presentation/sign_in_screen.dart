import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/locale_store.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

/// Entry sign-in screen for Odat with Google & Telegram auth options.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      final credential =
          await ref.read(authRepositoryProvider).signInWithGoogle();
      if (credential == null && mounted) {
        setState(() => _busy = false);
        return;
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('signin.google_error'.tr());
      }
    }
  }

  void _onTelegramTap() {
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
        child: Stack(
          children: [
            // Top Bar with Language Selector
            Positioned(
              top: 12,
              right: 16,
              child: const _LanguageSelector(),
            ),

            // Center Content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
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
                          padding: const EdgeInsets.all(16),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/flowa_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Odat',
                        style: AppTextStyles.display
                            .copyWith(color: colors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'signin.title'.tr(),
                        style: AppTextStyles.h1
                            .copyWith(color: colors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'signin.subtitle'.tr(),
                        style: AppTextStyles.body
                            .copyWith(color: colors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),

                      // Google button
                      _GoogleButton(
                        label: 'signin.google'.tr(),
                        loading: _busy,
                        onPressed: _busy ? null : _signInWithGoogle,
                      ),
                      const SizedBox(height: 14),

                      // Telegram button
                      _TelegramButton(
                        label: 'signin.telegram'.tr(),
                        onPressed: _busy ? null : _onTelegramTap,
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'signin.privacy'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
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

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final easyLoc = EasyLocalization.of(context);
    final currentLocale = easyLoc?.locale ?? const Locale('uz');
    final currentCode = currentLocale.languageCode;

    return PopupMenuButton<Locale>(
      initialValue: currentLocale,
      tooltip: 'Tilni tanlang',
      onSelected: (locale) async {
        if (easyLoc != null) {
          await context.setLocale(locale);
        }
        await LocaleStore.save(locale.languageCode);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colors.surface,
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              currentCode.toUpperCase(),
              style: AppTextStyles.chip.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 20,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => kSupportedLocales.map((locale) {
        final code = locale.languageCode;
        final name = localeNativeName(code);
        final isSelected = currentCode == code;
        final flag = code == 'uz' ? '🇺🇿' : (code == 'ru' ? '🇷🇺' : '🇬🇧');
        return PopupMenuItem<Locale>(
          value: locale,
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Text(
                name,
                style: AppTextStyles.body.copyWith(
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEnabled = onPressed != null;

    return Material(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: colors.border, width: 1.4),
      ),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _GoogleG(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.label.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w700,
          fontSize: 16,
          height: 1.0,
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
        borderRadius: BorderRadius.circular(30),
      ),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
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
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
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
    final url = Uri.parse('https://t.me/flowwabuddybot?start=login_$token');
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

