import 'dart:math';
import '../models/game_models.dart';

class GameService {
  static List<Player> createMockPlayers(int playerCount, int undercoverCount) {
    // 无词库，目前分配固定词对
    const civilianWord = '苹果';
    const undercoverWord = '香蕉';

    // 生成玩家列表
    List<Player> players = List.generate(playerCount, (index) {
      return Player(
        id: index,
        name: '玩家${index + 1}',
        role: GameRole.civilian, // 先默认平民
        word: civilianWord,
      );
    });

    // 随机选择卧底索引
    final random = Random();
    Set<int> undercoverIndices = {};
    while (undercoverIndices.length < undercoverCount) {
      undercoverIndices.add(random.nextInt(playerCount));
    }

    // 设置卧底
    for (int index in undercoverIndices) {
      players[index] = Player(
        id: players[index].id,
        name: players[index].name,
        role: GameRole.undercover,
        word: undercoverWord,
        isAlive: true,
      );
    }

    return players;
  }
}