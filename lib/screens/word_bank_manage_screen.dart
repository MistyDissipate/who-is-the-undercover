import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uncover_agent/screens/word_bank_edit_screen.dart';
import 'package:uncover_agent/services/word_pool_service.dart';

class WordBankManageScreen extends StatefulWidget {
  const WordBankManageScreen({super.key});

  @override
  State<WordBankManageScreen> createState() => _WordBankManageScreenState();
}

class _WordBankManageScreenState extends State<WordBankManageScreen> {
  bool _isLoading = true;
  List<WordBank> _banks = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
    });
    final banks = await WordPoolService.loadBanks();
    if (!mounted) return;
    setState(() {
      _banks = banks;
      _isLoading = false;
    });
  }

  Future<void> _toggleBank(WordBank bank, bool enabled) async {
    try {
      await WordPoolService.setBankEnabled(bank.id, enabled);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _createUserBank() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建词库'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '词库名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    nameController.dispose();

    if (name == null || name.isEmpty) return;
    if (!mounted) return;

    final bank = WordPoolService.createEmptyUserBank(name);
    final edited = await Navigator.push<WordBank>(
      context,
      MaterialPageRoute(builder: (context) => WordBankEditScreen(bank: bank)),
    );

    if (edited == null) return;
    await WordPoolService.saveUserBank(edited);
    await _reload();
  }

  Future<void> _importBank() async {
    final controller = TextEditingController();
    final rawText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入词库（TOML）'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(
              hintText: 'name = "我的词库"\n\n[[pairs]]\ncivilian = "苹果"\nundercover = "香蕉"',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (rawText == null || rawText.isEmpty) return;
    if (!mounted) return;

    try {
      await WordPoolService.importUserBank(rawText);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('词库导入成功')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _exportBank(WordBank bank) async {
    try {
      final toml = await WordPoolService.exportBankToToml(bank.id);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('导出：${bank.name}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(toml),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: toml));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _editBank(WordBank bank) async {
    final edited = await Navigator.push<WordBank>(
      context,
      MaterialPageRoute(builder: (context) => WordBankEditScreen(bank: bank)),
    );
    if (edited == null) return;

    await WordPoolService.saveUserBank(edited);
    await _reload();
  }

  Future<void> _deleteBank(WordBank bank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除词库'),
        content: Text('确定删除词库“${bank.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await WordPoolService.deleteUserBank(bank.id);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('词库管理'),
        actions: [
          IconButton(
            onPressed: _importBank,
            tooltip: '导入词库',
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            onPressed: _createUserBank,
            tooltip: '新建词库',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _banks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bank = _banks[index];
                return ListTile(
                  title: Text(bank.name),
                  subtitle: Text('${bank.isDefault ? '默认' : '用户'}词库 · ${bank.entries.length} 词条'),
                  leading: Switch(
                    value: bank.enabled,
                    onChanged: (value) => _toggleBank(bank, value),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: '导出',
                        onPressed: () => _exportBank(bank),
                        icon: const Icon(Icons.ios_share_outlined),
                      ),
                      if (bank.isUser)
                        IconButton(
                          tooltip: '编辑',
                          onPressed: () => _editBank(bank),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      if (bank.isUser)
                        IconButton(
                          tooltip: '删除',
                          onPressed: () => _deleteBank(bank),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}