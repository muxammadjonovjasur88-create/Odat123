import 'package:cloud_firestore/cloud_firestore.dart';

class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.source,
    required this.category,
    required this.publishedAt,
    this.url,
    this.sourceEmoji = '📰',
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String source;
  final String category; // all, uzbekistan, world, tech, sport
  final DateTime publishedAt;
  final String? url;
  final String sourceEmoji;

  factory NewsItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return NewsItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      source: data['source'] as String? ?? 'Kun.uz',
      category: data['category'] as String? ?? 'uzbekistan',
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      url: data['url'] as String?,
      sourceEmoji: data['sourceEmoji'] as String? ?? '📰',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'source': source,
      'category': category,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'url': url,
      'sourceEmoji': sourceEmoji,
    };
  }
}
