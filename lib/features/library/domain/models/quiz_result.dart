class QuizResult {
  final int score;
  final int totalQuestions;
  final int pointsEarned;
  final bool alreadySubmitted;

  const QuizResult({
    required this.score,
    required this.totalQuestions,
    required this.pointsEarned,
    this.alreadySubmitted = false,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      alreadySubmitted: json['alreadySubmitted'] as bool? ?? false,
    );
  }
}
