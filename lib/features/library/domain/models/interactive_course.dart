import 'package:cloud_firestore/cloud_firestore.dart';

class CourseQuestion {
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const CourseQuestion({
    required this.questionText,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  factory CourseQuestion.fromMap(Map<String, dynamic> map) {
    return CourseQuestion(
      questionText: map['questionText'] as String? ?? '',
      options: (map['options'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      correctIndex: (map['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: map['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'questionText': questionText,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };
}

class CourseLesson {
  final String id;
  final int index;
  final String title;
  final String content;
  final String practicalExercise;
  final List<CourseQuestion> quizQuestions;
  final bool isCompleted;

  const CourseLesson({
    required this.id,
    required this.index,
    required this.title,
    required this.content,
    required this.practicalExercise,
    this.quizQuestions = const [],
    this.isCompleted = false,
  });

  factory CourseLesson.fromMap(Map<String, dynamic> map) {
    return CourseLesson(
      id: map['id'] as String? ?? '',
      index: (map['index'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      practicalExercise: map['practicalExercise'] as String? ?? '',
      quizQuestions: (map['quizQuestions'] as List<dynamic>? ?? [])
          .map((q) => CourseQuestion.fromMap(Map<String, dynamic>.from(q as Map)))
          .toList(),
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'index': index,
    'title': title,
    'content': content,
    'practicalExercise': practicalExercise,
    'quizQuestions': quizQuestions.map((q) => q.toMap()).toList(),
    'isCompleted': isCompleted,
  };

  CourseLesson copyWith({bool? isCompleted}) {
    return CourseLesson(
      id: id,
      index: index,
      title: title,
      content: content,
      practicalExercise: practicalExercise,
      quizQuestions: quizQuestions,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class InteractiveCourse {
  final String id;
  final String bookId;
  final String title;
  final String author;
  final String category;
  final int totalLessons;
  final int rewardPoints;
  final List<CourseLesson> lessons;
  final List<CourseQuestion> finalExam;
  final bool isCompleted;
  final int userScore;
  final DateTime? createdAt;

  const InteractiveCourse({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    this.category = 'Shaxsiy rivojlanish',
    this.totalLessons = 0,
    this.rewardPoints = 250,
    this.lessons = const [],
    this.finalExam = const [],
    this.isCompleted = false,
    this.userScore = 0,
    this.createdAt,
  });

  factory InteractiveCourse.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return InteractiveCourse.fromMap(doc.id, data);
  }

  factory InteractiveCourse.fromMap(String id, Map<String, dynamic> data) {
    return InteractiveCourse(
      id: id,
      bookId: data['bookId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      author: data['author'] as String? ?? '',
      category: data['category'] as String? ?? 'Shaxsiy rivojlanish',
      totalLessons: (data['totalLessons'] as num?)?.toInt() ?? 0,
      rewardPoints: (data['rewardPoints'] as num?)?.toInt() ?? 250,
      lessons: (data['lessons'] as List<dynamic>? ?? [])
          .map((l) => CourseLesson.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
      finalExam: (data['finalExam'] as List<dynamic>? ?? [])
          .map((q) => CourseQuestion.fromMap(Map<String, dynamic>.from(q as Map)))
          .toList(),
      isCompleted: data['isCompleted'] as bool? ?? false,
      userScore: (data['userScore'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'bookId': bookId,
    'title': title,
    'author': author,
    'category': category,
    'totalLessons': lessons.length,
    'rewardPoints': rewardPoints,
    'lessons': lessons.map((l) => l.toMap()).toList(),
    'finalExam': finalExam.map((q) => q.toMap()).toList(),
    'isCompleted': isCompleted,
    'userScore': userScore,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };
}
