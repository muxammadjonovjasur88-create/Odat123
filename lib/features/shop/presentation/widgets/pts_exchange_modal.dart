import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/user_repository.dart';

/// Opens the Fenix Coins to PTS exchange modal (Rate: 1 Fenix Coin = 10 PTS).
Future<void> showPtsExchangeModal(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _PtsExchangeModalContent(),
  );
}

class _PtsExchangeModalContent extends ConsumerStatefulWidget {
  const _PtsExchangeModalContent();

  @override
  ConsumerState<_PtsExchangeModalContent> createState() =>
      _PtsExchangeModalContentState();
}

class _PtsExchangeModalContentState
    extends ConsumerState<_PtsExchangeModalContent> {
  int _selectedCoins = 10;
  bool _isProcessing = false;
  final TextEditingController _customController =
      TextEditingController(text: '10');

  final List<int> _presetPackages = [10, 50, 100, 500];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _onSelectPreset(int coins) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCoins = coins;
      _customController.text = coins.toString();
    });
  }

  Future<void> _handleExchange(int userCoins, String uid) async {
    if (_selectedCoins < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('shop.min_exchange_limit'.tr()),
        ),
      );
      return;
    }

    if (userCoins < _selectedCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF0055),
          content: Text('shop.insufficient_fenix_coins'.tr()),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      final success = await ref
          .read(userRepositoryProvider)
          .exchangeCoinsToPts(uid, _selectedCoins);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        final ptsReceived = _selectedCoins * 10;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A7FCC),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  '🎉 $_selectedCoins Fenix Coin $ptsReceived PTS ga almashtirildi!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('shop.exchange_error'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final totalPts = user?.totalPoints ?? 0;
    final fenixCoins = user?.fenixCoins ?? 0;
    final ptsToReceive = _selectedCoins * 10;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF4AADDC), width: 1.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Rate Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFB703),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.currency_exchange_rounded,
                        color: Color(0xFFFFB703),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Fenix Coin ➡️ PTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x224AADDC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xAA4AADDC)),
                  ),
                  child: const Text(
                    '1 Coin = 10 PTS',
                    style: TextStyle(
                      color: Color(0xFF4AADDC),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Balances Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF090B18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Mavjud Fenix Coin',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              color: Color(0xFFFFB703), size: 16),
                          Text(
                            '$fenixCoins Coin',
                            style: const TextStyle(
                              color: Color(0xFFFFB703),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Column(
                    children: [
                      const Text(
                        'Mavjud PTS',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: Color(0xFF4AADDC), size: 16),
                          Text(
                            '$totalPts PTS',
                            style: const TextStyle(
                              color: Color(0xFF4AADDC),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Presets
            const Text(
              'Paketni tanlang yoki Coin miqdorini kiriting:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: _presetPackages.map((coins) {
                final isSelected = _selectedCoins == coins;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onSelectPreset(coins),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFB703)
                            : const Color(0xFF090B18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFB703)
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$coins Coin',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '+${coins * 10} PTS',
                            style: TextStyle(
                              color: isSelected ? Colors.black87 : const Color(0xFF4AADDC),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom Coin Input
            TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF090B18),
                labelText: 'Fenix Coin miqdorini kiriting',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                suffixText: '= $ptsToReceive PTS',
                suffixStyle: const TextStyle(
                  color: Color(0xFF4AADDC),
                  fontWeight: FontWeight.bold,
                ),
                prefixIcon: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB703)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFFFB703)),
                ),
              ),
              onChanged: (val) {
                final parsed = int.tryParse(val) ?? 0;
                setState(() => _selectedCoins = parsed);
              },
            ),
            const SizedBox(height: 24),

            // Confirm Exchange Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing || user == null
                    ? null
                    : () => _handleExchange(fenixCoins, user.uid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB703),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  shadowColor: const Color(0x66FFB703),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.swap_horiz_rounded,
                              color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$_selectedCoins Coin ni $ptsToReceive PTS ga almashtirish',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
