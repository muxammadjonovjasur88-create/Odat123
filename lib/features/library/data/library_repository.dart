import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/models/book.dart';
import '../domain/models/book_progress.dart';
import '../domain/models/quiz_question.dart';
import '../domain/models/quiz_result.dart';

class LibraryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;
  final FirebaseAuth? _auth;

  LibraryRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions,
        _auth = auth;

  FirebaseFunctions get _functionsInstance => _functions ?? FirebaseFunctions.instance;

  String? get currentUserId {
    try {
      return (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Stream of all active books from Firestore
  Stream<List<Book>> watchBooks() {
    return _firestore
        .collection('books')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Book.fromFirestore(doc))
          .where((book) => book.isActive)
          .toList();
    });
  }

  /// Stream of user's progress for a single book
  Stream<BookProgress?> watchUserBookProgress(String bookId) {
    final uid = currentUserId;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('bookProgress')
        .doc(bookId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return BookProgress.fromFirestore(doc);
    });
  }

  /// Stream of all user's book progress items
  Stream<Map<String, BookProgress>> watchAllUserBookProgress() {
    final uid = currentUserId;
    if (uid == null) return Stream.value({});

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('bookProgress')
        .snapshots()
        .map((snapshot) {
      final map = <String, BookProgress>{};
      for (final doc in snapshot.docs) {
        map[doc.id] = BookProgress.fromFirestore(doc);
      }
      return map;
    });
  }

  /// Update reading progress in Firestore & Cloud Functions
  Future<void> updateProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    // Direct Firestore update for instant responsiveness & offline support
    final progressRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('bookProgress')
        .doc(bookId);

    final docSnap = await progressRef.get();
    final isCompleted = currentPage >= totalPages;

    final updates = <String, dynamic>{
      'lastPageRead': currentPage,
      'totalPages': totalPages,
      'status': isCompleted ? 'completed' : 'reading',
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!docSnap.exists) {
      updates['startedAt'] = FieldValue.serverTimestamp();
    }
    if (isCompleted && (!docSnap.exists || docSnap.data()?['status'] != 'completed')) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }

    await progressRef.set(updates, SetOptions(merge: true));

    // Try calling cloud function in background for server-side verification
    try {
      final callable = _functionsInstance.httpsCallable('updateBookProgress');
      await callable.call<Map<String, dynamic>>({
        'bookId': bookId,
        'currentPage': currentPage,
      });
    } catch (_) {
      // Ignore if offline or call fails, local Firestore update is already done
    }
  }

  /// Generate or fetch quiz for a book using Cloud Function (Gemini AI)
  Future<List<QuizQuestion>> generateBookQuiz(String bookId) async {
    // Check if quiz already exists in Firestore first
    final quizSnap = await _firestore.collection('bookQuizzes').doc(bookId).get();
    if (quizSnap.exists) {
      final data = quizSnap.data();
      if (data != null && data['questions'] is List) {
        final rawQuestions = data['questions'] as List<dynamic>;
        return rawQuestions
            .map((q) => QuizQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
            .toList();
      }
    }

    // Call Cloud Function to generate quiz via Gemini API
    final callable = _functionsInstance.httpsCallable('generateBookQuiz');
    final result = await callable.call<Map<String, dynamic>>({'bookId': bookId});
    final resData = result.data;

    final quizData = resData['quiz'] as Map<String, dynamic>? ?? {};
    final questionsRaw = quizData['questions'] as List<dynamic>? ?? [];

    return questionsRaw
        .map((q) => QuizQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
        .toList();
  }

  /// Submit user answers for a book quiz
  Future<QuizResult> submitBookQuiz({
    required String bookId,
    required List<int> answers,
  }) async {
    final callable = _functionsInstance.httpsCallable('submitBookQuiz');
    final result = await callable.call<Map<String, dynamic>>({
      'bookId': bookId,
      'answers': answers,
    });

    final resData = result.data;
    return QuizResult.fromJson(Map<String, dynamic>.from(resData));
  }
}
