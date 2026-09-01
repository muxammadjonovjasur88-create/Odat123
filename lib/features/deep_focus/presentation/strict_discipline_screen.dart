import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/user_repository.dart';
import '../../blocking/data/blocking_repository.dart';
import '../../blocking/domain/blocking_settings.dart';
import '../../blocking/presentation/blocking_permission_gate.dart';
import '../../reminders/data/reminders_notification_service.dart';
import '../../reminders/data/reminders_repository.dart';
import '../../reminders/presentation/providers/reminders_provider.dart';
import '../data/focus_service.dart';

/// Qat'iy Intizom (Strict Discipline / Hard Lock Mode)
/// Telefon belgilangan vaqt davomida to'liq bloklanadi (kamida 10 daqiqa).
/// Faqat favqulodda qo'ng'iroq uchun ruxsat beriladi va qaytib kirganda qulflanadi.
/// Real vaqt hisobi (timestamp) bo'yicha orqa fonda ham vaqt sanaladi.
class StrictDisciplineScreen extends ConsumerStatefulWidget {
  final String? reminderId;

  const StrictDisciplineScreen({super.key, this.reminderId});

  @override
  ConsumerState<StrictDisciplineScreen> createState() => _StrictDisciplineScreenState();
}

class _StrictDisciplineScreenState extends ConsumerState<StrictDisciplineScreen>
    with WidgetsBindingObserver {
  int _selectedMinutes = 30; // default 30 min
  bool _isLocked = false;
  DateTime? _lockEndTime;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  Timer? _countdownTimer;
  bool _isCallActive = false;

  final Set<String> _selectedPackages = {
    'com.instagram.android',
    'org.telegram.messenger',
    'com.zhiliaoapp.musically',
    'com.google.android.youtube',
  };

  List<Map<String, dynamic>> _installedApps = [];
  bool _isLoadingApps = false;
  String _appSearchQuery = '';

  Future<void> _loadInstalledApps() async {
    setState(() => _isLoadingApps = true);
    try {
      const channel = MethodChannel('flowa/blocking');
      final List<dynamic>? rawApps = await channel.invokeMethod('getInstalledApps');
      if (rawApps != null && rawApps.isNotEmpty) {
        final List<Map<String, dynamic>> parsed = [];
        for (final item in rawApps) {
          if (item is Map) {
            final pkg = item['packageName']?.toString() ?? '';
            final name = item['appName']?.toString() ?? item['name']?.toString() ?? pkg;
            final iconRaw = item['icon'];
            Uint8List? iconBytes;
            if (iconRaw is Uint8List) {
              iconBytes = iconRaw;
            } else if (iconRaw is List) {
              iconBytes = Uint8List.fromList(iconRaw.cast<int>());
            }

            if (pkg.isNotEmpty && !pkg.contains('com.company.flova') && !pkg.contains('com.flowa')) {
              parsed.add({
                'name': name,
                'packageName': pkg,
                'icon': iconBytes,
              });
            }
          }
        }
        if (mounted) {
          final cloudSettings = ref.read(blockingSettingsProvider).asData?.value;
          if (cloudSettings != null && cloudSettings.blockedPackages.isNotEmpty) {
            _selectedPackages.addAll(cloudSettings.blockedPackages);
          }

          setState(() {
            _installedApps = parsed;
            for (final a in parsed) {
              final pkg = a['packageName'] as String;
              if (pkg.contains('instagram') ||
                  pkg.contains('telegram') ||
                  pkg.contains('tiktok') ||
                  pkg.contains('youtube') ||
                  pkg.contains('pubg') ||
                  pkg.contains('brawlstars')) {
                _selectedPackages.add(pkg);
              }
            }
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingApps = false);
    }
  }

  Widget _buildAppCheckbox(String title, String packageKey, String emoji) {
    final isChecked = _selectedPackages.contains(packageKey);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isChecked) {
            _selectedPackages.remove(packageKey);
          } else {
            _selectedPackages.add(packageKey);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Checkbox(
              value: isChecked,
              activeColor: const Color(0xFFFF0055),
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (val == true) {
                    _selectedPackages.add(packageKey);
                  } else {
                    _selectedPackages.remove(packageKey);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInstalledApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isLocked && _lockEndTime != null) {
      if (state == AppLifecycleState.resumed) {
        // Returned from background / lockscreen -> calculate exact remaining seconds
        _syncRemainingTime();
        WakelockPlus.enable();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        setState(() {
          _isCallActive = false;
        });
      } else if (state == AppLifecycleState.paused) {
        _isCallActive = true;
      }
    }
  }

  void _syncRemainingTime() {
    if (_lockEndTime == null) return;
    final now = DateTime.now();
    final diff = _lockEndTime!.difference(now).inSeconds;

    if (diff <= 0) {
      _countdownTimer?.cancel();
      _onLockCompleted();
    } else {
      setState(() {
        _remainingSeconds = diff;
      });
    }
  }

  void _confirmAndStartLock() {
    if (_selectedMinutes < 1) return;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFFFF0055), width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                Icon(Icons.gavel_rounded, color: Color(0xFFFF0055), size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'QAT‘IY INTIZOM SHARTLARI',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRuleItem('🛡️', 'To‘liq bloklash', 'Seans davomida o‘yinlar, ijtimoiy tarmoqlar va ilovalardan foydalanish qat‘iyan to‘xtatiladi.'),
            const SizedBox(height: 10),
            _buildRuleItem('⏳', 'Bekor qilib bo‘lmaydi', '$_selectedMinutes daqiqa tugamaguncha seans to‘xtatilmaydi va bekor qilish tugmasi bo‘lmaydi.'),
            const SizedBox(height: 10),
            _buildRuleItem('📞', 'Favqulodda qo‘ng‘iroq', 'Muhim holatlar uchun faqat telefon qo‘ng‘irog‘i ochiladi, suhbat tugagach yana bloklanadi.'),
            const SizedBox(height: 10),
            _buildRuleItem('💰', '+${_selectedMinutes * 2} PTS mukofot', 'Belgilangan vaqtni muvaffaqiyatli bajarsangiz hisobingizga ball beriladi.'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startLock();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0055),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'ROZIMAN, INTIZOMNI BOSHLASH ⚡',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String emoji, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _startLock() async {
    final hasPerms = await ensureBlockingPermissions(context, ref);
    if (!hasPerms) return;

    HapticFeedback.heavyImpact();

    final total = _selectedMinutes * 60;
    final endTime = DateTime.now().add(Duration(seconds: total));

    setState(() {
      _isLocked = true;
      _totalSeconds = total;
      _lockEndTime = endTime;
      _remainingSeconds = total;
    });

    final packagesToBlock = _selectedPackages.isNotEmpty
        ? _selectedPackages.toList()
        : [
            'com.instagram.android',
            'org.telegram.messenger',
            'org.thunderdog.challegram',
            'com.zhiliaoapp.musically',
            'com.ss.android.ugc.trill',
            'com.facebook.katana',
            'com.twitter.android',
            'com.google.android.youtube',
            'com.dts.freefireth',
            'com.tencent.ig',
            'com.pubg.krmobile',
            'com.activision.callofduty.shooter',
            'com.mobile.legends',
            'com.supercell.brawlstars',
            'com.supercell.clashofclans',
            'com.supercell.clashroyale',
          ];

    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Sync to Cloud Firestore server
    final uid = ref.read(userProfileProvider).asData?.value?.uid;
    if (uid != null) {
      ref.read(blockingRepositoryProvider).save(
        uid,
        BlockingSettings(
          alwaysBlock: true,
          blockedPackages: _selectedPackages,
          strictMode: true,
        ),
      );
    }

    // Schedule native app blocker foreground service & blocking overlay
    try {
      const blockingChannel = MethodChannel('flowa/blocking');
      blockingChannel.invokeMethod('startSession', {
        'packages': packagesToBlock,
        'startAt': DateTime.now().millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'strict': true,
        'lang': 'uz',
      });
    } catch (_) {}

    try {
      FocusService.instance.scheduleSession(
        taskId: 'strict_discipline',
        title: 'Qat‘iy Intizom Seansi',
        startAt: DateTime.now(),
        endAt: endTime,
        packages: packagesToBlock,
        strict: true,
        lang: 'uz',
      );
    } catch (_) {}

    // Schedule local reminder when discipline finishes
    try {
      final notifService = RemindersNotificationService.instance;
      RemindersRepository.instance.add(
        title: 'Qat‘iy Intizom Yakunlandi (+${_selectedMinutes * 2} PTS)!',
        dateTime: endTime,
      ).then((reminder) => notifService.schedule(reminder));
    } catch (_) {}

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _syncRemainingTime();
    });
  }

  Future<void> _onLockCompleted() async {
    try {
      const blockingChannel = MethodChannel('flowa/blocking');
      blockingChannel.invokeMethod('stopSession');
    } catch (_) {}
    try {
      FocusService.instance.stopSession();
    } catch (_) {}
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    HapticFeedback.heavyImpact();

    final earnedPts = _selectedMinutes * 2; // e.g. 30 min = +60 PTS
    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      await ref.read(userRepositoryProvider).awardPoints(user.uid, earnedPts);
    }
    
    if (widget.reminderId != null) {
      try {
        await ref.read(remindersProvider.notifier).markCompleted(widget.reminderId!);
      } catch (_) {}
    }

    setState(() {
      _isLocked = false;
      _lockEndTime = null;
    });

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D1220),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF3B9BFF), width: 1.5),
          ),
          title: const Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 28)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Qat‘iy Intizom Yakunlandi!',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tabriklaymiz! Siz $_selectedMinutes daqiqa davomida telefoningizni to‘liq bloklab, chuqur diqqat va intizomni saqlab qoldingiz.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x3300FF88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3B9BFF)),
                ),
                child: Text(
                  '+$earnedPts PTS MUKOFOT BERILDI ⚡',
                  style: const TextStyle(color: Color(0xFF3B9BFF), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B9BFF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('deep_focus.great_continue'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openDialer() async {
    HapticFeedback.mediumImpact();
    final url = Uri.parse('tel:');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _formatTime(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isLocked) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFFF0055),
              content: Text('deep_focus.strict_mode_warning'.tr()),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080B14),
        body: SafeArea(
          child: _isLocked ? _buildLockedView() : _buildSetupView(),
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => context.pop(),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33FF0055),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF0055)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: Color(0xFFFF0055), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'HARD LOCK MODE',
                      style: TextStyle(color: Color(0xFFFF0055), fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Hero Icon & Title
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0x22FF0055),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF0055), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0055).withValues(alpha: 0.25),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_person_rounded, color: Color(0xFFFF0055), size: 44),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'QAT‘IY INTIZOM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Telefoningizni to‘liq qulflang va diqqatingizni jamlang',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Custom Duration Selector (Slider & Input)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'QULFLASH VAQTI:',
                style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x33FF0055),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF0055)),
                ),
                child: Text(
                  '$_selectedMinutes daqiqa (${(_selectedMinutes / 60).toStringAsFixed(1)} soat)',
                  style: const TextStyle(color: Color(0xFFFF0055), fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slider for custom minutes
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFF0055),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFFFF0055),
              overlayColor: const Color(0x33FF0055),
              trackHeight: 6,
            ),
            child: Slider(
              value: _selectedMinutes.toDouble().clamp(1.0, 1440.0),
              min: 1,
              max: 1440,
              divisions: 288,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _selectedMinutes = v.round().clamp(1, 1440));
              },
            ),
          ),

          // Quick +/- Adjust Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () {
                  if (_selectedMinutes > 1) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (_selectedMinutes <= 5) {
                        _selectedMinutes = (_selectedMinutes - 1).clamp(1, 1440);
                      } else {
                        _selectedMinutes = (_selectedMinutes - 5).clamp(1, 1440);
                      }
                    });
                  }
                },
                icon: const Icon(Icons.remove_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF131929)),
              ),
              const SizedBox(width: 16),
              Text(
                _selectedMinutes >= 60
                    ? '${_selectedMinutes ~/ 60} SOAT ${_selectedMinutes % 60 > 0 ? '${_selectedMinutes % 60} MIN' : ''}'
                    : '$_selectedMinutes MIN',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (_selectedMinutes < 5) {
                      _selectedMinutes = (_selectedMinutes + 1).clamp(1, 1440);
                    } else {
                      _selectedMinutes = (_selectedMinutes + 5).clamp(1, 1440);
                    }
                  });
                },
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF131929)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Prominent 2 PTS/min Reward Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x2200FF88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3B9BFF).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF3B9BFF), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Daqiqasiga 2 PTS: +${_selectedMinutes * 2} PTS olasiz 🏆',
                    style: const TextStyle(
                      color: Color(0xFF3B9BFF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App Selection Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BLOKLANADIGAN ILOVALAR:',
                style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Text(
                '${_selectedPackages.length} ta tanlandi',
                style: const TextStyle(color: Color(0xFFFF0055), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field for Installed Apps
          TextField(
            onChanged: (val) => setState(() => _appSearchQuery = val.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ilovalarni qidirish...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
              filled: true,
              fillColor: const Color(0xFF0D1220),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x22FFFFFF)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: _isLoadingApps
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Color(0xFFFF0055)),
                    ),
                  )
                : _installedApps.isEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAppCheckbox('Instagram', 'com.instagram.android', '📸'),
                          const Divider(color: Colors.white10, height: 1),
                          _buildAppCheckbox('Telegram', 'org.telegram.messenger', '✈️'),
                          const Divider(color: Colors.white10, height: 1),
                          _buildAppCheckbox('TikTok', 'com.zhiliaoapp.musically', '🎵'),
                          const Divider(color: Colors.white10, height: 1),
                          _buildAppCheckbox('YouTube', 'com.google.android.youtube', '▶️'),
                        ],
                      )
                    : Builder(
                        builder: (context) {
                          final filtered = _installedApps.where((a) {
                            final name = (a['name'] as String).toLowerCase();
                            final pkg = (a['packageName'] as String).toLowerCase();
                            return _appSearchQuery.isEmpty ||
                                name.contains(_appSearchQuery) ||
                                pkg.contains(_appSearchQuery);
                          }).toList();

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (context, idx) {
                              final app = filtered[idx];
                              final pkg = app['packageName'] as String;
                              final name = app['name'] as String;
                              final iconBytes = app['icon'] as Uint8List?;
                              final isChecked = _selectedPackages.contains(pkg);

                              return CheckboxListTile(
                                value: isChecked,
                                activeColor: const Color(0xFFFF0055),
                                checkColor: Colors.white,
                                secondary: iconBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          iconBytes,
                                          width: 38,
                                          height: 38,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: const Color(0x22FF0055),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.apps_rounded, color: Color(0xFFFF0055), size: 20),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0x22FF0055),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.apps_rounded, color: Color(0xFFFF0055), size: 20),
                                      ),
                                title: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  isChecked ? '🚫 Bloklanadi' : 'Ruxsat berilgan',
                                  style: TextStyle(
                                    color: isChecked ? const Color(0xFFFF0055) : Colors.white38,
                                    fontSize: 10.5,
                                    fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (val == true) {
                                      _selectedPackages.add(pkg);
                                    } else {
                                      _selectedPackages.remove(pkg);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
          ),
          const SizedBox(height: 24),

          // Warning Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x22FFB703),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x55FFB703)),
            ),
            child: const Row(
              children: [
                Text('⚠️', style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rejim boshlangach uni to‘xtatib bo‘lmaydi. Faqat favqulodda qo‘ng‘iroqqa ruxsat beriladi.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Start Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _confirmAndStartLock,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0055),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Text(
                '$_selectedMinutes DAQIQA INTIZOMNI BOSHLASH (+${_selectedMinutes * 2} PTS) ⚡',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedView() {
    final progress = _totalSeconds > 0 ? (1.0 - (_remainingSeconds / _totalSeconds)).clamp(0.0, 1.0) : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x33FF0055),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF0055)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFFFF0055), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'QAT‘IY INTIZOM FAOL',
                    style: TextStyle(color: Color(0xFFFF0055), fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Circular Progress with Countdown
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: const Color(0xFF131929),
                    color: const Color(0xFFFF0055),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'QOLGAN VAQT',
                      style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 36),

            const Text(
              '«Chalg‘ishni to‘xtat — o‘zing bilan kurashda yutib chiq!»',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Emergency Call Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openDialer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF3B9BFF), size: 18),
                label: Text('deep_focus.emergency_call'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
