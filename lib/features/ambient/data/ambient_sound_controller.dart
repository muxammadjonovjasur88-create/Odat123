import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/ambient_sound.dart';

/// State of the ambient focus sound: the selected sound (null = off), the
/// volume (0..1), and whether it's muted.
@immutable
class AmbientSoundState {
  const AmbientSoundState({
    this.sound,
    this.volume = 0.5,
    this.muted = false,
  });

  final AmbientSound? sound;
  final double volume;
  final bool muted;

  bool get hasSound => sound != null;

  /// Volume actually sent to the player (0 while muted).
  double get effectiveVolume => muted ? 0 : volume;

  AmbientSoundState copyWith({
    AmbientSound? sound,
    bool clearSound = false,
    double? volume,
    bool? muted,
  }) => AmbientSoundState(
    sound: clearSound ? null : (sound ?? this.sound),
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
  );
}

/// Owns the looping ambient-sound player (just_audio). Persistent provider so a
/// chosen sound keeps playing across the Deep/Active/Workout focus screens and,
/// while the foreground service holds the process alive, in the background and
/// on the lock screen. Remembers the last sound + volume in Hive.
class AmbientSoundController extends Notifier<AmbientSoundState> {
  AudioPlayer? _player;
  Box<dynamic>? _box;

  static const _boxName = 'flowa_audio';
  static const _kSound = 'sound';
  static const _kVolume = 'volume';
  static const _kMuted = 'muted';

  @override
  AmbientSoundState build() {
    ref.onDispose(() {
      _player?.dispose();
      _player = null;
    });
    _load();
    return const AmbientSoundState();
  }

  Future<void> _load() async {
    try {
      _box = await Hive.openBox<dynamic>(_boxName);
      state = state.copyWith(
        sound: AmbientSound.fromName(_box!.get(_kSound) as String?),
        volume: (_box!.get(_kVolume) as num?)?.toDouble() ?? 0.5,
        muted: _box!.get(_kMuted) as bool? ?? false,
      );
    } catch (_) {
      // Hive unavailable — keep in-memory defaults.
    }
  }

  Future<void> _persist() async {
    final box = _box;
    if (box == null) return;
    await box.put(_kSound, state.sound?.name);
    await box.put(_kVolume, state.volume);
    await box.put(_kMuted, state.muted);
  }

  AudioPlayer get _ensurePlayer => _player ??= AudioPlayer();

  /// User tapped a sound chip. Tapping the active sound (or None → null) stops;
  /// any other sound starts looping.
  Future<void> select(AmbientSound? sound) async {
    if (sound == null || sound == state.sound) {
      state = state.copyWith(clearSound: true);
      await _player?.stop();
      await _persist();
      return;
    }
    state = state.copyWith(sound: sound);
    await _persist();
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final s = state.sound;
    if (s == null) return;
    final player = _ensurePlayer;
    try {
      await player.setAsset(s.asset);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(state.effectiveVolume);
      await player.play();
    } catch (_) {
      // Asset/codec issue — fail quietly so the focus session is unaffected.
    }
  }

  /// Resume the remembered sound when a focus screen becomes active (it stays
  /// selected after a previous session ended, so it auto-plays next time).
  Future<void> resumeIfSelected() async {
    if (state.sound != null && !(_player?.playing ?? false)) {
      await _playCurrent();
    }
  }

  Future<void> setVolume(double v) async {
    state = state.copyWith(volume: v.clamp(0.0, 1.0), muted: false);
    await _player?.setVolume(state.effectiveVolume);
    await _persist();
  }

  Future<void> toggleMute() async {
    state = state.copyWith(muted: !state.muted);
    await _player?.setVolume(state.effectiveVolume);
    await _persist();
  }

  /// Stops playback (e.g. the session ended) WITHOUT forgetting the chosen
  /// sound, so it auto-resumes for the next session.
  Future<void> stopPlayback() async {
    await _player?.stop();
  }
}

final ambientSoundProvider =
    NotifierProvider<AmbientSoundController, AmbientSoundState>(
      AmbientSoundController.new,
    );
