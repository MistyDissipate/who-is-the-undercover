import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../services/game_service.dart';
import 'vote_screen.dart';

class HostScreen extends StatefulWidget {
  final int playerCount;
  final int undercoverCount;

  const HostScreen({
    super.key,
    required this.playerCount,
    required this.undercoverCount,
  });

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  List<Player> players = [];
  int currentIndex = 0;
  bool _isWordVisible = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initPlayers();
  }

  Future<void> _initPlayers() async {
    try {
      final loadedPlayers = await GameService.createPlayersFromWordPool(
        widget.playerCount,
        widget.undercoverCount,
      );

      if (!mounted) return;
      setState(() {
        players = loadedPlayers;
        currentIndex = 0;
        _isWordVisible = false;
        _isLoading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '词库加载失败，请检查 assets 配置和 JSON 格式';
      });
    }
  }

  Future<void> _nextPlayer() async {
    final isLastPlayer = currentIndex >= players.length - 1;
    if (isLastPlayer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('所有玩家都已查看词汇')),
      );
      return;
    }

    setState(() {
      currentIndex += 1;
      _isWordVisible = false;
    });
  }

  Future<void> _startGame() async {
    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute(
        builder: (context) => VoteScreen(players: players),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('查看词汇'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('查看词汇'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                    });
                    _initPlayers();
                  },
                  child: Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (players.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('查看词汇'),
        ),
        body: Center(
          child: Text('没有可用玩家数据'),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final player = players[currentIndex];
    final isLastPlayer = currentIndex >= players.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('查看词汇'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              onPressed: !_isWordVisible
                  ? null
                  : isLastPlayer
                      ? _startGame
                      : _nextPlayer,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(isLastPlayer ? '开始游戏' : '确认，下一位'),
            ),
          ],
        ),
      ),
    );
  }
}