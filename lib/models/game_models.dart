enum GameRole { civilian, undercover } 
// 身份： civilian-平民 undercover-卧底 

class Player {
  final int id; // 玩家编号
  final String name; 
  final GameRole role;
  final String word;
  bool isAlive;

  Player({
    required this.id,
    required this.name,
    required this.role,
    required this.word,
    this.isAlive = true,
  });

  Player copy()
  {
    return Player(id: id, name: name, role: role, word: word, isAlive: isAlive);
  }
}