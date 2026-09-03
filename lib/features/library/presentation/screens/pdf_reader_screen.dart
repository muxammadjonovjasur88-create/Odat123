import 'dart:async';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/book.dart';
import '../providers/library_provider.dart';
import 'quiz_screen.dart';

class PdfReaderScreen extends ConsumerStatefulWidget {
  final Book book;
  final int initialPage;

  const PdfReaderScreen({
    super.key,
    required this.book,
    this.initialPage = 1,
  });

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  Timer? _debounceTimer;
  bool _isCompletedDialogShown = false;
  int _downloadProgress = 0; // 0–100, only used during download

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _initPdf();
  }

  Future<void> _initPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = 0;
    });

    try {
      if (widget.book.pdfUrl.isEmpty) {
        throw Exception("Kitob uchun PDF manzili (pdfUrl) ko'rsatilgan emas.");
      }

      File pdfFile;
      if (widget.book.pdfUrl.startsWith("http://") || widget.book.pdfUrl.startsWith("https://")) {
        pdfFile = await _downloadAndCachePdf(widget.book.pdfUrl, widget.book.id);
      } else if (widget.book.pdfUrl.startsWith("data:application/pdf;base64,")) {
        throw Exception("Base64 fayl formati qo'llab-quvvatlanmaydi, iltimos URL kiriting.");
      } else {
        pdfFile = File(widget.book.pdfUrl);
      }

      if (!await pdfFile.exists()) {
        throw Exception("PDF fayl qurilmada topilmadi.");
      }

      final doc = await PdfDocument.openFile(pdfFile.path);
      _totalPages = doc.pagesCount;

      final startPage = widget.initialPage.clamp(1, _totalPages);

      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(pdfFile.path),
        initialPage: startPage,
      );

      setState(() {
        _currentPage = startPage;
        _isLoading = false;
      });

      // Save initial open progress
      _saveProgressDebounced(startPage);
    } catch (err) {
      setState(() {
        _isLoading = false;
        _errorMessage = err.toString().replaceAll("Exception: ", "");
      });
    }
  }

  /// Returns the permanent storage file for a book (documents/books/book_<id>.pdf).
  Future<File> _getPermanentFile(String bookId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${docsDir.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return File('${booksDir.path}/book_$bookId.pdf');
  }

  /// Downloads the PDF to the permanent books/ directory with streaming progress.
  /// If the file already exists and is valid (>10KB), returns it immediately.
  Future<File> _downloadAndCachePdf(String url, String bookId) async {
    final file = await _getPermanentFile(bookId);

    // Return cached file if already downloaded and valid
    if (await file.exists()) {
      final size = await file.length();
      if (size > 10240) {
        return file;
      }
    }

    // Stream download with progress tracking
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception("PDF yuklashda xatolik yuz berdi (HTTP ${response.statusCode})");
    }

    final contentLength = response.contentLength ?? 0;
    int bytesReceived = 0;
    final sink = file.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0 && mounted) {
          final pct = (bytesReceived / contentLength * 100).clamp(0, 100).toInt();
          setState(() => _downloadProgress = pct);
        }
      }
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      throw Exception("Yuklab olishda xatolik: $e");
    }

    await sink.flush();
    await sink.close();

    // Final integrity check
    final finalSize = await file.length();
    if (finalSize < 1024) {
      await file.delete();
      throw Exception("Yuklab olingan fayl to'liq emas. Qayta urinib ko'ring.");
    }

    return file;
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });

    _saveProgressDebounced(page);

    // If user reached the last page for the first time
    if (page >= _totalPages && !_isCompletedDialogShown) {
      _isCompletedDialogShown = true;
      _showBookCompletedDialog();
    }
  }

  void _saveProgressDebounced(int page) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      ref.read(libraryRepositoryProvider).updateProgress(
            bookId: widget.book.id,
            currentPage: page,
            totalPages: _totalPages > 0 ? _totalPages : widget.book.totalPages,
          );
    });
  }

  void _flushProgressNow() {
    _debounceTimer?.cancel();
    ref.read(libraryRepositoryProvider).updateProgress(
          bookId: widget.book.id,
          currentPage: _currentPage,
          totalPages: _totalPages > 0 ? _totalPages : widget.book.totalPages,
        );
  }

  void _showBookCompletedDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.dark.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF3A7FCC), Color(0xFF4AADDC)]),
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF090B18), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tabriklaymiz!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'Siz "${widget.book.title}" kitobini to\'liq o\'qib tugatdingiz!\n\nEndi bilimingizni sinab ko\'rish uchun test topshiring va +${widget.book.pointsReward} ball mukofot oling.',
            style: TextStyle(color: AppColors.dark.textSecondary, fontSize: 14, height: 1.4),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common.later'.tr(), style: TextStyle(color: AppColors.dark.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(book: widget.book),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('library.start_quiz'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _flushProgressNow();
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _flushProgressNow();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1420),
        appBar: AppBar(
          backgroundColor: AppColors.dark.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () {
              _flushProgressNow();
              Navigator.of(context).pop();
            },
          ),
          title: Column(
            children: [
              Text(
                widget.book.title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              if (_totalPages > 0)
                Text(
                  '$_currentPage / $_totalPages bet',
                  style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          centerTitle: true,
          actions: [
            if (widget.book.hasQuiz)
              IconButton(
                icon: const Icon(Icons.quiz_outlined, color: Colors.amberAccent, size: 22),
                tooltip: 'Test topshirish',
                onPressed: () {
                  _flushProgressNow();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(book: widget.book),
                    ),
                  );
                },
              ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book_rounded, color: AppColors.cyanAccent, size: 48),
                      const SizedBox(height: 20),
                      Text(
                        _downloadProgress > 0 ? 'Kitob yuklanmoqda...' : 'Kitob ochilmoqda...',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      if (_downloadProgress > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _downloadProgress / 100,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_downloadProgress%',
                          style: const TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ] else
                        const CircularProgressIndicator(color: AppColors.cyanAccent),
                      const SizedBox(height: 8),
                      Text(
                        _downloadProgress > 0 ? 'Birinchi marta yuklab olinmoqda\nKeyingi safar darhol ochiladi ⚡' : '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
                      ),
                    ],
                  ),
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFFB7185), size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _initPdf,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text('common.retry'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cyanAccent,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _pdfController != null
                    ? PdfViewPinch(
                        controller: _pdfController!,
                        onPageChanged: _onPageChanged,
                      )
                    : const SizedBox.shrink(),
      ),
    );
  }
}
