import 'package:flutter/material.dart';
import 'package:uncover_agent/screens/host_screen.dart';
import 'package:uncover_agent/services/word_pool_service.dart';
import 'package:uncover_agent/utils/app_logger.dart';
import 'package:uncover_agent/widgets/setup/counter_setting_card.dart';
import 'package:uncover_agent/widgets/setup/difficulty_filter_setting_card.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const EdgeInsets _screenPadding = EdgeInsets.all(16);
  static const EdgeInsets _bottomBarPadding = EdgeInsets.fromLTRB(16, 8, 16, 16);
  static const EdgeInsets _contentCardPadding = EdgeInsets.all(16);
  static const int _maxPlayers = 12;
  static const int _minUndercover = 1;

  int get maxUndercover => (playerNum / 2).ceil() - 1;
  int get minPlayers => (undercoverNum * 2) + 1;
  Set<String>? get _selectedDifficulties => _enableDifficultyFilter && _selectedDifficulty != null
      ? {_selectedDifficulty!}
      : null;

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
    AppLogger.info('Setup screen initialized', name: 'SetupScreen');
    _checkWordPool();
  }

  Future<void> _checkWordPool() async {
    AppLogger.debug(
      'Checking word pool (filter=$_enableDifficultyFilter, difficulty=${_selectedDifficulty ?? 'none'})',
      name: 'SetupScreen',
    );

    setState(() {
      _isCheckingWordPool = true;
      _wordPoolError = null;
    });

    try {
      final availability = await WordPoolService.checkAvailability(
        enableDifficultyFilter: _enableDifficultyFilter,
        selectedDifficulty: _selectedDifficulty,
      );

      if (!mounted) return;
      setState(() {
        _isCheckingWordPool = false;
        _wordBankOptions = availability.options;
        _enableDifficultyFilter = availability.enableDifficultyFilter;
        _selectedDifficulty = availability.selectedDifficulty;
      });
      AppLogger.info(
        'Word pool ready (options=${availability.options.length}, categories=${availability.enabledCategories.length}, difficulties=${availability.availableDifficulties.length})',
        name: 'SetupScreen',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCheckingWordPool = false;
        _wordPoolError = error is StateError
            ? error.message
            : '词库加载失败，请检查 assets/wordbanks/index.json 或 assets/word_pairs.json';
      });
      AppLogger.error(
        'Word pool check failed',
        name: 'SetupScreen',
        error: error,
      );
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

  Future<void> _startGame() async {
    AppLogger.info(
      'Start game tapped (players=$playerNum, undercover=$undercoverNum, categories=${_enabledCategories().length}, difficulty=${_selectedDifficulty ?? 'none'})',
      name: 'SetupScreen',
    );

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
          selectedDifficulties: _selectedDifficulties,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _isStarting = false;
    });
    AppLogger.debug('Returned from host screen', name: 'SetupScreen');
  }

  void _onToggleDifficultyFilter(bool value) {
    AppLogger.info('Toggle difficulty filter: $value', name: 'SetupScreen');
    setState(() {
      _enableDifficultyFilter = value;
      _selectedDifficulty ??= _enabledDifficulties().first;
    });
    _checkWordPool();
  }

  void _onSelectDifficulty(String difficulty) {
    AppLogger.info('Select difficulty: $difficulty', name: 'SetupScreen');
    setState(() {
      _selectedDifficulty = difficulty;
    });
    _checkWordPool();
  }

  void _decreasePlayerCount() {
    setState(() {
      playerNum--;
    });
    AppLogger.debug('Player count decreased to $playerNum', name: 'SetupScreen');
  }

  void _increasePlayerCount() {
    setState(() {
      playerNum++;
      if (undercoverNum > maxUndercover) {
        undercoverNum = maxUndercover;
      }
    });
    AppLogger.debug(
      'Player count increased to $playerNum, undercover adjusted to $undercoverNum',
      name: 'SetupScreen',
    );
  }

  void _decreaseUndercoverCount() {
    setState(() {
      undercoverNum--;
    });
    AppLogger.debug('Undercover count decreased to $undercoverNum', name: 'SetupScreen');
  }

  void _increaseUndercoverCount() {
    setState(() {
      undercoverNum++;
    });
    AppLogger.debug('Undercover count increased to $undercoverNum', name: 'SetupScreen');
  }

  Widget _buildStartButton(bool canStart) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: canStart ? _startGame : null,
        child: Text(_isStarting ? '进入中...' : '开始游戏'),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Column(
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
      ],
    );
  }

  Widget _buildWordPoolStatusSection(BuildContext context) {
    if (_isCheckingWordPool) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('正在加载词库...'),
      );
    }

    if (_wordPoolError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEnabledCategoriesSummary() {
    final categories = _enabledCategories().toList()..sort();
    return Text(
      categories.isEmpty
          ? '当前未启用任何分类（请在 index.json 设置 enabled: true）'
          : '已启用分类：${categories.join('、')}',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildEnabledCategoriesSummary(),
        const SizedBox(height: 12),
        DifficultyFilterSettingCard(
          enabled: _enableDifficultyFilter,
          difficulties: _enabledDifficulties(),
          selectedDifficulty: _selectedDifficulty,
          onToggle: _onToggleDifficultyFilter,
          onSelectDifficulty: _onSelectDifficulty,
        ),
        const SizedBox(height: 12),
        CounterSettingCard(
          title: '玩家数',
          subtitle: '范围：$minPlayers - $_maxPlayers',
          value: playerNum,
          onDecrease: playerNum > minPlayers ? _decreasePlayerCount : null,
          onIncrease: playerNum < _maxPlayers ? _increasePlayerCount : null,
        ),
        const SizedBox(height: 12),
        CounterSettingCard(
          title: '卧底数',
          subtitle: '范围：$_minUndercover - $maxUndercover',
          value: undercoverNum,
          onDecrease: undercoverNum > _minUndercover ? _decreaseUndercoverCount : null,
          onIncrease: undercoverNum < maxUndercover ? _increaseUndercoverCount : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = !_isStarting && !_isCheckingWordPool && _wordPoolError == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏设置'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: _bottomBarPadding,
          child: _buildStartButton(canStart),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: _screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: _contentCardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderSection(context),
                              _buildWordPoolStatusSection(context),
                              _buildSettingsSection(),
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