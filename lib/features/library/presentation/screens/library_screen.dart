import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_progress.dart';
import '../providers/library_provider.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _selectedCategory = 'Barchasi';

  final List<String> _categories = [
    'Barchasi',
    'O\'qilmoqda',
    'Shaxsiy rivojlanish',
    'Badiiy',
    'Ilmiy',
    'Biznes',
    'Motivatsion',
    'Psixologiya',
    'Diniy-ma\'rifiy',
    'Texnologiya',
  ];

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksStreamProvider);
    final allProgressAsync = ref.watch(allUserBookProgressStreamProvider);

    final allProgress = allProgressAsync.asData?.value ?? {};

    return Scaffold(
      backgroundColor: AppColors.dark.background,
      appBar: AppBar(
        backgroundColor: AppColors.dark.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Kutubxona',
          style: AppTextStyles.h2.copyWith(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Filter Chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.cyanAccent
                          : AppColors.dark.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.cyanAccent
                            : AppColors.dark.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Books Grid
          Expanded(
            child: booksAsync.when(
              data: (books) {
                final filteredBooks = books.where((book) {
                  if (_selectedCategory == 'Barchasi') return true;
                  if (_selectedCategory == 'O\'qilmoqda') {
                    final prog = allProgress[book.id];
                    return prog != null && prog.lastPageRead > 0;
                  }
                  return book.category == _selectedCategory;
                }).toList();

                if (filteredBooks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 56,
                          color: AppColors.dark.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Hali kitoblar topilmadi',
                          style: AppTextStyles.h3.copyWith(color: AppColors.dark.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Boshqa kategoriyani tanlab ko\'ring',
                          style: AppTextStyles.caption.copyWith(color: AppColors.dark.textTertiary),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredBooks.length,
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    final progress = allProgress[book.id];
                    return _BookCard(
                      book: book,
                      progress: progress,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BookDetailScreen(bookId: book.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.cyanAccent),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFB7185), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Kitoblarni yuklashda xatolik yuz berdi',
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(booksStreamProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cyanAccent,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Qayta urinish'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final BookProgress? progress;
  final VoidCallback onTap;

  const _BookCard({
    required this.book,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double pct = progress?.progressPercentage ?? 0.0;
    final bool isReading = progress != null && progress!.lastPageRead > 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.dark.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.dark.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: const Color(0xFF1F2638),
                      child: book.coverImageUrl.isNotEmpty
                          ? Image.network(
                              book.coverImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.book_rounded, color: AppColors.cyanAccent, size: 40),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.book_rounded, color: AppColors.cyanAccent, size: 40),
                            ),
                    ),
                    // Points reward badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.military_tech_rounded, color: Colors.amberAccent, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '+${book.pointsReward}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Quiz status badge
                    if (book.hasQuiz)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Test bor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Book Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author.isNotEmpty ? book.author : 'Noma\'lum muallif',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.dark.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar if started
                  if (isReading) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${progress!.lastPageRead}/${progress!.totalPages} bet',
                          style: TextStyle(
                            color: AppColors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(pct * 100).toInt()}%',
                          style: TextStyle(
                            color: AppColors.dark.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: AppColors.dark.surfaceMuted,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.dark.surfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book.category,
                        style: TextStyle(
                          color: AppColors.dark.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
