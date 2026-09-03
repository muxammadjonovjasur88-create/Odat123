import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/referral_repository.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  String? _myReferralCode;
  bool _isLoading = true;
  final TextEditingController _codeInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
  }

  @override
  void dispose() {
    _codeInputController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralCode() async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      final code = await ref.read(referralRepositoryProvider).getOrCreateReferralCode(user);
      if (mounted) {
        setState(() {
          _myReferralCode = code;
          _isLoading = false;
        });
      }
    }
  }

  void _shareCode() {
    if (_myReferralCode == null) return;
    final shareText = 'Salom! ODAT ilovasida sog‘lom odatlar va mashqlar bilan kunni rejalashtir! Mening referal kodim: $_myReferralCode\nIlovaga qo‘shil va bonus ballarga ega bo‘l!';
    Share.share(shareText);
  }

  void _copyCode() {
    if (_myReferralCode == null) return;
    Clipboard.setData(ClipboardData(text: _myReferralCode!));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF090B18),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF3A7FCC))),
        content: Text('Referal kod nusxalandi: $_myReferralCode'),
      ),
    );
  }

  void _showEnterCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0x444AADDC))),
        title: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFB703)),
            const SizedBox(width: 8),
            Text('referral.enter_friend_code'.tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Do‘stingiz bergan referal kodni kiriting va +50 PTS bonusga ega bo‘ling!',
              style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codeInputController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'ODAT-REF-XXXX',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF090B18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = _codeInputController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);

              final user = ref.read(userProfileProvider).asData?.value;
              if (user == null) return;

              try {
                await ref.read(referralRepositoryProvider).applyReferralCode(
                  currentUid: user.uid,
                  code: code,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF3A7FCC),
                      content: Text('referral.reward_success'.tr()),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('common.error'.tr(args: [e.toString()]))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A7FCC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('common.confirm'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: const FlowaAppBar(showBackButton: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero Referral Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.2,
                    colors: [Color(0xFF1B2845), Color(0xFF090B18)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x66FFB703), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x22FFB703), blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Color(0x22FFB703), shape: BoxShape.circle),
                      child: const Icon(Icons.stars_rounded, color: Color(0xFFFFB703), size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'DO‘STLARNI TAKLIF QILING!',
                      style: TextStyle(color: Color(0xFFFFB703), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Har bir do‘st uchun +100 PTS',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Do‘stlaringiz ODAT ilovasiga sizning kodingiz bilan qo‘shilganda, sizga 100 PTS, do‘stingizga esa 50 PTS bonus beriladi!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // User's Unique Code Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF090B18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x334AADDC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('referral.your_code_label'.tr(), style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _isLoading
                            ? const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4AADDC))
                            : Text(
                                _myReferralCode ?? 'ODAT-REF-100',
                                style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _copyCode,
                              tooltip: 'Nusxalash',
                              icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                            ),
                            IconButton(
                              onPressed: _shareCode,
                              tooltip: 'Ulashish',
                              icon: const Icon(Icons.share_rounded, color: Color(0xFF3A7FCC)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Button to enter friend's code
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _showEnterCodeDialog,
                  icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFB703)),
                  label: Text('referral.enter_code_btn'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x66FFB703), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Big Share Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _shareCode,
                  icon: const Icon(Icons.share_rounded, color: Colors.black),
                  label: Text('referral.share_friends'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7FCC),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
