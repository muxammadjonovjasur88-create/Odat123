import 'package:cloud_firestore/cloud_firestore.dart';

class BookProgress {
  final String bookId;
  final int lastPageRead;
  final int totalPages;
  final String status; // 'reading', 'completed'
  final DateTime? lastReadAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const BookProgress({
    required this.bookId,
    this.lastPageRead = 1,
    this.totalPages = 1,
    this.status = 'reading',
    this.lastReadAt,
    this.startedAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed' || lastPageRead >= totalPages;

  double get progressPercentage {
    if (totalPages <= 0) return 0.0;
    return (lastPageRead / totalPages).clamp(0.0, 1.0);
  }

  factory BookProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BookProgress(
      bookId: doc.id,
      lastPageRead: (data['lastPageRead'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      status: data['status'] as String? ?? 'reading',
      lastReadAt: (data['lastReadAt'] as Timestamp?)?.toDate(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}
