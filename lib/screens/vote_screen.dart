import 'package:flutter/material.dart';
import '../models/game_models.dart';
import 'host_screen.dart';

class VoteScreen extends StatefulWidget {
  final List<Player> players;
  final bool revealRoleOnElimination;
  final String selectedWordBankId;

  const VoteScreen({
    super.key,
    required this.players,
    required this.revealRoleOnElimination,
    required this.selectedWordBankId,
  });

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  late List<Player> _players;
  Player? _selectedPlayer; // 当前选中的玩家

  String _roleLabel(GameRole role) {
    return role == GameRole.civilian ? '平民' : '卧底';
  }

  @override
  void initState() {
    super.initState();
    _players = widget.players.map((p) => p.copy()).toList();
  }

  void _eliminateSelected() {
    if (_selectedPlayer == null) return;

    final eliminated = _selectedPlayer!;
    setState(() {
      // 标记选中玩家死亡
      final index = _players.indexWhere((p) => p.id == _selectedPlayer!.id);
      if (index != -1) {
        _players[index].isAlive = false;
      }
      _selectedPlayer = null;
    });

    final message = widget.revealRoleOnElimination
        ? '${eliminated.name} 已出局，身份：${_roleLabel(eliminated.role)}'
        : '${eliminated.name} 已出局';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    // 检查游戏是否结束
    _checkGameOver();
  }

  Future<void> _confirmEliminateSelected() async {
    if (_selectedPlayer == null) return;
    final playerName = _selectedPlayer!.name;
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认淘汰'),
        content: Text('确定要淘汰 $playerName 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: Text('确认淘汰'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _eliminateSelected();
    }
  }

  Future<void> _showForgotWordDialog() async {
    final alivePlayers = _players.where((p) => p.isAlive).toList();
    if (alivePlayers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('当前没有可查看词汇的玩家')),
      );
      return;
    }

    final selected = await showDialog<Player>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('忘词回看'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: alivePlayers.length,
            itemBuilder: (context, index) {
              final player = alivePlayers[index];
              return ListTile(
                title: Text(player.name),
                onTap: () => Navigator.pop(context, player),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
        ],
      ),
    );

    if (!mounted || selected == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${selected.name} 的词汇'),
        content: Text(
          selected.word,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('我已记住'),
          ),
        ],
      ),
    );
  }

  void _checkGameOver() {
    int aliveUndercover = _players.where((p) => p.isAlive && p.role == GameRole.undercover).length;
    int aliveCivilian = _players.where((p) => p.isAlive && p.role == GameRole.civilian).length;

    String? result;
    if (aliveUndercover == 0) {
      result = '平民胜利！';
    } else if (aliveCivilian <= aliveUndercover) {
      result = '卧底胜利！';
    }

    if (result != null) {
      _showGameOverDialog(result);
    }
  }

  void _showGameOverDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('游戏结算'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('所有玩家身份与词汇：'),
              SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _players.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final player = _players[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(player.name),
                      subtitle: Text('身份：${_roleLabel(player.role)}  |  词汇：${player.word}'),
                      trailing: Text(player.isAlive ? '存活' : '淘汰'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true)
                  .popUntil((route) => route.isFirst);
            },
            child: Text('返回首页'),
          ),
          TextButton(
            onPressed: () {
              final playerCount = _players.length;
              final undercoverCount = _players
                  .where((p) => p.role == GameRole.undercover)
                  .length;

              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
                MaterialPageRoute(
                  builder: (context) => HostScreen(
                    playerCount: playerCount,
                    undercoverCount: undercoverCount,
                    selectedWordBankId: widget.selectedWordBankId,
                    revealRoleOnElimination: widget.revealRoleOnElimination,
                  ),
                ),
                (route) => route.isFirst,
              );
            },
            child: Text('再来一局'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('投票淘汰'),
        actions: [
          IconButton(
            onPressed: _showForgotWordDialog,
            tooltip: '忘词回看',
            icon: Icon(Icons.visibility_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RadioGroup<Player>(
              groupValue: _selectedPlayer,
              onChanged: (value) {
                setState(() {
                  _selectedPlayer = value;
                });
              },
              child: ListView.builder(
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  final player = _players[index];
                  if (!player.isAlive) return SizedBox.shrink(); // 不显示已淘汰玩家
                  return ListTile(
                    title: Text(player.name),
                    leading: Radio<Player>(value: player),
                    onTap: () {
                      setState(() {
                        _selectedPlayer = player;
                      });
                    },
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ElevatedButton(
                onPressed: _selectedPlayer == null ? null : _confirmEliminateSelected,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                child: Text('淘汰选中玩家'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}