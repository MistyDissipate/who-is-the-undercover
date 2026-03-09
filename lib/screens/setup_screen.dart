import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uncover_agent/screens/host_screen.dart';
import 'package:uncover_agent/screens/word_bank_manage_screen.dart';
import 'package:uncover_agent/services/issue_report_service.dart';
import 'package:uncover_agent/services/update_service.dart';
import 'package:uncover_agent/services/word_pool_service.dart';
import 'package:uncover_agent/utils/app_logger.dart';
import 'package:uncover_agent/widgets/setup/counter_setting_card.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const List<String> _issueTypeOptions = ['崩溃', '卡顿', '显示异常', '其他'];
  static const String _lastAutoUpdateCheckAtKey = 'last_auto_update_check_at';
  static const Duration _autoUpdateCheckCooldown = Duration(hours: 6);

  int get maxUndercover => (playerNum / 2).ceil() - 1;
  int get minPlayers => (undercoverNum * 2) + 1;
  int playerNum = 4;
  int undercoverNum = 1;
  bool _isStarting = false;
  bool _isCheckingWordPool = true;
  bool _isSendingIssueReport = false;
  bool _isCheckingUpdate = false;
  bool _revealRoleOnElimination = true;
  String? _wordPoolError;
  List<WordBank> _wordBanks = [];
  String? _selectedWordBankId;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Setup screen initialized', name: 'SetupScreen');
    _loadWordBanks();

    if (UpdateService.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeAutoCheckForUpdates();
      });
    }
  }

  Future<void> _maybeAutoCheckForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckAt = prefs.getInt(_lastAutoUpdateCheckAtKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastCheckAt < _autoUpdateCheckCooldown.inMilliseconds) {
      return;
    }

    await prefs.setInt(_lastAutoUpdateCheckAtKey, now);
    await _checkForUpdates(silentIfLatest: true, silentOnError: true);
  }

  Future<void> _loadWordBanks() async {
    AppLogger.debug(
      'Loading word bank selection state',
      name: 'SetupScreen',
    );

    setState(() {
      _isCheckingWordPool = true;
      _wordPoolError = null;
    });

    try {
      final selectionState = await WordPoolService.getSelectionState(
        selectedBankId: _selectedWordBankId,
      );

      if (!mounted) return;
      setState(() {
        _isCheckingWordPool = false;
        _wordBanks = selectionState.banks;
        _selectedWordBankId = selectionState.selectedBankId;
      });
      AppLogger.info(
        'Word banks loaded (total=${selectionState.banks.length}, enabled=${selectionState.enabledBanks.length})',
        name: 'SetupScreen',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCheckingWordPool = false;
        _wordPoolError = error is StateError
            ? error.message
            : '词库加载失败，请检查 assets/wordbanks/index.json';
      });
      AppLogger.error(
        'Word bank load failed',
        name: 'SetupScreen',
        error: error,
      );
    }
  }

  List<WordBank> _enabledBanks() {
    return _wordBanks.where((bank) => bank.enabled).toList();
  }

  Future<void> _startGame() async {
    final selectedBankId = _selectedWordBankId;
    if (selectedBankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择可用词库')),
      );
      return;
    }

    AppLogger.info(
      'Start game tapped (players=$playerNum, undercover=$undercoverNum, wordBank=$selectedBankId, revealRole=$_revealRoleOnElimination)',
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
          selectedWordBankId: selectedBankId,
          revealRoleOnElimination: _revealRoleOnElimination,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _isStarting = false;
    });
    AppLogger.debug('Returned from host screen', name: 'SetupScreen');
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

  Future<void> _openWordBankManageScreen() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const WordBankManageScreen()),
    );
    await _loadWordBanks();
  }

  Future<void> _sendIssueReport() async {
    if (_isSendingIssueReport) return;

    final descriptionController = TextEditingController();
    var selectedIssueType = _issueTypeOptions.last;

    final reportInput = await showDialog<_IssueReportInput>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('发送问题日志'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('将打开邮箱并自动填入最近日志，你可以确认后发送。'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedIssueType,
                        decoration: const InputDecoration(
                          labelText: '问题类型',
                          border: OutlineInputBorder(),
                        ),
                        items: _issueTypeOptions
                            .map((type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedIssueType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 4,
                        minLines: 3,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: '可选：请描述问题发生时你做了什么',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(
                        _IssueReportInput(
                          issueType: selectedIssueType,
                          description: descriptionController.text.trim(),
                        ),
                      ),
                      child: const Text('继续'),
                    ),
                  ],
                );
              },
            );
          },
        );

    descriptionController.dispose();

    if (reportInput == null || !mounted) return;

    setState(() {
      _isSendingIssueReport = true;
    });

    AppLogger.info(
      'User triggered issue report email (type=${reportInput.issueType})',
      name: 'SetupScreen',
    );
    final success = await IssueReportService.sendLogsByEmail(
      userDescription: reportInput.description,
      issueType: reportInput.issueType,
    );

    if (!mounted) return;
    setState(() {
      _isSendingIssueReport = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '已打开邮箱，请确认后发送。' : '未找到可用邮箱客户端，请稍后重试。',
        ),
      ),
    );
  }

  Future<void> _checkForUpdates({
    bool silentIfLatest = false,
    bool silentOnError = false,
  }) async {
    if (_isCheckingUpdate) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final updateInfo = await UpdateService.checkForUpdates();
      if (!mounted) return;

      if (!updateInfo.hasUpdate) {
        if (!silentIfLatest) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('当前已是最新版本 v${updateInfo.currentVersion}')),
          );
        }
        return;
      }

      await _showUpdateDialog(updateInfo);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Update check failed',
        name: 'SetupScreen',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;
      if (silentOnError) {
        return;
      }

      if (error is UpdateCheckException && error.isRateLimited) {
        await _showRateLimitedDialog(error);
        return;
      }

      final errorText = error is UpdateCheckException ? error.message : '检查更新失败，请稍后重试。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isCheckingUpdate = false;
      });
    }
  }

  Future<void> _showRateLimitedDialog(UpdateCheckException error) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('检查更新过于频繁'),
        content: const Text('GitHub 接口当前限流，暂时无法直接获取最新版本信息。你可以先前往发布页手动查看。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri.parse(error.releasePageUrl ?? UpdateService.releaseLatestPageUrl);
              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!mounted) return;
              if (!launched) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('无法打开发布页，请稍后重试。')),
                );
              }
            },
            child: const Text('打开发布页'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateDialog(UpdateInfo updateInfo) async {
    final notes = updateInfo.releaseNotes.trim();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前版本：v${updateInfo.currentVersion}'),
                Text('最新版本：v${updateInfo.latestVersion}'),
                const SizedBox(height: 12),
                const Text('更新说明：'),
                const SizedBox(height: 6),
                SizedBox(
                  height: 220,
                  child: SingleChildScrollView(
                    child: Text(
                      notes.isEmpty ? '本次发布未填写更新说明。' : notes,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final targetUrl = updateInfo.downloadUrl ?? updateInfo.releasePageUrl;
                final uri = Uri.parse(targetUrl);
                final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!mounted) return;
                if (!launched) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('无法打开更新链接，请稍后重试。')),
                  );
                }
              },
              child: const Text('前往更新'),
            ),
          ],
        );
      },
    );
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
              onPressed: _loadWordBanks,
              child: const Text('重试加载词库'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEnabledCategoriesSummary() {
    final enabledBanks = _enabledBanks();
    return Text(
      enabledBanks.isEmpty
          ? '当前未启用任何词库，请先到词库管理中启用。'
          : '当前可用词库：${enabledBanks.length} 个',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
    );
  }

  Widget _buildWordBankSection() {
    final enabledBanks = _enabledBanks();
    final selectedExists = _selectedWordBankId != null &&
        enabledBanks.any((bank) => bank.id == _selectedWordBankId);
    final selected = selectedExists
        ? _selectedWordBankId
        : (enabledBanks.isNotEmpty ? enabledBanks.first.id : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '词库选择',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _openWordBankManageScreen,
                child: const Text('管理词库'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selected,
            items: enabledBanks
                .map(
                  (bank) => DropdownMenuItem<String>(
                    value: bank.id,
                    child: Text('${bank.name}（${bank.entries.length}词条）'),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onChanged: enabledBanks.isEmpty
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedWordBankId = value;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildRuleOptionsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          '出局后显示身份',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          '关闭后仅显示玩家已淘汰，不公布其身份',
          style: TextStyle(fontSize: 12),
        ),
        value: _revealRoleOnElimination,
        onChanged: (value) {
          setState(() {
            _revealRoleOnElimination = value;
          });
        },
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildEnabledCategoriesSummary(),
        const SizedBox(height: 12),
        _buildWordBankSection(),
        const SizedBox(height: 12),
        _buildRuleOptionsSection(),
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
        actions: [
          IconButton(
            onPressed: _isSendingIssueReport ? null : _sendIssueReport,
            tooltip: '反馈问题',
            icon: _isSendingIssueReport
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bug_report_outlined),
          ),
          IconButton(
            onPressed: _isCheckingUpdate ? null : _checkForUpdates,
            tooltip: '检查更新',
            icon: _isCheckingUpdate
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt_outlined),
          ),
        ],
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

class _IssueReportInput {
  final String issueType;
  final String description;

  const _IssueReportInput({
    required this.issueType,
    required this.description,
  });
}