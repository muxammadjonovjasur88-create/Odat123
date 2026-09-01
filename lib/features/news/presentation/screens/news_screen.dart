import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/flowa_loading.dart';
import '../../data/news_repository.dart';
import '../../domain/models/news_item.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  String _selectedCategory = 'all';

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'label': '🔥 Barchasi', 'color': const Color(0xFFFFB703)},
    {'id': 'uzbekistan', 'label': '🇺🇿 O‘zbekiston', 'color': const Color(0xFF5BC8FA)},
    {'id': 'world', 'label': '🌍 Dunyo', 'color': const Color(0xFF3B9BFF)},
    {'id': 'tech', 'label': '⚡ Texnologiya', 'color': const Color(0xFF7B2FFF)},
    {'id': 'sport', 'label': '⚽ Sport', 'color': const Color(0xFFFF0055)},
  ];

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(newsStreamProvider(_selectedCategory));

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1220),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0x335BC8FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.newspaper_rounded, color: Color(0xFF5BC8FA), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Yangiliklar va Xabarlar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Category Selector Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1220),
              border: Border(bottom: BorderSide(color: Color(0x15FFFFFF))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['id'];
                  final Color catColor = cat['color'] as Color;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat['id'] as String);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? catColor : const Color(0xFF131929),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? catColor : const Color(0x22FFFFFF),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: catColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cat['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // News List
          Expanded(
            child: newsAsync.when(
              data: (articles) {
                if (articles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.feed_outlined, color: Colors.white24, size: 48),
                        const SizedBox(height: 10),
                        Text('news.empty_category'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: articles.length,
                  itemBuilder: (context, index) {
                    final item = articles[index];
                    return _NewsCard(item: item);
                  },
                );
              },
              loading: () => const Center(child: FlowaLoading()),
              error: (err, _) => Center(child: Text('Xatolik: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final NewsItem item;

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    return '${diff.inDays} kun oldin';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showNewsDetailModal(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1220),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x22FFFFFF)),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF182238),
                      child: const Center(
                        child: Icon(Icons.image_not_supported_rounded, color: Colors.white24, size: 36),
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source Badge & Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x225BC8FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x445BC8FA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item.sourceEmoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              item.source,
                              style: const TextStyle(color: Color(0xFF5BC8FA), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTimeAgo(item.publishedAt),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Description snippet
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8B9BB4),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewsDetailModal(BuildContext context, NewsItem item) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF5BC8FA), width: 1.5)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              if (item.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    item.imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x335BC8FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${item.sourceEmoji} ${item.source}', style: const TextStyle(color: Color(0xFF5BC8FA), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  Text(_formatTimeAgo(item.publishedAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.3),
              ),
              const SizedBox(height: 10),
              Text(
                item.description,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final targetUrl = (item.url != null && item.url!.isNotEmpty)
                        ? item.url!
                        : (item.source.toLowerCase().contains('daryo')
                            ? 'https://daryo.uz'
                            : (item.source.toLowerCase().contains('qalampir')
                                ? 'https://qalampir.uz'
                                : 'https://kun.uz'));
                    try {
                      launchUrl(Uri.parse(targetUrl), mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5BC8FA),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: Text('news.read_full'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
