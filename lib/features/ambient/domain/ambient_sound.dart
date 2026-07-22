import 'package:flutter/material.dart';

/// An ambient focus sound that loops during a session. Files live in
/// `assets/sounds/`.
enum AmbientSound {
  rain('Rain', 'rain.mp3', Icons.water_drop_rounded),
  forest('Forest', 'forest.mp3', Icons.forest_rounded),
  ocean('Ocean', 'ocean.mp3', Icons.waves_rounded),
  whiteNoise('White noise', 'white_noise.mp3', Icons.graphic_eq_rounded),
  lofi('Lo-fi', 'lofi.mp3', Icons.music_note_rounded);

  const AmbientSound(this.label, this.file, this.icon);

  final String label;
  final String file;
  final IconData icon;

  String get asset => 'assets/sounds/$file';

  static AmbientSound? fromName(String? name) {
    if (name == null) return null;
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}
