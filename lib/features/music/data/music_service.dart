import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/music_track.dart';

final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService();
});

class MusicPlayerState {
  const MusicPlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.isLoading = false,
    this.isLooping = false,
    this.isShuffling = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.selectedCategory = 'workout',
    this.playlist = const [],
  });

  final MusicTrack? currentTrack;
  final bool isPlaying;
  final bool isLoading;
  final bool isLooping;
  final bool isShuffling;
  final Duration position;
  final Duration duration;
  final String selectedCategory;
  final List<MusicTrack> playlist;

  MusicPlayerState copyWith({
    MusicTrack? currentTrack,
    bool? isPlaying,
    bool? isLoading,
    bool? isLooping,
    bool? isShuffling,
    Duration? position,
    Duration? duration,
    String? selectedCategory,
    List<MusicTrack>? playlist,
    bool clearCurrentTrack = false,
  }) {
    return MusicPlayerState(
      currentTrack: clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isLooping: isLooping ?? this.isLooping,
      isShuffling: isShuffling ?? this.isShuffling,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      playlist: playlist ?? this.playlist,
    );
  }
}

class MusicNotifier extends Notifier<MusicPlayerState> {
  final AudioPlayer _player = AudioPlayer();
  int _playRequestId = 0;

  @override
  MusicPlayerState build() {
    _initPlayer();
    ref.onDispose(() {
      _player.dispose();
    });
    return const MusicPlayerState();
  }

  void _initPlayer() {
    _player.playerStateStream.listen((pState) {
      final isBuffering = pState.processingState == ProcessingState.buffering ||
          pState.processingState == ProcessingState.loading;
      state = state.copyWith(
        isPlaying: pState.playing && pState.processingState != ProcessingState.completed,
        isLoading: isBuffering,
      );

      // Auto-play next track when current track completes
      if (pState.processingState == ProcessingState.completed) {
        if (!state.isLooping) {
          playNext();
        }
      }
    });

    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });
  }

  void toggleLoop() {
    final nextLoop = !state.isLooping;
    state = state.copyWith(isLooping: nextLoop);
    _player.setLoopMode(nextLoop ? LoopMode.one : LoopMode.off);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffling: !state.isShuffling);
  }

  void setPlaylist(List<MusicTrack> list) {
    state = state.copyWith(playlist: list);
  }

  Future<void> playNext([List<MusicTrack>? overrideList]) async {
    final list = overrideList ?? state.playlist;
    if (list.isEmpty) return;
    if (state.isShuffling) {
      final randIndex = (DateTime.now().millisecondsSinceEpoch ~/ 17) % list.length;
      await playTrack(list[randIndex], playlist: list);
      return;
    }
    final currentIndex = list.indexWhere((t) => t.id == state.currentTrack?.id);
    if (currentIndex != -1 && currentIndex + 1 < list.length) {
      await playTrack(list[currentIndex + 1], playlist: list);
    } else if (list.isNotEmpty) {
      await playTrack(list.first, playlist: list);
    }
  }

  Future<void> playPrevious([List<MusicTrack>? overrideList]) async {
    final list = overrideList ?? state.playlist;
    if (list.isEmpty) return;
    final currentIndex = list.indexWhere((t) => t.id == state.currentTrack?.id);
    if (currentIndex > 0) {
      await playTrack(list[currentIndex - 1], playlist: list);
    } else if (list.isNotEmpty) {
      await playTrack(list.last, playlist: list);
    }
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<File?> _getLocalTrackFile(MusicTrack track) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/odat_music');
      if (!musicDir.existsSync()) {
        musicDir.createSync(recursive: true);
      }
      final safeName = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      return File('${musicDir.path}/$safeName.mp3');
    } catch (e) {
      debugPrint('⚠️ Error resolving odat_music storage: $e');
      return null;
    }
  }

  Future<bool> isTrackDownloaded(MusicTrack track) async {
    final file = await _getLocalTrackFile(track);
    return file != null && file.existsSync() && file.lengthSync() > 1000;
  }

  Future<void> _downloadTrack(MusicTrack track, File localFile) async {
    final audioUrl = track.audioUrl.trim();
    if (audioUrl.isEmpty) return;

    try {
      // 1. Handle Base64 encoded audio
      if (audioUrl.startsWith('data:audio') || audioUrl.startsWith('data:application')) {
        debugPrint('📥 [ODAT Music] Decoding Base64 audio for: ${track.title}');
        final commaIndex = audioUrl.indexOf(',');
        final base64Str = commaIndex != -1 ? audioUrl.substring(commaIndex + 1) : audioUrl;
        final bytes = base64Decode(base64Str.trim());
        await localFile.writeAsBytes(bytes, flush: true);
        debugPrint('✅ [ODAT Music] Base64 audio saved (${bytes.length} bytes): ${localFile.path}');
        return;
      }

      // 2. Handle HTTP/HTTPS audio stream
      if (audioUrl.startsWith('http')) {
        debugPrint('📥 [ODAT Music] Downloading: ${track.title} → ${localFile.path}');
        final httpClient = HttpClient();
        httpClient.connectionTimeout = const Duration(seconds: 30);

        var request = await httpClient.getUrl(Uri.parse(audioUrl));
        request.headers.set('User-Agent', 'FlowApp/1.0 AudioPlayer');
        var response = await request.close();

        int redirectCount = 0;
        while ((response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307) && redirectCount < 5) {
          final location = response.headers.value('location');
          if (location == null) break;
          await response.drain();
          request = await httpClient.getUrl(Uri.parse(location));
          request.headers.set('User-Agent', 'FlowApp/1.0 AudioPlayer');
          response = await request.close();
          redirectCount++;
        }

        if (response.statusCode == 200) {
          final sink = localFile.openWrite();
          await response.pipe(sink);
          await sink.flush();
          await sink.close();
          debugPrint('✅ [ODAT Music] Downloaded to odat_music: ${localFile.lengthSync()} bytes → ${localFile.path}');
        } else {
          debugPrint('⚠️ [ODAT Music] HTTP ${response.statusCode} for track: $audioUrl');
          await response.drain();
        }
        httpClient.close();
      }
    } catch (e) {
      debugPrint('⚠️ [ODAT Music] Download error: $e');
    }
  }

  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? playlist}) async {
    final requestId = ++_playRequestId;

    if (playlist != null && playlist.isNotEmpty) {
      state = state.copyWith(playlist: playlist);
    }

    if (state.currentTrack?.id == track.id) {
      if (state.isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    try {
      state = state.copyWith(currentTrack: track, isLoading: true, position: Duration.zero);
      await _player.stop();
      if (requestId != _playRequestId) return;

      final localFile = await _getLocalTrackFile(track);
      if (requestId != _playRequestId) return;
      
      final audioUrl = track.audioUrl.trim();

      // ── 0. Direct Asset Path ──
      if (audioUrl.startsWith('assets/')) {
        try {
          final duration = await _player.setAsset(audioUrl);
          if (duration != null) state = state.copyWith(duration: duration);
          await _player.play();
          state = state.copyWith(isLoading: false, isPlaying: true);
          return;
        } catch (assetErr) {
          debugPrint('⚠️ [Music] Asset error: $assetErr');
        }
      }

      // ── 1. Play instantly from local cache (already downloaded) ──
      if (localFile != null && localFile.existsSync() && localFile.lengthSync() > 1000) {
        try {
          final duration = await _player.setFilePath(localFile.path);
          if (duration != null) state = state.copyWith(duration: duration);
          debugPrint('🎵 [Music] Local cache: ${localFile.path}');
          await _player.play();
          state = state.copyWith(isLoading: false, isPlaying: true);
          return;
        } catch (e) {
          debugPrint('⚠️ [Music] Local file error: $e — removing');
          try { localFile.deleteSync(); } catch (_) {}
        }
      }

      // ── 2. HTTP Storage URL — play instantly and download in background ──
      if (audioUrl.startsWith('http')) {
        debugPrint('🌐 [Music] Instant stream: $audioUrl');
        await _player.setVolume(1.0);
        try {
          final duration = await _player.setUrl(
            audioUrl,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Mobile Safari/537.36',
            },
          );
          if (requestId != _playRequestId) return;
          if (duration != null) state = state.copyWith(duration: duration);
          await _player.play();
          if (requestId != _playRequestId) return;
          state = state.copyWith(isLoading: false, isPlaying: true);
          return;
        } catch (streamErr) {
          debugPrint('⚠️ [Music] Stream failed ($streamErr), attempting background download and fallback');
          if (localFile != null) {
            await _downloadTrack(track, localFile);
            if (requestId != _playRequestId) return;
            if (localFile.existsSync() && localFile.lengthSync() > 1000) {
              final duration = await _player.setFilePath(localFile.path);
              if (requestId != _playRequestId) return;
              if (duration != null) state = state.copyWith(duration: duration);
              await _player.play();
              if (requestId != _playRequestId) return;
              state = state.copyWith(isLoading: false, isPlaying: true);
              return;
            }
          }
        }
      }

      // ── 3. Base64 data URL — decode and cache locally ──
      if (audioUrl.startsWith('data:audio') || audioUrl.startsWith('data:application')) {
        if (localFile != null) {
          await _downloadTrack(track, localFile);
          if (localFile.existsSync() && localFile.lengthSync() > 1000) {
            final duration = await _player.setFilePath(localFile.path);
            if (duration != null) state = state.copyWith(duration: duration);
          }
        }
        await _player.play();
        state = state.copyWith(isLoading: false, isPlaying: true);
        return;
      }

      // ── 4. Fallback: Local Bundled Assets (Always Works) ──
      final fallbackAsset = _getCategoryAsset(track.category);
      try {
        final duration = await _player.setAsset(fallbackAsset);
        if (duration != null) state = state.copyWith(duration: duration);
        await _player.play();
        state = state.copyWith(isLoading: false, isPlaying: true);
        return;
      } catch (assetErr) {
        debugPrint('⚠️ [Music] Asset fallback error: $assetErr');
      }

      // ── 5. Fallback: Firestore audioChunks (legacy tracks only) ──
      try {
        debugPrint('⚠️ [Music] Falling back to Firestore chunks for: ${track.title}');
        final chunksSnap = await FirebaseFirestore.instance
            .collection('music_tracks')
            .doc(track.id)
            .collection('audio_chunks')
            .orderBy('index')
            .get();

        if (chunksSnap.docs.isNotEmpty && localFile != null) {
          final sortedDocs = chunksSnap.docs;
          final allBase64 = StringBuffer();
          for (final doc in sortedDocs) {
            allBase64.write((doc.data()['chunk'] as String?) ?? '');
          }
          final bytes = base64Decode(allBase64.toString().trim());
          await localFile.writeAsBytes(bytes, flush: true);
          final duration = await _player.setFilePath(localFile.path);
          if (duration != null) state = state.copyWith(duration: duration);
          await _player.play();
          state = state.copyWith(isLoading: false, isPlaying: true);
          return;
        }
      } catch (e) {
        debugPrint('⚠️ [Music] Chunks fallback error: $e');
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('⚠️ [Music] Global playback error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  static String _getCategoryAsset(String category) {
    switch (category.toLowerCase()) {
      case 'workout':
      case 'motivation':
        return 'assets/sounds/forest.mp3';
      case 'study':
        return 'assets/sounds/lofi.mp3';
      case 'gaming':
        return 'assets/sounds/ocean.mp3';
      case 'zen':
      case 'nasheed':
        return 'assets/sounds/rain.mp3';
      default:
        return 'assets/sounds/lofi.mp3';
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> stop() async {
    await _player.stop();
    state = state.copyWith(clearCurrentTrack: true, isPlaying: false, position: Duration.zero);
  }
}

final musicPlayerProvider =
    NotifierProvider<MusicNotifier, MusicPlayerState>(MusicNotifier.new);

class MusicService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Default fallback curated audio tracks for workouts, study, gaming, and zen
  static final List<MusicTrack> defaultTracks = [
    const MusicTrack(
      id: 'track_workout_1',
      title: 'Titan Kinetic Beats',
      artist: 'ODAT Fitness',
      audioUrl: 'assets/sounds/forest.mp3',
      category: 'workout',
      coverEmoji: '⚡',
      durationSec: 372,
    ),
    const MusicTrack(
      id: 'track_workout_2',
      title: 'Cyber Cardio Sprint',
      artist: 'ODAT Running',
      audioUrl: 'assets/sounds/ocean.mp3',
      category: 'workout',
      coverEmoji: '🔥',
      durationSec: 423,
    ),
    const MusicTrack(
      id: 'track_study_1',
      title: 'Deep Focus & Ambient Lofi',
      artist: 'ODAT Mind',
      audioUrl: 'assets/sounds/lofi.mp3',
      category: 'study',
      coverEmoji: '📚',
      durationSec: 350,
    ),
    const MusicTrack(
      id: 'track_study_2',
      title: 'Alpha Waves Brain Focus',
      artist: 'ODAT Zen',
      audioUrl: 'assets/sounds/white_noise.mp3',
      category: 'study',
      coverEmoji: '🧠',
      durationSec: 315,
    ),
    const MusicTrack(
      id: 'track_gaming_1',
      title: 'Cyberpunk 1v1 Battle Arena',
      artist: 'ODAT Gaming',
      audioUrl: 'assets/sounds/ocean.mp3',
      category: 'gaming',
      coverEmoji: '⚔️',
      durationSec: 360,
    ),
    const MusicTrack(
      id: 'track_zen_1',
      title: 'Meditation & Calm Rain',
      artist: 'ODAT Nature',
      audioUrl: 'assets/sounds/rain.mp3',
      category: 'zen',
      coverEmoji: '🧘',
      durationSec: 400,
    ),
    const MusicTrack(
      id: 'track_motivation_1',
      title: 'Unstoppable Momentum',
      artist: 'ODAT Energy',
      audioUrl: 'assets/sounds/forest.mp3',
      category: 'motivation',
      coverEmoji: '⚡',
      durationSec: 390,
    ),
    const MusicTrack(
      id: 'track_nasheed_1',
      title: 'Spiritual Peace & Harmony',
      artist: 'ODAT Peace',
      audioUrl: 'assets/sounds/rain.mp3',
      category: 'nasheed',
      coverEmoji: '🌙',
      durationSec: 300,
    ),
  ];

  /// Streams tracks directly from Firestore `music_tracks`.
  /// When a track is deleted or added in Firestore/Bot, it updates instantly in real-time.
  Stream<List<MusicTrack>> watchMusicTracks() {
    return _db
        .collection('music_tracks')
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      if (snap.docs.isEmpty) {
        return defaultTracks;
      }
      return snap.docs.map((d) => MusicTrack.fromMap(d.data(), id: d.id)).toList();
    });
  }
}

final musicTracksStreamProvider = StreamProvider<List<MusicTrack>>((ref) {
  return ref.watch(musicServiceProvider).watchMusicTracks();
});
