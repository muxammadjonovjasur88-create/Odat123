import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/user_repository.dart';
import '../../data/music_service.dart';
import '../../domain/music_track.dart';

class MusicSectionWidget extends ConsumerStatefulWidget {
  const MusicSectionWidget({super.key});

  @override
  ConsumerState<MusicSectionWidget> createState() => _MusicSectionWidgetState();
}

class _MusicSectionWidgetState extends ConsumerState<MusicSectionWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(musicPlayerProvider);
    final tracksAsync = ref.watch(musicTracksStreamProvider);

    final categories = [
      {'id': 'all', 'label': '🔥 Barchasi', 'color': const Color(0xFFFFB703)},
      {'id': 'workout', 'label': '🏋️ ${'music.workout'.tr()}', 'color': const Color(0xFF3A7FCC)},
      {'id': 'study', 'label': '📚 ${'music.study'.tr()}', 'color': const Color(0xFF4AADDC)},
      {'id': 'zen', 'label': '🧘 ${'music.zen'.tr()}', 'color': const Color(0xFF6B25CC)},
      {'id': 'motivation', 'label': '⚡ Motivatsiya', 'color': const Color(0xFFFF7B00)},
      {'id': 'gaming', 'label': '🎮 ${'music.gaming'.tr()}', 'color': const Color(0xFFFF0055)},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF090B18), Color(0xFF090B18)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x334AADDC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4AADDC).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Playing Indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0x224AADDC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note_rounded, color: Color(0xFF4AADDC), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'music.title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'music.sub'.tr(),
                      style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (playerState.isPlaying) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x224AADDC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3A7FCC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq_rounded, color: Color(0xFF3A7FCC), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'IJRO ETILMOQDA',
                        style: TextStyle(color: Color(0xFF3A7FCC), fontSize: 8.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // ── Search Bar ──────────────────────────────────────────
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF090B18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _searchQuery.isNotEmpty ? const Color(0xFF4AADDC) : const Color(0x22FFFFFF),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Musiqa yoki ijrochini qidirish...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4AADDC), size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Category Chips ──────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: categories.map((cat) {
                final isSel = playerState.selectedCategory == cat['id'];
                final color = cat['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(musicPlayerProvider.notifier).selectCategory(cat['id'] as String);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? color.withValues(alpha: 0.25) : const Color(0xFF090B18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? color : const Color(0x22FFFFFF),
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        cat['label'] as String,
                        style: TextStyle(
                          color: isSel ? color : Colors.white70,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // ── Track List ──────────────────────────────────────────
          tracksAsync.when(
            data: (allTracks) {
              // 1. Filter by category
              var filtered = allTracks;
              if (playerState.selectedCategory != 'all') {
                filtered = filtered
                    .where((t) => t.category.toLowerCase() == playerState.selectedCategory.toLowerCase())
                    .toList();
              }

              // 2. Filter by search query
              if (_searchQuery.isNotEmpty) {
                filtered = filtered.where((t) {
                  return t.title.toLowerCase().contains(_searchQuery) ||
                      t.artist.toLowerCase().contains(_searchQuery) ||
                      t.category.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.library_music_rounded,
                          color: Colors.white24,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Qidiruv bo‘yicha musiqa topilmadi'
                              : 'Hozircha ushbu bo‘limda musiqa yo‘q',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final userProfile = ref.watch(userProfileProvider).asData?.value;
              final myUid = ref.watch(authStateProvider).asData?.value?.uid ?? '';

              // 3. Limit to 5 if not searching and not expanded
              final totalCount = filtered.length;
              final displayList = (_searchQuery.isNotEmpty || _showAll)
                  ? filtered
                  : filtered.take(5).toList();

              return Column(
                children: [
                  ...displayList.map((track) {
                    final isCurrent = playerState.currentTrack?.id == track.id;
                    final isThisPlaying = isCurrent && playerState.isPlaying;
                    final isUnlocked = track.ptsCost <= 0 || (userProfile?.isTrackUnlocked(track.id) ?? false);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0x224AADDC) : const Color(0xFF090B18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent ? const Color(0xFF4AADDC) : const Color(0x15FFFFFF),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0x22FFFFFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                isCurrent ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                                color: isCurrent ? const Color(0xFF4AADDC) : Colors.white60,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: TextStyle(
                                    color: isCurrent ? const Color(0xFF4AADDC) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0x22FFFFFF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        track.category.toUpperCase(),
                                        style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 8.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    FutureBuilder<bool>(
                                      future: ref.read(musicPlayerProvider.notifier).isTrackDownloaded(track),
                                      builder: (context, snapshot) {
                                        final isDownloaded = snapshot.data == true;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isDownloaded ? const Color(0x224AADDC) : const Color(0x22FFFFFF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isDownloaded ? const Color(0xFF3A7FCC) : Colors.white24,
                                              width: 0.6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isDownloaded ? Icons.download_done_rounded : Icons.cloud_outlined,
                                                size: 10,
                                                color: isDownloaded ? const Color(0xFF3A7FCC) : Colors.white60,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                isDownloaded ? 'Yuklangan' : 'Online',
                                                style: TextStyle(
                                                  color: isDownloaded ? const Color(0xFF3A7FCC) : Colors.white60,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    if (track.ptsCost > 0 && !isUnlocked) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0x33FFB703),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFFB703), width: 0.8),
                                        ),
                                        child: Text(
                                          '${track.ptsCost} PTS',
                                          style: const TextStyle(color: Color(0xFFFFB703), fontSize: 8.5, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent && playerState.isLoading)
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF4AADDC),
                                ),
                              ),
                            )
                          else if (!isUnlocked)
                            InkWell(
                              onTap: () => _showUnlockModal(context, track, userProfile, myUid),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFB703), Color(0xFFFF7B00)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x44FFB703), blurRadius: 8),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_rounded, color: Colors.black, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${track.ptsCost} PTS',
                                      style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: Icon(
                                isThisPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                color: isCurrent ? const Color(0xFF4AADDC) : const Color(0xFF3A7FCC),
                                size: 36,
                              ),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                ref.read(musicPlayerProvider.notifier).playTrack(track, playlist: displayList);
                              },
                            ),
                        ],
                      ),
                    );
                  }),

                  // Show More / Show Less Button if > 5 tracks
                  if (_searchQuery.isEmpty && totalCount > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showAll = !_showAll);
                        },
                        icon: Icon(
                          _showAll ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF4AADDC),
                          size: 18,
                        ),
                        label: Text(
                          _showAll
                              ? 'Kamroq ko‘rsatish'
                              : 'Barchasini ko‘rish (jami $totalCount ta)',
                          style: const TextStyle(
                            color: Color(0xFF4AADDC),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  // Floating Glassmorphic Audio Player Bar
                  if (playerState.currentTrack != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1C2540), Color(0xFF090B18)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF4AADDC), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4AADDC).withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Cover Art & Equalizer
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  playerState.currentTrack!.coverEmoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playerState.currentTrack!.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      playerState.currentTrack!.artist,
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  playerState.isShuffling ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
                                  color: playerState.isShuffling ? const Color(0xFF3A7FCC) : Colors.white38,
                                  size: 20,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(musicPlayerProvider.notifier).toggleShuffle();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  ref.read(musicPlayerProvider.notifier).playPrevious();
                                },
                              ),
                              if (playerState.isLoading)
                                const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF4AADDC),
                                  ),
                                )
                              else
                                IconButton(
                                  icon: Icon(
                                    playerState.isPlaying
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_fill_rounded,
                                    color: const Color(0xFF4AADDC),
                                    size: 38,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    if (playerState.isPlaying) {
                                      ref.read(musicPlayerProvider.notifier).pause();
                                    } else {
                                      ref.read(musicPlayerProvider.notifier).resume();
                                    }
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  ref.read(musicPlayerProvider.notifier).playNext();
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  playerState.isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                  color: playerState.isLooping ? const Color(0xFF3A7FCC) : Colors.white38,
                                  size: 20,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(musicPlayerProvider.notifier).toggleLoop();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Track Progress & Slider
                          Row(
                            children: [
                              Text(
                                _formatDuration(playerState.position),
                                style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    trackHeight: 3,
                                    activeTrackColor: const Color(0xFF4AADDC),
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: const Color(0xFF3A7FCC),
                                  ),
                                  child: Slider(
                                    value: playerState.duration.inMilliseconds > 0
                                        ? playerState.position.inMilliseconds
                                            .clamp(0, playerState.duration.inMilliseconds)
                                            .toDouble()
                                        : 0.0,
                                    max: playerState.duration.inMilliseconds > 0
                                        ? playerState.duration.inMilliseconds.toDouble()
                                        : 1.0,
                                    onChanged: (val) {
                                      ref
                                          .read(musicPlayerProvider.notifier)
                                          .seek(Duration(milliseconds: val.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(playerState.duration),
                                style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF4AADDC))),
            ),
            error: (e, _) => Center(
              child: Text('Audio xatolik: $e', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnlockModal(BuildContext context, MusicTrack track, UserProfile? profile, String uid) {
    HapticFeedback.mediumImpact();
    final currentPoints = profile?.totalPoints ?? 0;
    final canAfford = currentPoints >= track.ptsCost;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF090B18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF4AADDC), width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4AADDC), Color(0xFFFFB703)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x444AADDC), blurRadius: 16),
                ],
              ),
              child: const Center(
                child: Icon(Icons.music_note_rounded, color: Color(0xFF090B18), size: 36),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              track.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              track.artist,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2540),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('music.track_price'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('${track.ptsCost} ⚡ PTS', style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                  Container(width: 1, height: 32, color: Colors.white12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('music.your_balance'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('$currentPoints ⚡ PTS', style: TextStyle(color: canAfford ? const Color(0xFF3A7FCC) : const Color(0xFFFF4D6D), fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (canAfford)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4AADDC),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    HapticFeedback.heavyImpact();
                    if (uid.isNotEmpty) {
                      final success = await ref.read(userRepositoryProvider).unlockMusicTrack(uid, track.id, track.ptsCost);
                      if (success) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🎉 "${track.title}" muvaffaqiyatli ochildi!'),
                              backgroundColor: const Color(0xFF3A7FCC),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        ref.read(musicPlayerProvider.notifier).playTrack(track);
                      }
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_open_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${track.ptsCost} PTS ga Ochish & Tinglash',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0x22FF4D6D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF4D6D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4D6D), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Balansingizda yetarli PTS yo‘q. Fokus seanslar orqali ball to‘plang!',
                        style: TextStyle(color: Color(0xFFFF4D6D), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}
