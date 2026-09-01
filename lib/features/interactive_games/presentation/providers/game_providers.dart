import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/game_repository.dart';
import '../../domain/game_models.dart';

final availableGamesProvider = Provider<List<LearningGame>>((ref) {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getAvailableGames();
});

final dailyBrainChallengeProvider = Provider<DailyBrainChallenge>((ref) {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getTodayChallenge();
});

final skillProfileProvider = Provider<SkillProfile>((ref) {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getSkillProfile();
});

final activeGameQuestionsProvider = Provider.family<List<GameQuestion>, ({String gameId, GameCategory category})>((ref, args) {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.loadGameQuestions(args.gameId, args.category, count: 10);
});
