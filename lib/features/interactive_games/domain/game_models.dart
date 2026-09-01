import 'package:flutter/foundation.dart';

/// Categories of learning games.
enum GameCategory {
  logic,
  math,
  language,
  memory,
}

/// Metadata for an interactive game.
@immutable
class LearningGame {
  const LearningGame({
    required this.id,
    required this.category,
    required this.titleKey,
    required this.descriptionKey,
    required this.iconName,
    required this.level,
    this.isOfflineSupported = true,
  });

  final String id;
  final GameCategory category;
  final String titleKey;
  final String descriptionKey;
  final String iconName;
  final int level;
  final bool isOfflineSupported;
}

/// A single interactive question or puzzle.
@immutable
class GameQuestion {
  const GameQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.topic = 'General',
    this.hint,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String topic;
  final String? hint;
}

/// User's attempt on a specific question.
@immutable
class QuestionAttempt {
  const QuestionAttempt({
    required this.questionId,
    required this.selectedOptionIndex,
    required this.isCorrect,
    required this.responseTimeMs,
  });

  final String questionId;
  final int selectedOptionIndex;
  final bool isCorrect;
  final int responseTimeMs;
}

/// Result of an active game session.
@immutable
class GameResult {
  const GameResult({
    required this.gameId,
    required this.category,
    required this.totalQuestions,
    required this.correctCount,
    required this.durationSeconds,
    required this.score,
    required this.earnedXp,
    required this.earnedCoins,
    required this.accuracyPercent,
    required this.isNewBest,
  });

  final String gameId;
  final GameCategory category;
  final int totalQuestions;
  final int correctCount;
  final int durationSeconds;
  final int score;
  final int earnedXp;
  final int earnedCoins;
  final int accuracyPercent;
  final bool isNewBest;
}

/// Multi-dimensional skill profile (Learning Performance Index).
@immutable
class SkillProfile {
  const SkillProfile({
    required this.logicScore,
    required this.mathScore,
    required this.languageScore,
    required this.memoryScore,
    required this.learningStreak,
    required this.totalGamesPlayed,
  });

  final int logicScore;
  final int mathScore;
  final int languageScore;
  final int memoryScore;
  final int learningStreak;
  final int totalGamesPlayed;

  factory SkillProfile.initial() => const SkillProfile(
        logicScore: 72,
        mathScore: 81,
        languageScore: 67,
        memoryScore: 75,
        learningStreak: 7,
        totalGamesPlayed: 34,
      );
}

/// Daily Brain Challenge progress.
@immutable
class DailyBrainChallenge {
  const DailyBrainChallenge({
    required this.dateStr,
    required this.totalPuzzles,
    required this.completedPuzzles,
    required this.isClaimed,
  });

  final String dateStr;
  final int totalPuzzles; // e.g. 14
  final int completedPuzzles; // e.g. 8
  final bool isClaimed;

  bool get isFinished => completedPuzzles >= totalPuzzles;
  double get progressRatio => totalPuzzles > 0 ? (completedPuzzles / totalPuzzles).clamp(0.0, 1.0) : 0.0;
}
