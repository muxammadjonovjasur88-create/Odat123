import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/avatar_circle.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_progress.dart';
import '../providers/library_provider.dart';
import 'book_detail_screen.dart';
import 'interactive_course_screen.dart';
import '../widgets/voice_club_view.dart';
import '../providers/voice_club_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  // Top Tabs: 0 -> Kutubxona, 1 -> Interaktiv Kurslar, 2 -> Kitobxonlar Suhbati (Voice Club)
  int _activeTopTab = 0;

  String _selectedCategory = 'Barchasi';
  final TextEditingController _customCourseController = TextEditingController();

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
  void dispose() {
    _customCourseController.dispose();
    ref.read(voiceClubProvider.notifier).leaveRoom();
    super.dispose();
  }

  Future<void> _pickAndUploadPdfForCourse() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String bookName = file.name.replaceAll('.pdf', '').replaceAll('_', ' ').replaceAll('-', ' ');
      if (bookName.isEmpty) bookName = 'Mening Kitobim';

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF4AADDC),
          content: Text(
            '📄 "$bookName" yuklandi! AI darslar va testlarni tayyorlamoqda...',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      final customBook = Book(
        id: 'uploaded_${file.name.hashCode.abs()}',
        title: bookName,
        author: 'Yuklangan Kitob',
        category: 'Interaktiv Kurs',
        description: '"$bookName" kitobi bo‘yicha AI tomonidan tuzilgan amaliy ta‘lim kursi va mustahkamlash testlari.',
        coverImageUrl: '',
        pdfUrl: file.path ?? '',
        totalPages: 50,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InteractiveCourseScreen(book: customBook),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('Fayl yuklashda xatolik: $e')),
        );
      }
    }
  }

  void _startCustomCourse(String topicOrBook) {
    if (topicOrBook.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    final customBook = Book(
      id: 'custom_${topicOrBook.trim().hashCode}',
      title: topicOrBook.trim(),
      author: 'AI Ilmiy Murabbiy',
      category: 'Interaktiv Kurs',
      description: '"${topicOrBook.trim()}" bo‘yicha to‘liq AI interaktiv ta‘lim kursi, hayotiy amaliyotlar va testlar.',
      coverImageUrl: '',
      pdfUrl: '',
      totalPages: 100,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveCourseScreen(book: customBook),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksStreamProvider);
    final allProgressAsync = ref.watch(allUserBookProgressStreamProvider);
    final allProgress = allProgressAsync.asData?.value ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _activeTopTab == 0
                  ? Icons.auto_stories_rounded
                  : (_activeTopTab == 1 ? Icons.school_rounded : Icons.headphones_rounded),
              color: const Color(0xFF4AADDC),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              _activeTopTab == 0
                  ? 'KUTUBXONA'
                  : (_activeTopTab == 1 ? 'INTERAKTIV KURSLAR' : 'OVOZLI KLUB'),
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Top 3-Tab Switcher ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF090B18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                _buildTopTabItem(0, Icons.menu_book_rounded, 'Kitoblar', const Color(0xFF6B25CC)),
                _buildTopTabItem(1, Icons.school_rounded, 'Kurslar', const Color(0xFF4AADDC)),
                _buildTopTabItem(2, Icons.record_voice_over_rounded, 'Ovozli Klub', const Color(0xFF3A7FCC)),
              ],
            ),
          ),

          // ── Active View Body ──
          Expanded(
            child: _activeTopTab == 0
                ? _buildLibraryBooksView(booksAsync, allProgress)
                : (_activeTopTab == 1
                    ? _buildInteractiveCoursesView(booksAsync)
                    : VoiceClubView(onLeave: () => setState(() => _activeTopTab = 0))),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabItem(int index, IconData icon, String title, Color activeColor) {
    final isSelected = _activeTopTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (_activeTopTab == 2 && index != 2) {
            ref.read(voiceClubProvider.notifier).leaveRoom();
          }
          setState(() => _activeTopTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? (activeColor == const Color(0xFF4AADDC) || activeColor == const Color(0xFF3A7FCC) ? Colors.black : Colors.white) : Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? (activeColor == const Color(0xFF4AADDC) || activeColor == const Color(0xFF3A7FCC) ? Colors.black : Colors.white) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW 1: KUTUBXONA (BOOKS CATALOG)
  // =========================================================================
  Widget _buildLibraryBooksView(
    AsyncValue<List<Book>> booksAsync,
    Map<String, BookProgress> allProgress,
  ) {
    return Column(
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
                    color: isSelected ? const Color(0xFF6B25CC) : const Color(0xFF090B18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6B25CC) : Colors.white12,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: booksAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B25CC)),
            ),
            error: (err, stack) => Center(
              child: Text(
                'Kitoblarni yuklashda xatolik: $err',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            data: (books) {
              List<Book> filteredBooks = books;

              if (_selectedCategory == 'O\'qilmoqda') {
                filteredBooks = books.where((b) {
                  final p = allProgress[b.id];
                  return p != null && p.lastPageRead > 1 && !p.isCompleted;
                }).toList();
              } else if (_selectedCategory != 'Barchasi') {
                filteredBooks = books.where((b) => b.category == _selectedCategory).toList();
              }

              if (filteredBooks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book_outlined, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(
                        'Bu kategoriyada kitoblar topilmadi',
                        style: AppTextStyles.body.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = filteredBooks[index];
                  final progress = allProgress[book.id];
                  return _buildBookCard(book, progress);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // VIEW 2: INTERAKTIV KURSLAR (CUSTOM & BOOK COURSES)
  // =========================================================================
  Widget _buildInteractiveCoursesView(AsyncValue<List<Book>> booksAsync) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Custom Topic Course Generator Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF003B46), Color(0xFF071B26)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF4AADDC), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4AADDC).withValues(alpha: 0.2),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF6B25CC), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Interaktiv Kurs Generatori',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'O‘zingiz xohlagan istalgan kitob yoki mavzu nomini kiriting. AI darhol sizga 3 ta to‘liq dars, hayotiy amaliy mashqlar va testlarni yaratib beradi!',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1422),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x664AADDC)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _customCourseController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Kitob yoki mavzu (masalan: Atom Odatlar, Psixologiya...)',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF4AADDC)),
                      onPressed: () => _startCustomCourse(_customCourseController.text),
                    ),
                  ),
                  onSubmitted: _startCustomCourse,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _startCustomCourse(_customCourseController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4AADDC),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: const Text(
                          'YARATISH ✨',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _pickAndUploadPdfForCourse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B283F),
                          foregroundColor: const Color(0xFF3A7FCC),
                          side: const BorderSide(color: Color(0xFF3A7FCC), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF3A7FCC)),
                        label: const Text(
                          'PDF YUKLASH 📥',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Row(
          children: [
            Text('📚', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Kutubxonadagi Tayyor Kurslar',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),

        booksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4AADDC))),
          error: (e, _) => Center(child: Text('Xatolik: $e', style: const TextStyle(color: Colors.red))),
          data: (books) {
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: books.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final b = books[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090B18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4AADDC).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school_rounded, color: Color(0xFF4AADDC)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${b.author} • 3 ta dars + Amaliyot + Imtihon',
                              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InteractiveCourseScreen(book: b),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4AADDC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Boshlash 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBookCard(Book book, BookProgress? progress) {
    final double percent = progress?.progressPercentage ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookDetailScreen(bookId: book.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF090B18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (book.coverImageUrl.isNotEmpty)
                    Image.network(
                      book.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderCover(book),
                    )
                  else
                    _buildPlaceholderCover(book),
                  if (percent > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.black45,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3A7FCC)),
                        minHeight: 4,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover(Book book) {
    return Container(
      color: const Color(0xFF1C273D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 36, color: Color(0xFF6B25CC)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                book.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
