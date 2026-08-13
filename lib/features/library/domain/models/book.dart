import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String category;
  final int pointsReward;
  final int totalPages;
  final String coverImageUrl;
  final String pdfUrl;
  final bool isActive;
  final bool hasQuiz;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Book({
    required this.id,
    required this.title,
    this.author = '',
    this.description = '',
    this.category = 'Shaxsiy rivojlanish',
    this.pointsReward = 100,
    this.totalPages = 1,
    this.coverImageUrl = '',
    this.pdfUrl = '',
    this.isActive = true,
    this.hasQuiz = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Book.fromFirestore(DocumentSnapshot doc, {bool hasQuizOverride = false}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Book(
      id: doc.id,
      title: data['title'] as String? ?? 'Noma\'lum kitob',
      author: data['author'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'Shaxsiy rivojlanish',
      pointsReward: (data['pointsReward'] as num?)?.toInt() ?? 100,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      coverImageUrl: data['coverImageUrl'] as String? ?? '',
      pdfUrl: data['pdfUrl'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      hasQuiz: (data['hasQuiz'] as bool?) ?? hasQuizOverride,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'description': description,
      'category': category,
      'pointsReward': pointsReward,
      'totalPages': totalPages,
      'coverImageUrl': coverImageUrl,
      'pdfUrl': pdfUrl,
      'isActive': isActive,
      'hasQuiz': hasQuiz,
    };
  }
}
