import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/library_repository.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_progress.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

/// Stream provider for all active books in the library
final booksStreamProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchBooks();
});

/// Stream provider for all book progress of the current user
final allUserBookProgressStreamProvider =
    StreamProvider<Map<String, BookProgress>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchAllUserBookProgress();
});

/// Family Stream provider for user's progress on a single book
final userBookProgressStreamProvider =
    StreamProvider.family<BookProgress?, String>((ref, bookId) {
  return ref.watch(libraryRepositoryProvider).watchUserBookProgress(bookId);
});
