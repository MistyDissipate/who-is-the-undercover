import 'package:flutter/material.dart';
import 'package:uncover_agent/screens/host_screen.dart';
import 'package:uncover_agent/services/word_pool_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const int maxPlayers = 12;
  static const int minUndercover = 1;
  int get maxUndercover => (playerNum / 2).ceil() - 1;
  int get minPlayers => (undercoverNum * 2) + 1;
  int playerNum = 4;
  int undercoverNum = 1;
  bool _isStarting = false;
  bool _isCheckingWordPool = true;
  String? _wordPoolError;

  @override
  void initState() {
    super.initState();
    _checkWordPool();
  }

  Future<void> _checkWordPool() async {
    setState(() {
      _isCheckingWordPool = true;
      _wordPoolError = null;
    });

    try {
      await WordPoolService.loadPairs();
      if (!mounted) return;
      setState(() {
        _isCheckingWordPool = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingWordPool = false;
        _wordPoolError = '词库加载失败，请检查 assets/word_pairs.json';
      });
    }
  }

  Widget _buildCounterTile({
    required String title,
    required String subtitle,
    required int value,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove),
          ),
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = !_isStarting && !_isCheckingWordPool && _wordPoolError == null;

    final startButton = SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: !canStart
            ? null
            : () async {
                setState(() {
                  _isStarting = true;
                });

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HostScreen(
                      playerCount: playerNum,
                      undercoverCount: undercoverNum,
                    ),
                  ),
                );

                if (!mounted) return;
                setState(() {
                  _isStarting = false;
                });
              },
        child: Text(_isStarting ? '进入中...' : '开始游戏'),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏设置'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: startButton,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '谁是卧底助手',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '设置玩家数量和卧底数量，然后开始游戏。',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              if (_isCheckingWordPool) ...[
                                const SizedBox(height: 8),
                                const Text('正在加载词库...'),
                              ],
                              if (_wordPoolError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _wordPoolError!,
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _checkWordPool,
                                  child: const Text('重试加载词库'),
                                ),
                              ],
                              const SizedBox(height: 16),
                              _buildCounterTile(
                                title: '玩家数',
                                subtitle: '范围：$minPlayers - $maxPlayers',
                                value: playerNum,
                                onDecrease: playerNum > minPlayers
                                    ? () {
                                        setState(() {
                                          playerNum--;
                                        });
                                      }
                                    : null,
                                onIncrease: playerNum < maxPlayers
                                    ? () {
                                        setState(() {
                                          playerNum++;
                                          if (undercoverNum > maxUndercover) {
                                            undercoverNum = maxUndercover;
                                          }
                                        });
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _buildCounterTile(
                                title: '卧底数',
                                subtitle: '范围：$minUndercover - $maxUndercover',
                                value: undercoverNum,
                                onDecrease: undercoverNum > minUndercover
                                    ? () {
                                        setState(() {
                                          undercoverNum--;
                                        });
                                      }
                                    : null,
                                onIncrease: undercoverNum < maxUndercover
                                    ? () {
                                        setState(() {
                                          undercoverNum++;
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ),
      ),
    );
  }
}