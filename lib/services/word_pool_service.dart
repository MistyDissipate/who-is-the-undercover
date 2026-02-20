import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

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
}

class WordBankOption {
  final String path;
  final String category;
  final String difficulty;
  final bool enabled;

  const WordBankOption({
    required this.path,
    required this.category,
    required this.difficulty,
    required this.enabled,
  });
}

class WordPoolService {
  static const String _legacyAssetPath = 'assets/word_pairs.json';
  static const String _indexAssetPath = 'assets/wordbanks/index.json';
  static final Random _random = Random();
  static List<WordPair>? _cachedPairs;
  static List<WordBankOption>? _cachedOptions;

  static Future<List<WordPair>> loadPairs({
    Set<String>? categories,
    Set<String>? difficulties,
  }) async {
    if (_cachedPairs == null) {
      List<WordPair> pairs = [];
      try {
        pairs = await _loadFromSplitBanks();
      } catch (_) {
        pairs = [];
      }

      if (pairs.isEmpty) {
        pairs = await _loadFromLegacyBank();
      }

      if (pairs.isEmpty) {
        throw StateError('词库为空：请在 assets/wordbanks/ 或 assets/word_pairs.json 中添加词对');
      }

      _cachedPairs = pairs;
    }

    var result = _cachedPairs!;
    if (categories != null && categories.isNotEmpty) {
      result = result.where((pair) => categories.contains(pair.category)).toList();
    }
    if (difficulties != null && difficulties.isNotEmpty) {
      result = result.where((pair) => difficulties.contains(pair.difficulty)).toList();
    }

    return result;
  }

  static Future<List<WordBankOption>> loadWordBankOptions() async {
    if (_cachedOptions != null) return _cachedOptions!;

    try {
      final indexString = await rootBundle.loadString(_indexAssetPath);
      final dynamic decoded = jsonDecode(indexString);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('词库索引格式错误：根节点必须是对象');
      }

      final dynamic files = decoded['files'];
      if (files is! List) {
        throw StateError('词库索引格式错误：files 必须是数组');
      }

      final options = files.whereType<Map<String, dynamic>>().map((item) {
        return WordBankOption(
          path: (item['path'] ?? '').toString().trim(),
          category: (item['category'] ?? '').toString().trim(),
          difficulty: (item['difficulty'] ?? 'easy').toString().trim(),
          enabled: item['enabled'] != false,
        );
      }).where((item) => item.path.isNotEmpty).toList();

      _cachedOptions = options;
      return _cachedOptions!;
    } catch (_) {
      final legacyPairs = await _loadFromLegacyBank();
      final categories = legacyPairs
          .map((pair) => pair.category)
          .where((category) => category.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      _cachedOptions = categories
          .map(
            (category) => WordBankOption(
              path: _legacyAssetPath,
              category: category,
              difficulty: 'easy',
              enabled: true,
            ),
          )
          .toList();
      return _cachedOptions!;
    }
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

  static Future<List<WordPair>> _loadFromSplitBanks() async {
    final options = await loadWordBankOptions();
    final enabledOptions = options.where((option) => option.enabled).toList();

    if (enabledOptions.isEmpty) {
      return [];
    }

    final List<WordPair> merged = [];
    final Set<String> dedup = <String>{};

    for (final option in enabledOptions) {
      final path = option.path;
      if (path.isEmpty) continue;

      final defaultCategory = option.category;
      final defaultDifficulty = option.difficulty;
      final bankString = await rootBundle.loadString(path);
      final dynamic decodedBank = jsonDecode(bankString);

      if (decodedBank is! Map<String, dynamic>) continue;
      final bankCategory = (decodedBank['category'] ?? defaultCategory).toString().trim();
      final bankDifficulty = (decodedBank['difficulty'] ?? defaultDifficulty).toString().trim();

      final dynamic rawPairs = decodedBank['pairs'];
      if (rawPairs is! List) continue;

      for (final raw in rawPairs.whereType<Map<String, dynamic>>()) {
        final normalized = <String, dynamic>{
          ...raw,
          if ((raw['category'] ?? '').toString().trim().isEmpty) 'category': bankCategory,
          if ((raw['difficulty'] ?? '').toString().trim().isEmpty)
            'difficulty': bankDifficulty,
        };

        final pair = WordPair.fromJson(normalized);
        if (pair.civilian.isEmpty || pair.undercover.isEmpty) continue;

        final a = pair.civilian;
        final b = pair.undercover;
        final dedupKey = a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
        if (dedup.add(dedupKey)) {
          merged.add(pair);
        }
      }
    }

    return merged;
  }

  static Future<WordPair> getRandomPair({
    Set<String>? categories,
    Set<String>? difficulties,
  }) async {
    final pairs = await loadPairs(
      categories: categories,
      difficulties: difficulties,
    );

    if (pairs.isEmpty) {
      throw StateError('当前筛选条件下没有可用词对');
    }

    final index = _random.nextInt(pairs.length);
    return pairs[index];
  }
}