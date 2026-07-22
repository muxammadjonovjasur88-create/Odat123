import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/otp_input.dart';
import '../../../core/widgets/widgets.dart';
import '../../sign_in/presentation/phone_auth_controller.dart';

/// Screen 04 — 6-digit OTP entry with a resend countdown. "Verify" completes
/// Firebase sign-in; the auth gate then routes onward (setup profile / home).
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  static const _resendSeconds = 60;

  String _code = '';
  int _secondsLeft = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      _snack('verify.error_incomplete'.tr());
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(phoneAuthControllerProvider.notifier).verifyCode(_code);
    // Success → auth gate redirects. Errors handled via ref.listen below.
  }

  void _resend() {
    final phone = ref.read(phoneAuthControllerProvider).phoneNumber;
    if (phone == null) return;
    ref
        .read(phoneAuthControllerProvider.notifier)
        .sendCode(phone, resend: true);
    _startCountdown();
    _snack('verify.resent'.tr());
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    ref.listen<PhoneAuthState>(phoneAuthControllerProvider, (prev, next) {
      if (next.status == PhoneAuthStatus.error && next.errorMessage != null) {
        _snack(next.errorMessage!);
      }
    });

    final state = ref.watch(phoneAuthControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Calm "stones" hero medallion.
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE7DECF), Color(0xFFCBBBA3)],
                  ),
                  border: Border.all(color: colors.surface, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.spa_outlined,
                  size: 48,
                  color: AppColors.forest.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'verify.title'.tr(),
                style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'verify.subtitle'.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 36),
              OtpInput(
                enabled: !state.isBusy,
                onChanged: (v) => setState(() => _code = v),
                onCompleted: (_) => _verify(),
              ),
              const SizedBox(height: 28),
              _ResendRow(
                secondsLeft: _secondsLeft,
                colors: colors,
                onResend: _resend,
              ),
              const SizedBox(height: 28),
              AppButton(
                label: 'verify.verify'.tr(),
                loading: state.isBusy,
                onPressed: state.isBusy ? null : _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.colors,
    required this.onResend,
  });

  final int secondsLeft;
  final AppColorScheme colors;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    if (secondsLeft > 0) {
      final m = (secondsLeft ~/ 60).toString();
      final s = (secondsLeft % 60).toString().padLeft(2, '0');
      return Text(
        'verify.resend_in'.tr(namedArgs: {'time': '$m:$s'}),
        style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
      );
    }
    return GestureDetector(
      onTap: onResend,
      child: Text(
        'verify.resend'.tr(),
        style: AppTextStyles.label.copyWith(color: colors.primary),
      ),
    );
  }
}
