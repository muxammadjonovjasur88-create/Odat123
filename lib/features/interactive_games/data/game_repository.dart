import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/game_models.dart';
import 'game_generators.dart';

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository();
});

class GameRepository {
  /// Get all available game categories and sub-games.
  List<LearningGame> getAvailableGames() {
    return const [
      LearningGame(
        id: 'math_sprint',
        category: GameCategory.math,
        titleKey: 'play.game_mental_math',
        descriptionKey: 'play.game_mental_math_desc',
        iconName: 'calculate_rounded',
        level: 9,
      ),
      LearningGame(
        id: 'math_percent',
        category: GameCategory.math,
        titleKey: 'play.game_percent',
        descriptionKey: 'play.game_percent_desc',
        iconName: 'percent_rounded',
        level: 8,
      ),
      LearningGame(
        id: 'math_algebra',
        category: GameCategory.math,
        titleKey: 'play.game_algebra',
        descriptionKey: 'play.game_algebra_desc',
        iconName: 'functions_rounded',
        level: 11,
      ),
      LearningGame(
        id: 'logic_sequence',
        category: GameCategory.logic,
        titleKey: 'play.game_sequence',
        descriptionKey: 'play.game_sequence_desc',
        iconName: 'linear_scale_rounded',
        level: 12,
      ),
      LearningGame(
        id: 'logic_odd_one',
        category: GameCategory.logic,
        titleKey: 'play.game_odd_one',
        descriptionKey: 'play.game_odd_one_desc',
        iconName: 'category_rounded',
        level: 10,
      ),
      LearningGame(
        id: 'lang_vocab_match',
        category: GameCategory.language,
        titleKey: 'play.game_word_match',
        descriptionKey: 'play.game_word_match_desc',
        iconName: 'translate_rounded',
        level: 15,
      ),
      LearningGame(
        id: 'mem_sequence_recall',
        category: GameCategory.memory,
        titleKey: 'play.game_sequence_recall',
        descriptionKey: 'play.game_sequence_recall_desc',
        iconName: 'psychology_rounded',
        level: 7,
      ),
    ];
  }

  /// Get daily brain challenge.
  DailyBrainChallenge getTodayChallenge() {
    return const DailyBrainChallenge(
      dateStr: '2026-08-27',
      totalPuzzles: 14,
      completedPuzzles: 8,
      isClaimed: false,
    );
  }

  /// Get skill profile.
  SkillProfile getSkillProfile() {
    return SkillProfile.initial();
  }

  /// Generate question set for active session.
  List<GameQuestion> loadGameQuestions(String gameId, GameCategory category, {int count = 10}) {
    return GameGenerators.generateQuestions(gameId, category, count: count);
  }
}
