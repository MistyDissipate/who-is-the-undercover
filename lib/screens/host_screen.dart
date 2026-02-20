import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../services/game_service.dart';
import 'vote_screen.dart';

class HostScreen extends StatefulWidget {
  final int playerCount;
  final int undercoverCount;

  const HostScreen({
    Key? key,
    required this.playerCount,
    required this.undercoverCount,
  }) : super(key: key);

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late List<Player> players;
  int currentIndex = 0;
  bool _isWordVisible = false;

  @override
  void initState() {
    super.initState();
    // 使用假数据初始化
    players = GameService.createMockPlayers(
      widget.playerCount,
      widget.undercoverCount,
    );
  }

  Future<void> _nextPlayer() async {
    final aliveIndices = <int>[];
    for (int index = 0; index < players.length; index++) {
      if (players[index].isAlive) {
        aliveIndices.add(index);
      }
    }

    if (aliveIndices.isEmpty) return;

    final currentAlivePosition = aliveIndices.indexOf(currentIndex);
    if (currentAlivePosition == -1) {
      setState(() {
        currentIndex = aliveIndices.first;
        _isWordVisible = false;
      });
      return;
    }

    final isLastAlivePlayer = currentAlivePosition == aliveIndices.length - 1;
    if (isLastAlivePlayer) {
      await Navigator.pushAndRemoveUntil<void>(
        context,
        MaterialPageRoute(
          builder: (context) => VoteScreen(players: players),
        ),
        (route) => route.isFirst,
      );
      return;
    }

    setState(() {
      currentIndex = aliveIndices[currentAlivePosition + 1];
      _isWordVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isWordVisible ? player.word : '???',
                style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            if (!_isWordVisible)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isWordVisible = true;
                  });
                },
                child: Text('点击查看词汇'),
              ),
            SizedBox(height: 60),
            ElevatedButton(
              onPressed: _isWordVisible ? _nextPlayer : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text('确认，下一位'),
            ),
          ],
        ),
      ),
    );
  }
}