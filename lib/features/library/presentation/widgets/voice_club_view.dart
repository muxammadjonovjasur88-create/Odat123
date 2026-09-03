import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_club_provider.dart';
import '../../../../core/widgets/avatar_circle.dart';

class VoiceClubView extends ConsumerStatefulWidget {
  final VoidCallback? onLeave;

  const VoiceClubView({super.key, this.onLeave});

  @override
  ConsumerState<VoiceClubView> createState() => _VoiceClubViewState();
}

class _VoiceClubViewState extends ConsumerState<VoiceClubView> {
  bool _hasRaisedHand = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(voiceClubProvider.notifier).joinRoom();
    });
  }

  @override
  void dispose() {
    ref.read(voiceClubProvider.notifier).leaveRoom();
    super.dispose();
  }

  Future<void> _handleLeaveRoom() async {
    HapticFeedback.heavyImpact();
    await ref.read(voiceClubProvider.notifier).leaveRoom();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B2A4A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          content: const Row(
            children: [
              Icon(Icons.call_end_rounded, color: Color(0xFFFF0055), size: 20),
              SizedBox(width: 8),
              Text('Ovozli muloqot xonasidan chiqdingiz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      widget.onLeave?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceClubProvider);
    final participants = state.participants;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        ref.read(voiceClubProvider.notifier).leaveRoom();
      },
      child: Column(
        children: [
          // Topic Header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2A4A), Color(0xFF0F1A2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0x3300FF88),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF3A7FCC), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🔴 JONLI SUHBAT', style: TextStyle(color: Color(0xFFFF0055), fontSize: 10, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 8),
                          Text('• ${participants.length} nafar', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kitobxonlar Ovozli Klubi 🎙️',
                        style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // Quick Leave Header Button
                GestureDetector(
                  onTap: _handleLeaveRoom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0055).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF0055), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFFF0055), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Chiqish',
                          style: TextStyle(color: Color(0xFFFF0055), fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(state.error!, style: const TextStyle(color: Colors.red)),
            ),

          // Active Speakers Grid
          Expanded(
            child: state.isJoined
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final reader = participants[index];
                      final isSpeaking = reader.isSpeaking;

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090B18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSpeaking ? const Color(0xFF3A7FCC) : Colors.white12,
                            width: isSpeaking ? 2 : 1,
                          ),
                          boxShadow: isSpeaking
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF3A7FCC).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isSpeaking)
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF3A7FCC), width: 2),
                                    ),
                                  ),
                                AvatarCircle(
                                  avatarKey: reader.avatar,
                                  photoUrl: reader.photoUrl,
                                  photoBase64: reader.photoBase64,
                                  size: 48,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: isSpeaking ? const Color(0xFF3A7FCC) : const Color(0xFF334155),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSpeaking ? Icons.mic : Icons.mic_off,
                                      size: 10,
                                      color: isSpeaking ? Colors.black : Colors.white60,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reader.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(child: CircularProgressIndicator(color: Color(0xFF3A7FCC))),
          ),

          // ── Bottom Voice Control Bar ──
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 14),
            decoration: const BoxDecoration(
              color: Color(0xFF090B18),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _VoiceControlButton(
                  icon: state.isSpeakerMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  label: state.isSpeakerMuted ? 'Dinamik o‘chiq' : 'Dinamik',
                  isActive: !state.isSpeakerMuted,
                  activeColor: const Color(0xFF4AADDC),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(voiceClubProvider.notifier).toggleSpeaker();
                  },
                ),
                _VoiceControlButton(
                  icon: state.isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: state.isMicMuted ? 'Mikrofon' : 'Gapiryapsiz',
                  isActive: !state.isMicMuted,
                  activeColor: const Color(0xFF3A7FCC),
                  isLarge: true,
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    ref.read(voiceClubProvider.notifier).toggleMic();
                  },
                ),
                _VoiceControlButton(
                  icon: Icons.front_hand_rounded,
                  label: _hasRaisedHand ? 'Qo‘l ko‘tarilgan' : 'Qo‘l ko‘tarish',
                  isActive: _hasRaisedHand,
                  activeColor: const Color(0xFFFFB703),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _hasRaisedHand = !_hasRaisedHand);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF090B18),
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          _hasRaisedHand ? '✋ Moderatorga so‘z so‘rab navbatga yozildingiz' : 'Qo‘l tushirildi',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                // Prominent Red Leave Button
                _VoiceControlButton(
                  icon: Icons.call_end_rounded,
                  label: 'Tark etish',
                  isActive: true,
                  activeColor: const Color(0xFFFF0055),
                  onTap: _handleLeaveRoom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  final bool isLarge;

  const _VoiceControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isLarge ? 16 : 11),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : Colors.white12,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white54,
              size: isLarge ? 26 : 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white54,
              fontSize: 9.5,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
