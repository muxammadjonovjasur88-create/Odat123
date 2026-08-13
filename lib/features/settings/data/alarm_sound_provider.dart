import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AlarmSoundNotifier extends Notifier<String> {
  static const _key = 'task_alarm_sound';

  @override
  String build() {
    // Start with the default and load the saved value asynchronously.
    _load();
    return 'system_alarm';
  }

  Future<void> _load() async {
    final box = await Hive.openBox('flowa_settings');
    final saved = box.get(_key) as String?;
    if (saved != null && saved.isNotEmpty) {
      state = saved == 'assets/sounds/alarm.wav' ? 'system_alarm' : saved;
    }
  }

  Future<void> setSound(String path) async {
    state = path;
    final box = await Hive.openBox('flowa_settings');
    await box.put(_key, path);
  }
}

final alarmSoundProvider = NotifierProvider<AlarmSoundNotifier, String>(
  AlarmSoundNotifier.new,
);
