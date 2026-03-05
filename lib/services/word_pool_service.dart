import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uncover_agent/utils/app_logger.dart';

class WordPair {
  final String civilian;
  final String undercover;
  final String category;
  final String difficulty;

  const WordPair({
    required this.civilian,
    required this.undercover,
    required this.category,
    required this.difficulty,
  });

  factory WordPair.fromJson(Map<String, dynamic> json) {
    return WordPair(
      civilian: (json['civilian'] ?? '').toString().trim(),
      undercover: (json['undercover'] ?? '').toString().trim(),
      category: (json['category'] ?? '').toString().trim(),
      difficulty: (json['difficulty'] ?? 'easy').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'civilian': civilian,
      'undercover': undercover,
      'category': category,
      'difficulty': difficulty,
    };
  }
}

enum WordBankSourceType { defaultAsset, user }

class WordBank {
  final String id;
  final String name;
  final WordBankSourceType sourceType;
  final bool enabled;
  final List<WordPair> entries;

  const WordBank({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.enabled,
    required this.entries,
  });

  bool get isDefault => sourceType == WordBankSourceType.defaultAsset;
  bool get isUser => sourceType == WordBankSourceType.user;

  WordBank copyWith({
    String? id,
    String? name,
    WordBankSourceType? sourceType,
    bool? enabled,
    List<WordPair>? entries,
  }) {
    return WordBank(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      enabled: enabled ?? this.enabled,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toUserJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'entries': entries
          .map(
            (pair) => {
              'civilian': pair.civilian,
              'undercover': pair.undercover,
              'category': pair.category,
              'difficulty': pair.difficulty,
            },
          )
          .toList(),
    };
  }

  factory WordBank.fromUserJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = rawEntries is List
        ? rawEntries
            .whereType<Map<String, dynamic>>()
            .map(WordPair.fromJson)
            .where((pair) => pair.civilian.isNotEmpty && pair.undercover.isNotEmpty)
            .toList()
        : <WordPair>[];

    return WordBank(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      sourceType: WordBankSourceType.user,
      enabled: json['enabled'] != false,
      entries: entries,
    );
  }
}

class WordPoolSelectionState {
  final List<WordBank> banks;
  final String selectedBankId;

  const WordPoolSelectionState({
    required this.banks,
    required this.selectedBankId,
  });

  List<WordBank> get enabledBanks {
    return banks.where((bank) => bank.enabled).toList();
  }

  WordBank get selectedBank {
    return banks.firstWhere((bank) => bank.id == selectedBankId);
  }
}

class WordPoolService {
  static const String _legacyAssetPath = 'assets/word_pairs.json';
  static const String _indexAssetPath = 'assets/wordbanks/index.json';
  static const String _prefsUserBanksKey = 'user_word_banks';
  static const String _prefsDefaultEnabledMapKey = 'default_word_bank_enabled_map';
  static final RegExp _tomlKvRegExp = RegExp(r'^([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*"(.*)"\s*$');
  static final Random _random = Random();
  static List<WordBank>? _cachedDefaultBanks;

  static Future<WordPoolSelectionState> getSelectionState({String? selectedBankId}) async {
    final banks = await loadBanks();
    final enabledBanks = banks.where((bank) => bank.enabled).toList();

    if (enabledBanks.isEmpty) {
      throw StateError('至少需要启用一个词库');
    }

    final hasSelected = selectedBankId != null && banks.any((bank) => bank.id == selectedBankId);
    final normalizedSelectedId = hasSelected &&
            banks.firstWhere((bank) => bank.id == selectedBankId).enabled
        ? selectedBankId
        : enabledBanks.first.id;

    return WordPoolSelectionState(banks: banks, selectedBankId: normalizedSelectedId);
  }

  static Future<List<WordBank>> loadBanks() async {
    final defaultBanks = await _loadDefaultBanks();
    final prefs = await SharedPreferences.getInstance();
    final enabledOverrides = _decodeEnabledOverrides(prefs.getString(_prefsDefaultEnabledMapKey));

    final normalizedDefaults = defaultBanks.map((bank) {
      final override = enabledOverrides[bank.id];
      return bank.copyWith(enabled: override ?? bank.enabled);
    }).toList();

    final userBanks = _loadUserBanksFromPrefs(prefs);
    final banks = [...normalizedDefaults, ...userBanks];

    if (banks.every((bank) => !bank.enabled) && banks.isNotEmpty) {
      final updated = banks.first.copyWith(enabled: true);
      banks[0] = updated;
      await _persistDefaultEnabledOverride(updated.id, true);
    }

    return banks;
  }

  static Future<List<WordPair>> loadPairsByBank(String bankId) async {
    final banks = await loadBanks();
    final bank = banks.where((item) => item.id == bankId).firstOrNull;
    if (bank == null) {
      throw StateError('未找到词库：$bankId');
    }
    if (!bank.enabled) {
      throw StateError('所选词库未启用：${bank.name}');
    }
    if (bank.entries.isEmpty) {
      throw StateError('词库为空：${bank.name}');
    }
    return bank.entries;
  }

  static Future<WordPair> getRandomPair({required String bankId}) async {
    final pairs = await loadPairsByBank(bankId);
    final index = _random.nextInt(pairs.length);
    return pairs[index];
  }

  static Future<void> setBankEnabled(String bankId, bool enabled) async {
    final banks = await loadBanks();
    final index = banks.indexWhere((item) => item.id == bankId);
    if (index < 0) {
      throw StateError('未找到词库：$bankId');
    }

    final target = banks[index];
    if (target.enabled == enabled) {
      return;
    }

    final enabledCount = banks.where((bank) => bank.enabled).length;
    if (!enabled && enabledCount <= 1) {
      throw StateError('至少需要保留一个启用词库');
    }

    if (target.isDefault) {
      await _persistDefaultEnabledOverride(bankId, enabled);
      return;
    }

    final updated = target.copyWith(enabled: enabled);
    banks[index] = updated;
    await _persistUserBanks(banks.where((bank) => bank.isUser).toList());
  }

  static WordBank createEmptyUserBank(String name) {
    return WordBank(
      id: 'user:${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      sourceType: WordBankSourceType.user,
      enabled: true,
      entries: const [],
    );
  }

  static Future<void> saveUserBank(WordBank bank) async {
    if (!bank.isUser) {
      throw ArgumentError('仅支持保存用户词库');
    }
    if (bank.name.trim().isEmpty) {
      throw StateError('词库名称不能为空');
    }

    final prefs = await SharedPreferences.getInstance();
    final userBanks = _loadUserBanksFromPrefs(prefs);
    final index = userBanks.indexWhere((item) => item.id == bank.id);
    if (index >= 0) {
      userBanks[index] = bank;
    } else {
      userBanks.add(bank);
    }
    await _persistUserBanks(userBanks);
  }

  static Future<void> deleteUserBank(String bankId) async {
    final prefs = await SharedPreferences.getInstance();
    final userBanks = _loadUserBanksFromPrefs(prefs);
    final target = userBanks.where((item) => item.id == bankId).firstOrNull;
    if (target == null) {
      return;
    }

    final banks = await loadBanks();
    final enabledCount = banks.where((bank) => bank.enabled).length;
    if (target.enabled && enabledCount <= 1) {
      throw StateError('至少需要保留一个启用词库');
    }

    userBanks.removeWhere((item) => item.id == bankId);
    await _persistUserBanks(userBanks);
  }

  static Future<WordBank> importUserBank(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw StateError('导入失败：内容为空');
    }

    if (text.startsWith('{') || text.startsWith('[')) {
      return importUserBankFromJson(text);
    }

    return importUserBankFromToml(text);
  }

  static Future<WordBank> importUserBankFromJson(String rawJson) async {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('导入失败：JSON 根节点必须是对象');
    }

    final name = (decoded['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      throw StateError('导入失败：词库 name 不能为空');
    }

    final dynamic rawPairs = decoded['pairs'];
    if (rawPairs is! List) {
      throw StateError('导入失败：pairs 必须是数组');
    }

    final entries = rawPairs
        .whereType<Map<String, dynamic>>()
        .map((item) => WordPair.fromJson({
              ...item,
              if ((item['category'] ?? '').toString().trim().isEmpty) 'category': name,
              if ((item['difficulty'] ?? '').toString().trim().isEmpty) 'difficulty': 'custom',
            }))
        .where((pair) => pair.civilian.isNotEmpty && pair.undercover.isNotEmpty)
        .toList();

    if (entries.isEmpty) {
      throw StateError('导入失败：没有有效词条');
    }

    final bank = WordBank(
      id: 'user:${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      sourceType: WordBankSourceType.user,
      enabled: true,
      entries: entries,
    );

    await saveUserBank(bank);
    return bank;
  }

  static Future<WordBank> importUserBankFromToml(String rawToml) async {
    final parsed = _parseTomlWordBank(rawToml);
    final bank = WordBank(
      id: 'user:${DateTime.now().microsecondsSinceEpoch}',
      name: parsed.name,
      sourceType: WordBankSourceType.user,
      enabled: true,
      entries: parsed.entries,
    );

    await saveUserBank(bank);
    return bank;
  }

  static Future<String> exportBankToToml(String bankId) async {
    final banks = await loadBanks();
    final bank = banks.where((item) => item.id == bankId).firstOrNull;
    if (bank == null) {
      throw StateError('导出失败：词库不存在');
    }

    final buffer = StringBuffer();
    buffer.writeln('name = "${_escapeToml(bank.name)}"');
    for (final pair in bank.entries) {
      buffer.writeln();
      buffer.writeln('[[pairs]]');
      buffer.writeln('civilian = "${_escapeToml(pair.civilian)}"');
      buffer.writeln('undercover = "${_escapeToml(pair.undercover)}"');
    }
    return buffer.toString();
  }

  static Future<List<WordBank>> _loadDefaultBanks() async {
    if (_cachedDefaultBanks != null) {
      return _cachedDefaultBanks!;
    }

    AppLogger.info('Loading default word banks from assets', name: 'WordPoolService');

    final indexString = await rootBundle.loadString(_indexAssetPath);
    final dynamic decoded = jsonDecode(indexString);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('词库索引格式错误：根节点必须是对象');
    }

    final dynamic files = decoded['files'];
    if (files is! List) {
      throw StateError('词库索引格式错误：files 必须是数组');
    }

    final banks = <WordBank>[];
    for (final item in files.whereType<Map<String, dynamic>>()) {
      final path = (item['path'] ?? '').toString().trim();
      if (path.isEmpty) continue;

      final category = (item['category'] ?? '').toString().trim();
      final difficulty = (item['difficulty'] ?? 'easy').toString().trim();
      final entries = await _loadPairsFromBankAsset(path, category: category, difficulty: difficulty);
      if (entries.isEmpty) continue;

      banks.add(
        WordBank(
          id: 'default:$path',
          name: category.isNotEmpty ? '$category（$difficulty）' : path.split('/').last,
          sourceType: WordBankSourceType.defaultAsset,
          enabled: item['enabled'] != false,
          entries: entries,
        ),
      );
    }

    if (banks.isEmpty) {
      final legacyPairs = await _loadFromLegacyBank();
      if (legacyPairs.isEmpty) {
        throw StateError('词库为空：请在 assets/wordbanks/ 或 assets/word_pairs.json 中添加词对');
      }

      banks.add(
        WordBank(
          id: 'default:legacy',
          name: '默认词库（legacy）',
          sourceType: WordBankSourceType.defaultAsset,
          enabled: true,
          entries: legacyPairs,
        ),
      );
    }

    _cachedDefaultBanks = banks;
    return _cachedDefaultBanks!;
  }

  static Future<List<WordPair>> _loadPairsFromBankAsset(
    String assetPath, {
    required String category,
    required String difficulty,
  }) async {
    final bankString = await rootBundle.loadString(assetPath);
    if (assetPath.toLowerCase().endsWith('.toml')) {
      final parsed = _parseTomlWordBank(bankString, fallbackName: category);
      return parsed.entries
          .map(
            (pair) => WordPair(
              civilian: pair.civilian,
              undercover: pair.undercover,
              category: pair.category.isNotEmpty ? pair.category : category,
              difficulty: pair.difficulty.isNotEmpty ? pair.difficulty : difficulty,
            ),
          )
          .toList();
    }

    final dynamic decodedBank = jsonDecode(bankString);
    if (decodedBank is! Map<String, dynamic>) {
      return [];
    }

    final bankCategory = (decodedBank['category'] ?? category).toString().trim();
    final bankDifficulty = (decodedBank['difficulty'] ?? difficulty).toString().trim();
    final dynamic rawPairs = decodedBank['pairs'];
    if (rawPairs is! List) {
      return [];
    }

    return rawPairs
        .whereType<Map<String, dynamic>>()
        .map(
          (raw) => WordPair.fromJson({
            ...raw,
            if ((raw['category'] ?? '').toString().trim().isEmpty) 'category': bankCategory,
            if ((raw['difficulty'] ?? '').toString().trim().isEmpty)
              'difficulty': bankDifficulty,
          }),
        )
        .where((pair) => pair.civilian.isNotEmpty && pair.undercover.isNotEmpty)
        .toList();
  }

  static _ParsedTomlBank _parseTomlWordBank(String rawToml, {String? fallbackName}) {
    final lines = rawToml.replaceAll('\r\n', '\n').split('\n');

    String bankName = (fallbackName ?? '').trim();
    final entries = <WordPair>[];
    Map<String, String>? currentPair;

    void flushCurrentPair() {
      if (currentPair == null) return;
      final civilian = (currentPair!['civilian'] ?? '').trim();
      final undercover = (currentPair!['undercover'] ?? '').trim();
      if (civilian.isEmpty || undercover.isEmpty) {
        currentPair = null;
        return;
      }

      final resolvedCategory = (currentPair!['category'] ?? bankName).trim();
      final resolvedDifficulty = (currentPair!['difficulty'] ?? 'custom').trim();
      entries.add(
        WordPair(
          civilian: civilian,
          undercover: undercover,
          category: resolvedCategory,
          difficulty: resolvedDifficulty,
        ),
      );
      currentPair = null;
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      if (line == '[[pairs]]' || line == '[[entries]]') {
        flushCurrentPair();
        currentPair = <String, String>{};
        continue;
      }

      final match = _tomlKvRegExp.firstMatch(line);
      if (match == null) {
        continue;
      }

      final key = match.group(1)!;
      final value = _unescapeToml(match.group(2)!);

      if (currentPair == null) {
        if (key == 'name') {
          bankName = value.trim();
        }
        continue;
      }

      if (key == 'civilian' || key == 'undercover' || key == 'category' || key == 'difficulty') {
        currentPair?[key] = value.trim();
      }
    }

    flushCurrentPair();

    if (bankName.isEmpty) {
      throw StateError('导入失败：TOML 缺少 name 字段');
    }
    if (entries.isEmpty) {
      throw StateError('导入失败：TOML 没有有效 pairs 词条');
    }

    final normalizedEntries = entries
        .map(
          (item) => item.copyWith(
            category: item.category.isEmpty ? bankName : item.category,
            difficulty: item.difficulty.isEmpty ? 'custom' : item.difficulty,
          ),
        )
        .toList();

    AppLogger.debug('Parsed TOML bank "$bankName" with ${normalizedEntries.length} pairs', name: 'WordPoolService');

    return _ParsedTomlBank(name: bankName, entries: normalizedEntries);
  }

  static String _escapeToml(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  static String _unescapeToml(String value) {
    return value.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
  }

  static List<WordBank> _loadUserBanksFromPrefs(SharedPreferences prefs) {
    final jsonString = prefs.getString(_prefsUserBanksKey);
    if (jsonString == null || jsonString.trim().isEmpty) {
      return <WordBank>[];
    }

    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        return <WordBank>[];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(WordBank.fromUserJson)
          .where((bank) => bank.id.isNotEmpty && bank.name.isNotEmpty)
          .toList();
    } catch (_) {
      return <WordBank>[];
    }
  }

  static Future<void> _persistUserBanks(List<WordBank> banks) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = banks.map((bank) => bank.toUserJson()).toList();
    await prefs.setString(_prefsUserBanksKey, jsonEncode(raw));
  }

  static Map<String, bool> _decodeEnabledOverrides(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, bool>{};
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, bool>{};

      final map = <String, bool>{};
      decoded.forEach((key, value) {
        map[key] = value == true;
      });
      return map;
    } catch (_) {
      return <String, bool>{};
    }
  }

  static Future<void> _persistDefaultEnabledOverride(String bankId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _decodeEnabledOverrides(prefs.getString(_prefsDefaultEnabledMapKey));
    existing[bankId] = enabled;
    await prefs.setString(_prefsDefaultEnabledMapKey, jsonEncode(existing));
  }

  static Future<List<WordPair>> _loadFromLegacyBank() async {
    final jsonString = await rootBundle.loadString(_legacyAssetPath);
    final dynamic decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('词库格式错误：根节点必须是对象');
    }

    final dynamic rawPairs = decoded['pairs'];
    if (rawPairs is! List) {
      throw StateError('词库格式错误：pairs 必须是数组');
    }

    return rawPairs
        .whereType<Map<String, dynamic>>()
        .map(WordPair.fromJson)
        .where((pair) => pair.civilian.isNotEmpty && pair.undercover.isNotEmpty)
        .toList();
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}

class _ParsedTomlBank {
  final String name;
  final List<WordPair> entries;

  const _ParsedTomlBank({
    required this.name,
    required this.entries,
  });
}

extension _WordPairCopy on WordPair {
  WordPair copyWith({
    String? civilian,
    String? undercover,
    String? category,
    String? difficulty,
  }) {
    return WordPair(
      civilian: civilian ?? this.civilian,
      undercover: undercover ?? this.undercover,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}