import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../data/alarm_sound_provider.dart';

class AlarmSoundSheet extends ConsumerStatefulWidget {
  const AlarmSoundSheet({super.key});

  @override
  ConsumerState<AlarmSoundSheet> createState() => _AlarmSoundSheetState();
}

class _AlarmSoundSheetState extends ConsumerState<AlarmSoundSheet> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<Map<String, String>> _defaultSounds = [
    {'name': 'Klassik', 'path': 'assets/sounds/alarm.wav'},
    {'name': 'Yumshoq', 'path': 'assets/sounds/alarm_soft.wav'},
    {'name': 'Qattiq', 'path': 'assets/sounds/alarm_loud.wav'},
  ];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String path) async {
    try {
      if (path.startsWith('assets/')) {
        await _audioPlayer.setAsset(path);
      } else {
        await _audioPlayer.setFilePath(path);
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> _pickCustomFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        ref.read(alarmSoundProvider.notifier).setSound(path);
        _playSound(path);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentSound = ref.watch(alarmSoundProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Budilnik ovozi',
                style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ..._defaultSounds.map((sound) {
            final isSelected = currentSound == sound['path'];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(
                sound['name']!,
                style: AppTextStyles.label.copyWith(
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.play_circle_outline_rounded, color: colors.textSecondary),
                    onPressed: () => _playSound(sound['path']!),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded, color: colors.primary, size: 22),
                ],
              ),
              onTap: () {
                ref.read(alarmSoundProvider.notifier).setSound(sound['path']!);
              },
            );
          }),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: _pickCustomFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text('settings.custom_sound_pick'.tr()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!currentSound.startsWith('assets/'))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Tanlangan fayl: ...${currentSound.split('/').last}',
                style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

void showAlarmSoundSheet(BuildContext context) {
  final colors = context.colors;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const AlarmSoundSheet(),
  );
}
