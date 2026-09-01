class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.category,
    this.durationSec = 180,
    this.coverEmoji = '🎵',
    this.coverUrl,
    this.ptsCost = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String category; // 'workout', 'study', 'gaming', 'zen'
  final int durationSec;
  final String coverEmoji;
  final String? coverUrl;
  final int ptsCost;

  factory MusicTrack.fromMap(Map<String, dynamic> map, {String? id}) {
    return MusicTrack(
      id: id ?? (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? 'Noma’lum trek',
      artist: map['artist'] as String? ?? 'ODAT Audio',
      audioUrl: map['audioUrl'] as String? ?? '',
      category: map['category'] as String? ?? 'workout',
      durationSec: (map['durationSec'] as num?)?.toInt() ?? 180,
      coverEmoji: map['coverEmoji'] as String? ?? '🎵',
      coverUrl: map['coverUrl'] as String?,
      ptsCost: (map['ptsCost'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'audioUrl': audioUrl,
      'category': category,
      'durationSec': durationSec,
      'coverEmoji': coverEmoji,
      'coverUrl': coverUrl,
      'ptsCost': ptsCost,
    };
  }
}
