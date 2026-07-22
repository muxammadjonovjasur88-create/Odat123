import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/ambient_sound_controller.dart';
import '../domain/ambient_sound.dart';

/// Compact ambient-sound selector for the focus screens: a row of small Zen
/// icons (None + each sound), plus a volume slider + mute toggle that appears
/// only while a sound is playing. Tapping the active sound or None stops it.
class AmbientSoundBar extends ConsumerWidget {
  const AmbientSoundBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(ambientSoundProvider);
    final controller = ref.read(ambientSoundProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SoundButton(
              icon: Icons.volume_off_rounded,
              label: 'None',
              selected: state.sound == null,
              onTap: () => controller.select(null),
            ),
            for (final sound in AmbientSound.values)
              _SoundButton(
                icon: sound.icon,
                label: sound.label,
                selected: state.sound == sound,
                onTap: () => controller.select(sound),
              ),
          ],
        ),
        if (state.hasSound) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: controller.toggleMute,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    state.muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.surfaceMuted,
                    thumbColor: colors.primary,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: state.muted ? 0 : state.volume,
                    onChanged: controller.setVolume,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SoundButton extends StatelessWidget {
  const _SoundButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? colors.primary : colors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? colors.primary : colors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: selected ? colors.onPrimary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
