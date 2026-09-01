import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../data/ambient_sound_controller.dart';

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: _LargeActionButton(
                icon: Icons.volume_off_rounded,
                label: 'Jim',
                selected: !state.hasSound,
                onTap: () => controller.select(null),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: _LargeActionButton(
                icon: Icons.music_note_rounded,
                label: state.customFilePath != null
                    ? state.customFilePath!.split('/').last.split('\\').last
                    : 'Fayldan tanlash',
                selected: state.hasSound && state.customFilePath != null,
                onTap: () => _pickCustomFile(context, controller),
              ),
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

class _LargeActionButton extends StatelessWidget {
  const _LargeActionButton({
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
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary
                : colors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : colors.border.withValues(alpha: 0.25),
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colors.onPrimary : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? colors.onPrimary : colors.textSecondary,
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

Future<void> _pickCustomFile(
  BuildContext context,
  AmbientSoundController controller,
) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await [Permission.audio, Permission.storage].request();
  }

  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
  );

  if (result != null && result.files.single.path != null) {
    final originalPath = result.files.single.path!;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = result.files.single.name;
      final savedFile = File('${docDir.path}/$fileName');
      if (!savedFile.existsSync()) {
        await File(originalPath).copy(savedFile.path);
      }
      await controller.selectCustomFile(savedFile.path);
    } catch (e) {
      // Fallback to original path if copy fails
      await controller.selectCustomFile(originalPath);
    }
  }
}
