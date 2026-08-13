import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/library/domain/models/book_progress.dart';
import 'package:flowa/features/library/domain/models/quiz_question.dart';
import 'package:flowa/features/library/domain/models/quiz_result.dart';
import 'package:flowa/features/library/data/library_repository.dart';

void main() {
  group('Library Models Tests', () {
    test('BookProgress calculations work correctly', () {
      const progress = BookProgress(
        bookId: 'book_1',
        lastPageRead: 50,
        totalPages: 200,
        status: 'reading',
      );

      expect(progress.progressPercentage, equals(0.25));
      expect(progress.isCompleted, isFalse);

      const completedProgress = BookProgress(
        bookId: 'book_1',
        lastPageRead: 200,
        totalPages: 200,
        status: 'completed',
      );

      expect(completedProgress.progressPercentage, equals(1.0));
      expect(completedProgress.isCompleted, isTrue);
    });

    test('QuizQuestion & QuizResult parsing works', () {
      final qJson = {
        'question': 'Kim atom odatlar kitobi muallifi?',
        'options': ['Jeyms Klir', 'Stiven Kovi', 'Robin Sharma', 'Bodo Shefer'],
      };

      final question = QuizQuestion.fromJson(qJson);
      expect(question.question, equals('Kim atom odatlar kitobi muallifi?'));
      expect(question.options.length, equals(4));
      expect(question.options.first, equals('Jeyms Klir'));

      final rJson = {
        'score': 8,
        'totalQuestions': 10,
        'pointsEarned': 80,
        'alreadySubmitted': false,
      };

      final result = QuizResult.fromJson(rJson);
      expect(result.score, equals(8));
      expect(result.totalQuestions, equals(10));
      expect(result.pointsEarned, equals(80));
      expect(result.alreadySubmitted, isFalse);
    });
  });

  group('LibraryRepository Firestore Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('watchBooks returns active books from Firestore', () async {
      await fakeFirestore.collection('books').doc('book_1').set({
        'title': 'Atom Odatlar',
        'author': 'Jeyms Klir',
        'category': 'Shaxsiy rivojlanish',
        'pointsReward': 100,
        'totalPages': 250,
        'isActive': true,
        'hasQuiz': true,
      });

      await fakeFirestore.collection('books').doc('book_2').set({
        'title': 'Noaktiv Kitob',
        'author': 'Noma\'lum',
        'isActive': false,
      });

      final repo = LibraryRepository(firestore: fakeFirestore);
      final booksStream = repo.watchBooks();

      final books = await booksStream.first;
      expect(books.length, equals(1));
      expect(books.first.id, equals('book_1'));
      expect(books.first.title, equals('Atom Odatlar'));
      expect(books.first.hasQuiz, isTrue);
    });
  });
}
