import 'package:flutter/material.dart';
import 'package:uncover_agent/services/word_pool_service.dart';

class WordBankEditScreen extends StatefulWidget {
  final WordBank bank;

  const WordBankEditScreen({
    super.key,
    required this.bank,
  });

  @override
  State<WordBankEditScreen> createState() => _WordBankEditScreenState();
}

class _WordBankEditScreenState extends State<WordBankEditScreen> {
  late final TextEditingController _nameController;
  late List<WordPair> _entries;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bank.name);
    _entries = [...widget.bank.entries];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addEntry() async {
    final civilianController = TextEditingController();
    final undercoverController = TextEditingController();

    final entry = await showDialog<WordPair>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增词条'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: civilianController,
              decoration: const InputDecoration(
                labelText: '平民词',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: undercoverController,
              decoration: const InputDecoration(
                labelText: '卧底词',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final civilian = civilianController.text.trim();
              final undercover = undercoverController.text.trim();
              if (civilian.isEmpty || undercover.isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                WordPair(
                  civilian: civilian,
                  undercover: undercover,
                  category: widget.bank.name,
                  difficulty: 'custom',
                ),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    civilianController.dispose();
    undercoverController.dispose();

    if (entry == null) return;

    setState(() {
      _entries = [..._entries, entry];
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index);
    });
  }

  void _save() {
    final normalizedName = _nameController.text.trim();
    if (normalizedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('词库名称不能为空')),
      );
      return;
    }
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少保留一个词条')),
      );
      return;
    }

    final updatedEntries = _entries
        .map(
          (item) => WordPair(
            civilian: item.civilian,
            undercover: item.undercover,
            category: normalizedName,
            difficulty: item.difficulty,
          ),
        )
        .toList();

    Navigator.pop(
      context,
      widget.bank.copyWith(
        name: normalizedName,
        entries: updatedEntries,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑词库'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '词库名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _entries.isEmpty
                  ? const Center(child: Text('暂无词条，点击右下角添加'))
                  : ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return ListTile(
                          title: Text(entry.civilian),
                          subtitle: Text('卧底词：${entry.undercover}'),
                          trailing: IconButton(
                            tooltip: '删除',
                            onPressed: () => _removeEntry(index),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}