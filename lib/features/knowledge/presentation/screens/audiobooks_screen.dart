import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

class AudiobooksScreen extends StatefulWidget {
  const AudiobooksScreen({super.key});

  @override
  State<AudiobooksScreen> createState() => _AudiobooksScreenState();
}

class _AudiobooksScreenState extends State<AudiobooksScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _currentTrackId; // track by ID, not index — filter-safe
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _speed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String _selectedCategory = 'all'; // 'all', 'walk_learn', 'it', 'business', 'psychology', 'audiobooks'

  List<Map<String, dynamic>> _audioItems = [];
  StreamSubscription? _audiobooksSubscription;
  StreamSubscription? _podcastsSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToContent();

    _player.playerStateStream.listen((ps) {
      if (mounted) {
        setState(() {
          _isPlaying = ps.playing && ps.processingState != ProcessingState.completed;
          _isBuffering = ps.processingState == ProcessingState.loading ||
              ps.processingState == ProcessingState.buffering;
        });
      }
    });

    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });

    // Reset state when playback completes naturally
    _player.playbackEventStream.listen((_) {}, onError: (e) {
      debugPrint('Audio playback event error: $e');
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  void _listenToContent() {
    try {
      List<Map<String, dynamic>> dbBooks = [];
      List<Map<String, dynamic>> dbPodcasts = [];

      void updateList() {
        final combined = [...dbPodcasts, ...dbBooks];
        final seen = <String>{};
        final unique = <Map<String, dynamic>>[];
        for (final item in combined) {
          final title = (item['title'] as String? ?? '').toLowerCase().trim();
          final author = (item['author'] as String? ?? '').toLowerCase().trim();
          final key = '${title}_$author';
          if (title.isNotEmpty && seen.add(key)) {
            unique.add(item);
          }
        }

        if (mounted) {
          setState(() {
            _audioItems = unique;
            _isLoading = false;
          });
        }
      }

      _audiobooksSubscription = FirebaseFirestore.instance.collection('audiobooks').snapshots().listen((snapshot) {
        dbBooks = snapshot.docs.map((doc) {
          final data = doc.data();
          final rawCat = (data['category'] as String? ?? 'badiiy').toLowerCase();
          final category = (rawCat.contains('badiiy') || rawCat.contains('art') || rawCat.contains('roman') || rawCat.contains('lit') || rawCat == 'audiobooks')
              ? 'badiiy'
              : rawCat;

          return {
            'id': doc.id,
            'title': data['title'] as String? ?? 'Noma’lum audio kitob',
            'author': data['author'] as String? ?? data['creator'] as String? ?? 'Muallif',
            'narrator': data['narrator'] as String? ?? 'O‘zbekcha ovoz',
            'category': category,
            'durationMin': (data['durationMin'] as num?)?.toInt() ?? (data['duration'] as num?)?.toInt() ?? 15,
            'emoji': data['emoji'] as String? ?? '📚',
            'color': const Color(0xFF4AADDC),
            'telegramUrl': data['telegramUrl'] as String? ?? data['tgUrl'] as String? ?? 'https://t.me/odat_fenix',
            'audioUrl': data['audioUrl'] as String? ?? data['url'] as String? ?? data['fileUrl'] as String? ?? data['audio_url'] as String? ?? '',
            'desc': data['desc'] as String? ?? data['description'] as String? ?? '',
          };
        }).toList();
        updateList();
      }, onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      });

      _podcastsSubscription = FirebaseFirestore.instance.collection('podcasts').snapshots().listen((snapshot) {
        dbPodcasts = snapshot.docs.map((doc) {
          final data = doc.data();
          final rawCat = (data['category'] as String? ?? 'walk_learn').toLowerCase();
          return {
            'id': doc.id,
            'title': data['title'] as String? ?? 'Walk & Learn Podkast',
            'author': data['author'] as String? ?? data['creator'] as String? ?? 'ODAT Knowledge',
            'narrator': data['narrator'] as String? ?? 'O‘zbekcha ovoz',
            'category': rawCat,
            'durationMin': (data['durationMin'] as num?)?.toInt() ?? (data['duration'] as num?)?.toInt() ?? 15,
            'emoji': data['emoji'] as String? ?? '🎙️',
            'color': const Color(0xFFFFB703),
            'telegramUrl': data['telegramUrl'] as String? ?? data['tgUrl'] as String? ?? 'https://t.me/odat_fenix',
            'audioUrl': data['audioUrl'] as String? ?? data['url'] as String? ?? data['fileUrl'] as String? ?? data['audio_url'] as String? ?? '',
            'desc': data['desc'] as String? ?? data['description'] as String? ?? '',
          };
        }).toList();
        updateList();
      }, onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _audiobooksSubscription?.cancel();
    _podcastsSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playTrack(Map<String, dynamic> item) async {
    HapticFeedback.mediumImpact();
    final trackId = item['id'] as String? ?? item['title'] as String? ?? '';

    // Toggle pause/play for currently active track
    if (_currentTrackId == trackId) {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    setState(() {
      _currentTrackId = trackId;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    final url = (item['audioUrl'] as String? ?? '').trim();
    final telegramUrl = (item['telegramUrl'] as String? ?? '').trim();

    if (url.isNotEmpty) {
      try {
        await _player.stop();
        Duration? duration;
        if (url.startsWith('assets/') || url.startsWith('asset://')) {
          duration = await _player.setAsset(url);
        } else if (url.startsWith('file://')) {
          duration = await _player.setFilePath(url.replaceFirst('file://', ''));
        } else if (url.startsWith('http://') || url.startsWith('https://')) {
          duration = await _player.setUrl(
            url,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 12) Mobile Safari/537.36',
            },
          );
        } else {
          // Unknown scheme — try as URL
          duration = await _player.setUrl(url);
        }
        if (duration != null && mounted) {
          setState(() => _duration = duration!);
        }
        await _player.setSpeed(_speed);
        await _player.play();
        return;
      } catch (e) {
        debugPrint('Audio play error: $e');
        if (mounted) setState(() => _isPlaying = false);
        // Fall through to telegram fallback
      }
    }

    // URL bo'sh yoki stream xato — Telegram fallback
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF090B18),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF4AADDC), width: 1.2),
          ),
          content: Text(
            url.isEmpty
                ? '⏳ ${item['title']} hali yuklanmagan. Telegramdan tinglang:'
                : '⚠️ Audio stream ochilmadi. Telegramda tinglashingiz mumkin:',
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
          action: telegramUrl.isNotEmpty
              ? SnackBarAction(
                  label: '📱 Telegramda eshitish',
                  textColor: const Color(0xFF4AADDC),
                  onPressed: () => _openTelegram(telegramUrl),
                )
              : null,
        ),
      );
    }
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.25;
      } else if (_speed == 1.25) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
    _player.setSpeed(_speed);
  }

  void _seekRelative(int seconds) {
    HapticFeedback.selectionClick();
    final newPos = _position + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      _player.seek(Duration.zero);
    } else if (newPos > _duration) {
      _player.seek(_duration);
    } else {
      _player.seek(newPos);
    }
  }

  Future<void> _openTelegram(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _audioItems.where((item) {
      if (_selectedCategory == 'all') return true;
      final cat = (item['category'] as String? ?? '').toLowerCase();
      if (_selectedCategory == 'badiiy') {
        return cat == 'badiiy' || cat == 'audiobooks' || cat == 'literature';
      }
      if (_selectedCategory == 'audiobooks') {
        return cat == 'audiobooks' || cat == 'badiiy';
      }
      return cat == _selectedCategory;
    }).toList();

    // Find current track by ID — filter-safe (no stale index)
    final currentTrack = _currentTrackId != null
        ? _audioItems.where((item) {
            final id = item['id'] as String? ?? item['title'] as String? ?? '';
            return id == _currentTrackId;
          }).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.podcasts_rounded, color: Color(0xFF4AADDC), size: 22),
            SizedBox(width: 8),
            Text(
              'Walk & Learn Podkastlar 🎙️',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Filter Chips
            Container(
              height: 48,
              color: const Color(0xFF090B18),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                children: [
                  _categoryChip('all', '🌟 Barchasi'),
                  _categoryChip('badiiy', '📚 Badiiy Kitoblar'),
                  _categoryChip('walk_learn', '🚶‍♂️ Walk & Learn'),
                  _categoryChip('business', '🚀 Biznes'),
                  _categoryChip('psychology', '🧠 Psixologiya'),
                  _categoryChip('it', '💻 IT & AI'),
                  _categoryChip('audiobooks', '🎧 Audio Kitoblar'),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4AADDC)))
                  : filteredList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF4AADDC).withValues(alpha: 0.1),
                                    border: Border.all(color: const Color(0xFF4AADDC).withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(Icons.podcasts_rounded, color: Color(0xFF4AADDC), size: 34),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Hozircha audio darsliklar yo‘q',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Yangi darsliklar va podkastlar tez orada mini app orqali yuklanadi 🎙️',
                                  style: TextStyle(color: Colors.white54, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            final trackId = item['id'] as String? ?? item['title'] as String? ?? '';
                            final isCurrent = _currentTrackId == trackId;
                            final color = item['color'] as Color? ?? const Color(0xFF4AADDC);

                            return GestureDetector(
                              onTap: () => _playTrack(item),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xFF090B18) : const Color(0xFF090B18),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isCurrent ? color : const Color(0x22FFFFFF),
                                    width: isCurrent ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: color.withValues(alpha: 0.4)),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.headphones_rounded,
                                          color: color,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'] as String,
                                            style: TextStyle(
                                              color: isCurrent ? const Color(0xFF4AADDC) : Colors.white,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item['author']} • ${item['durationMin']} daqiqa',
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                          if ((item['desc'] as String? ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              item['desc'] as String,
                                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                     const SizedBox(width: 8),
                                     IconButton(
                                       onPressed: () => _playTrack(item),
                                       icon: isCurrent && _isBuffering
                                           ? const SizedBox(
                                               width: 24,
                                               height: 24,
                                               child: CircularProgressIndicator(
                                                 strokeWidth: 2,
                                                 color: Color(0xFF4AADDC),
                                               ),
                                             )
                                           : Icon(
                                               isCurrent && _isPlaying
                                                   ? Icons.pause_circle_filled_rounded
                                                   : Icons.play_circle_fill_rounded,
                                               color: isCurrent ? const Color(0xFF4AADDC) : Colors.white70,
                                               size: 38,
                                             ),
                                     ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),

      // Bottom Mini Player
      bottomSheet: currentTrack == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF090B18),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(top: BorderSide(color: (currentTrack['color'] as Color).withValues(alpha: 0.5), width: 1.5)),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (currentTrack['color'] as Color).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (currentTrack['color'] as Color).withValues(alpha: 0.5)),
                        ),
                        child: Icon(Icons.headphones_rounded, color: currentTrack['color'] as Color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentTrack['title'] as String,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // 15s Rewind
                      IconButton(
                        onPressed: () => _seekRelative(-15),
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 22),
                      ),
                      // Play / Pause
                      IconButton(
                        onPressed: () {
                          if (_isPlaying) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                          color: const Color(0xFF4AADDC),
                          size: 38,
                        ),
                      ),
                      // 15s Forward
                      IconButton(
                        onPressed: () => _seekRelative(15),
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 22),
                      ),
                      // Speed Button
                      GestureDetector(
                        onTap: _cycleSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B283E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            '${_speed}x',
                            style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _duration.inMilliseconds == 0 ? 0 : _position.inMilliseconds / _duration.inMilliseconds,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(currentTrack['color'] as Color? ?? const Color(0xFF4AADDC)),
                      minHeight: 3.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _categoryChip(String categoryKey, String label) {
    final isSelected = _selectedCategory == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
        ),
        selectedColor: const Color(0xFF4AADDC),
        backgroundColor: const Color(0xFF090B18),
        onSelected: (_) {
          setState(() {
            _selectedCategory = categoryKey;
          });
        },
      ),
    );
  }
}
