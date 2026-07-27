import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `proofSessions/{sessionId}` hujjatini ifodalaydi.
///
/// Statuslar:
///   pending   – yaratilgan, vaqt hali kelmagan
///   notified  – push yuborilgan, 2 daq ichida javob kutiladi
///   completed – foydalanuvchi rasm yubordi
///   missed    – muddati o'tib ketdi
enum ProofStatus { pending, notified, completed, missed }

class ProofSession {
  const ProofSession({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.status,
    required this.scheduledTime,
    required this.createdAt,
    this.rearPhotoUrl,
    this.frontPhotoUrl,
    this.completedAt,
    this.notifiedAt,
    this.taskTitle,
    this.expiresAt,
    this.moodResponse,
  });

  final String id;
  final String taskId;
  final String userId;
  final ProofStatus status;
  final DateTime scheduledTime;
  final DateTime createdAt;
  final String? rearPhotoUrl;
  final String? frontPhotoUrl;
  final DateTime? completedAt;
  final DateTime? notifiedAt;
  final DateTime? expiresAt;
  final String? moodResponse;

  /// Task nomi — Cloud Function tomonidan saqlangan bo'lishi mumkin,
  /// yoki ilova UI da taskId orqali olinadi.
  final String? taskTitle;

  bool get isCompleted => status == ProofStatus.completed;
  bool get isMissed => status == ProofStatus.missed;
  bool get isPending => status == ProofStatus.pending;
  bool get isNotified => status == ProofStatus.notified;

  /// Ikkala foto ham mavjud bo'lsa true.
  bool get hasPhotos => rearPhotoUrl != null && frontPhotoUrl != null;

  factory ProofSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ProofSession(
      id: doc.id,
      taskId: (data['taskId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      status: _parseStatus(data['status'] as String?),
      scheduledTime:
          (data['scheduledTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rearPhotoUrl: data['rearPhotoUrl'] as String?,
      frontPhotoUrl: data['frontPhotoUrl'] as String?,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      notifiedAt: (data['notifiedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      taskTitle: data['taskTitle'] as String?,
      moodResponse: data['moodResponse'] as String?,
    );
  }

  static ProofStatus _parseStatus(String? raw) => switch (raw) {
        'completed' => ProofStatus.completed,
        'missed' => ProofStatus.missed,
        'notified' => ProofStatus.notified,
        _ => ProofStatus.pending,
      };
}
