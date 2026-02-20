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
  List<WordBankOption> _wordBankOptions = [];
  bool _enableDifficultyFilter = false;
  String? _selectedDifficulty;

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
      final options = await WordPoolService.loadWordBankOptions();
      final enabledCategories = options
          .where((item) => item.enabled && item.category.isNotEmpty)
          .map((item) => item.category)
          .toSet();

      final availableDifficulties = options
          .where((item) => item.enabled && item.difficulty.isNotEmpty)
          .map((item) => item.difficulty)
          .toSet();

      if (_selectedDifficulty != null && !availableDifficulties.contains(_selectedDifficulty)) {
        _selectedDifficulty = null;
        _enableDifficultyFilter = false;
      }

      final pairs = await WordPoolService.loadPairs(
        categories: enabledCategories,
        difficulties: _enableDifficultyFilter && _selectedDifficulty != null
            ? {_selectedDifficulty!}
            : null,
      );

      if (pairs.isEmpty) {
        throw StateError('当前筛选条件下没有可用词库，请调整索引 enabled 或难度开关');
      }

      if (!mounted) return;
      setState(() {
        _isCheckingWordPool = false;
        _wordBankOptions = options;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCheckingWordPool = false;
        _wordPoolError = error is StateError
            ? error.message
            : '词库加载失败，请检查 assets/wordbanks/index.json 或 assets/word_pairs.json';
      });
    }
  }

  Set<String> _enabledCategories() {
    return _wordBankOptions
        .where((item) => item.enabled && item.category.isNotEmpty)
        .map((item) => item.category)
        .toSet();
  }

  List<String> _enabledDifficulties() {
    final values = _wordBankOptions
        .where((item) => item.enabled && item.difficulty.isNotEmpty)
        .map((item) => item.difficulty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  Widget _buildDifficultyFilterCard() {
    final difficulties = _enabledDifficulties();
    final canToggle = difficulties.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '按难度筛选词库',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              canToggle ? '开启后仅使用所选难度' : '当前没有可用难度',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            value: _enableDifficultyFilter,
            onChanged: !canToggle
                ? null
                : (value) {
                    setState(() {
                      _enableDifficultyFilter = value;
                      _selectedDifficulty ??= difficulties.first;
                    });
                    _checkWordPool();
                  },
          ),
          if (_enableDifficultyFilter && canToggle) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: difficulties.map((difficulty) {
                final selected = _selectedDifficulty == difficulty;
                return ChoiceChip(
                  label: Text(difficulty),
                  selected: selected,
                  onSelected: (isSelected) {
                    if (!isSelected) return;
                    setState(() {
                      _selectedDifficulty = difficulty;
                    });
                    _checkWordPool();
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
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
                      selectedCategories: _enabledCategories(),
                      selectedDifficulties: _enableDifficultyFilter &&
                              _selectedDifficulty != null
                          ? {_selectedDifficulty!}
                          : null,
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
                              Builder(
                                builder: (context) {
                                  final categories = _enabledCategories().toList()..sort();
                                  return Text(
                                    categories.isEmpty
                                        ? '当前未启用任何分类（请在 index.json 设置 enabled: true）'
                                        : '已启用分类：${categories.join('、')}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildDifficultyFilterCard(),
                              const SizedBox(height: 12),
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