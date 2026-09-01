import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showSendEnvelopeGiftDialog(BuildContext context, {required String childName}) {
  showDialog(
    context: context,
    builder: (ctx) => _SendEnvelopeGiftDialog(childName: childName),
  );
}

class _SendEnvelopeGiftDialog extends StatefulWidget {
  const _SendEnvelopeGiftDialog({required this.childName});
  final String childName;

  @override
  State<_SendEnvelopeGiftDialog> createState() => _SendEnvelopeGiftDialogState();
}

class _SendEnvelopeGiftDialogState extends State<_SendEnvelopeGiftDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _noteController = TextEditingController(text: 'Bugungi intizoming va a’lo darsing uchun sovg‘a! Ofarin! 🌟');
  int _selectedAmount = 100;
  bool _isSending = false;
  bool _isSent = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  final List<int> _quickAmounts = [50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _sendGift() async {
    HapticFeedback.heavyImpact();
    setState(() => _isSending = true);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _isSent = true;
    });

    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3B9BFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Colors.black),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.childName}ga $_selectedAmount Fenix Coins konvertda muvaffaqiyatli yetkazildi! 💌✨',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
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
    return Dialog(
      backgroundColor: const Color(0xFF0D1220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Envelope Animation
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isSent
                            ? [const Color(0xFF3B9BFF), const Color(0xFF5BC8FA)]
                            : [const Color(0xFFFFB703), const Color(0xFFFF4500)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isSent ? const Color(0xFF3B9BFF) : const Color(0xFFFFB703)).withValues(alpha: 0.35),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isSent ? Icons.done_all_rounded : Icons.mail_rounded,
                      color: Colors.black,
                      size: 38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                _isSent ? 'Konvert Yuborildi! 💌' : 'Farzandga Rag‘bat Yuborish',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _isSent
                    ? '${widget.childName} hisobiga $_selectedAmount Fenix Coins qo‘shildi'
                    : '${widget.childName}ga rag‘batlantirish sifatida konvertda Fenix Coin va xabar yuboring',
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              if (!_isSent) ...[
                // Amount Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _quickAmounts.map((amt) {
                    final isSel = _selectedAmount == amt;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedAmount = amt);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFFB703) : const Color(0xFF141E33),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? const Color(0xFFFFB703) : Colors.white12,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🪙 $amt',
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Note Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141E33),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x335BC8FA)),
                  ),
                  child: TextField(
                    controller: _noteController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Iliq dil izhoringiz yoki tabrik yozing...',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendGift,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB703),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      _isSending ? 'Yuborilmoqda...' : '$_selectedAmount FENIX COIN YUBORISH 💌',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
