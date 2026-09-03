import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../../data/digital_wellbeing_service.dart';

class DigitalDetoxScreen extends ConsumerStatefulWidget {
  const DigitalDetoxScreen({super.key});

  @override
  ConsumerState<DigitalDetoxScreen> createState() => _DigitalDetoxScreenState();
}

class _DigitalDetoxScreenState extends ConsumerState<DigitalDetoxScreen> {
  int _selectedDurationMin = 30;
  bool _isDetoxActive = false;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startDetox() async {
    final lang = context.locale.languageCode;
    HapticFeedback.heavyImpact();
    final service = ref.read(digitalWellbeingServiceProvider);

    final apps = await service.getInstalledApps();
    final distracting = apps
        .where((a) =>
            a.packageName.contains('instagram') ||
            a.packageName.contains('telegram') ||
            a.packageName.contains('tiktok') ||
            a.packageName.contains('youtube') ||
            a.packageName.contains('game'))
        .map((a) => a.packageName)
        .toList();

    final started = await service.startDigitalDetox(
      durationMinutes: _selectedDurationMin,
      packageList: distracting,
      strict: true,
      lang: lang,
    );

    if (started) {
      setState(() {
        _isDetoxActive = true;
        _remainingSeconds = _selectedDurationMin * 60;
      });

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds <= 1) {
          timer.cancel();
          setState(() => _isDetoxActive = false);
        } else {
          setState(() => _remainingSeconds--);
        }
      });
    }
  }

  void _cancelDetox() {
    _countdownTimer?.cancel();
    setState(() => _isDetoxActive = false);
  }

  String _formatRemainingTime() {
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    if (h > 0) {
      final hStr = h.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'wellbeing.detox_title'.tr(),
          style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _isDetoxActive ? _buildActiveDetoxHUD() : _buildSetupView(),
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing Icon
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4AADDC).withValues(alpha: 0.15),
            border: Border.all(color: const Color(0xFF4AADDC), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x444AADDC), blurRadius: 24, spreadRadius: 4),
            ],
          ),
          child: const Center(
            child: Icon(Icons.do_not_disturb_on_rounded, color: Color(0xFF4AADDC), size: 44),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'wellbeing.detox_heading'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'wellbeing.detox_desc'.tr(),
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Duration Presets
        Text(
          'wellbeing.select_duration'.tr(),
          style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [30, 60, 120, 240].map((mins) {
            final isSel = _selectedDurationMin == mins;
            final label = mins >= 60 ? '${mins ~/ 60} soat' : '$mins daqiqa';
            return ChoiceChip(
              selected: isSel,
              onSelected: (_) => setState(() => _selectedDurationMin = mins),
              label: Text(label),
              selectedColor: const Color(0xFF4AADDC),
              backgroundColor: const Color(0xFF090B18),
              labelStyle: TextStyle(
                color: isSel ? const Color(0xFF04050D) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            );
          }).toList(),
        ),
        const SizedBox(height: 40),

        // Start Detox Button
        BouncyScale(
          onTap: _startDetox,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x444AADDC), blurRadius: 18, offset: Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                'wellbeing.start_detox_btn'.tr(),
                style: const TextStyle(
                  color: Color(0xFF04050D),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDetoxHUD() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Live Circular Countdown HUD
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0x115BC8FA), Color(0xFF090B18)]),
            border: Border.all(color: const Color(0xFF4AADDC), width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x334AADDC), blurRadius: 30, spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF3A7FCC), size: 28),
              const SizedBox(height: 8),
              Text(
                _formatRemainingTime(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'wellbeing.detox_active_label'.tr(),
                style: const TextStyle(
                  color: Color(0xFF4AADDC),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        Text(
          'wellbeing.detox_motivate'.tr(),
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Emergency Override Button (Hold to cancel)
        OutlinedButton.icon(
          onPressed: _showEmergencyOverrideDialog,
          icon: const Icon(Icons.lock_open_rounded, color: Color(0xFFFF5252), size: 18),
          label: Text(
            'wellbeing.emergency_override'.tr(),
            style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0x66FF5252)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  void _showEmergencyOverrideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('wellbeing.override_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'wellbeing.override_desc'.tr(),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelDetox();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            child: Text('wellbeing.stop_btn'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
