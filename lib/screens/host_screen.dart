import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../services/game_service.dart';

class HostScreen extends StatefulWidget {
  final int playerCount;
  final int undercoverCount;

  const HostScreen({
    Key? key,
    required this.playerCount,
    required this.undercoverCount,
  }) : super(key: key);

  @override
  _HostScreenState createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late List<Player> players;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // 使用假数据初始化
    players = GameService.createMockPlayers(
      widget.playerCount,
      widget.undercoverCount,
    );
  }

  void _nextPlayer() {
    setState(() {
      // 寻找下一个存活的玩家
      int nextIndex = currentIndex;
      do {
        nextIndex = (nextIndex + 1) % players.length;
      } while (!players[nextIndex].isAlive && nextIndex != currentIndex);
      currentIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = players[currentIndex];
    final aliveCount = players.where((p) => p.isAlive).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('游戏进行中'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '存活人数: $aliveCount / ${players.length}',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              '当前玩家: ${player.name}',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 40),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                player.word,
                style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: player.role == GameRole.undercover
                    ? Colors.red[100]
                    : Colors.green[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                player.role == GameRole.undercover ? '卧底' : '平民',
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 60),
            ElevatedButton(
              onPressed: _nextPlayer,
              child: Text('确认，下一位'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}