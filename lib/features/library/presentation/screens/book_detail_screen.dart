import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/library_provider.dart';
import 'pdf_reader_screen.dart';
import 'quiz_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksStreamProvider);
    final progressAsync = ref.watch(userBookProgressStreamProvider(bookId));

    return Scaffold(
      backgroundColor: AppColors.dark.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Kitob ma\'lumotlari', style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: booksAsync.when(
        data: (books) {
          final bookList = books.where((b) => b.id == bookId).toList();
          if (bookList.isEmpty) {
            return const Center(
              child: Text('Kitob topilmadi', style: TextStyle(color: Colors.white)),
            );
          }
          final book = bookList.first;
          final progress = progressAsync.asData?.value;

          final int lastPage = progress?.lastPageRead ?? 1;
          final int totalPages = progress?.totalPages ?? book.totalPages;
          final bool isCompleted = progress?.isCompleted ?? false;
          final bool isStarted = progress != null && progress.lastPageRead > 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image Hero
                Center(
                  child: Container(
                    width: 170,
                    height: 240,
                    decoration: BoxDecoration(
                      color: AppColors.dark.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.dark.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyanAccent.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: book.coverImageUrl.isNotEmpty
                          ? Image.network(
                              book.coverImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.book_rounded, color: AppColors.cyanAccent, size: 64),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.book_rounded, color: AppColors.cyanAccent, size: 64),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title & Author
                Center(
                  child: Column(
                    children: [
                      Text(
                        book.title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h1.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.author.isNotEmpty ? book.author : 'Noma\'lum muallif',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.dark.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Badges Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.dark.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dark.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.category_rounded, color: AppColors.cyanAccent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            book.category,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Points Reward Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.military_tech_rounded, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '+${book.pointsReward} ball',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Progress Banner (If Reading or Completed)
                if (isStarted || isCompleted) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.dark.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : AppColors.cyanAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isCompleted ? '🎉 O\'qib tugatilgan!' : 'O\'qish jarayoni',
                              style: TextStyle(
                                color: isCompleted ? const Color(0xFF34D399) : AppColors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$lastPage / $totalPages bet',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (lastPage / (totalPages > 0 ? totalPages : 1)).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppColors.dark.surfaceMuted,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted ? const Color(0xFF34D399) : AppColors.cyanAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Description
                Text(
                  'Tavsif',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.description.isNotEmpty
                      ? book.description
                      : 'Ushbu kitob uchun hali batafsil tavsif kiritilmagan.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.dark.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                if (isCompleted) ...[
                  // Take Quiz Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(book: book),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.quiz_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Test topshirish (+${book.pointsReward} ball)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Re-read Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PdfReaderScreen(book: book, initialPage: 1),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: AppColors.dark.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Qayta o\'qish (1-sahifa)'),
                    ),
                  ),
                ] else ...[
                  // Primary Action Button (Start or Resume)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyanAccent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PdfReaderScreen(
                                book: book,
                                initialPage: isStarted ? lastPage : 1,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isStarted ? Icons.play_arrow_rounded : Icons.auto_stories_rounded,
                              color: Colors.black,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isStarted
                                  ? 'Davom ettirish ($lastPage-sahifa)'
                                  : 'O\'qishni boshlash',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Option to take quiz directly if user wants
                  if (book.hasQuiz) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QuizScreen(book: book),
                            ),
                          );
                        },
                        icon: const Icon(Icons.quiz_outlined, size: 18, color: AppColors.cyanAccent),
                        label: Text(
                          'Sinov testini hozir topshirish',
                          style: TextStyle(color: AppColors.cyanAccent, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.cyanAccent),
        ),
        error: (err, stack) => Center(
          child: Text('Xatolik: $err', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
