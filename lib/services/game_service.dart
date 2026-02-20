import 'dart:math';
import '../models/game_models.dart';
import 'word_pool_service.dart';

class GameService {
  static Future<List<Player>> createPlayersFromWordPool(
    int playerCount,
    int undercoverCount,
  ) async {
    if (playerCount <= 0) {
      throw ArgumentError('playerCount 必须大于 0');
    }
    if (undercoverCount <= 0 || undercoverCount >= playerCount) {
      throw ArgumentError('undercoverCount 必须在 1 到 playerCount-1 之间');
    }

    final wordPair = await WordPoolService.getRandomPair();

    final players = List.generate(playerCount, (index) {
      return Player(
        id: index,
        name: '玩家${index + 1}',
        role: GameRole.civilian,
        word: wordPair.civilian,
      );
    });

    final random = Random();
    final undercoverIndices = <int>{};
    while (undercoverIndices.length < undercoverCount) {
      undercoverIndices.add(random.nextInt(playerCount));
    }

    for (final index in undercoverIndices) {
      players[index] = Player(
        id: players[index].id,
        name: players[index].name,
        role: GameRole.undercover,
        word: wordPair.undercover,
        isAlive: true,
      );
    }

    return players;
  }
}