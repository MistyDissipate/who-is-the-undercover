import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class WordPair {
  final String civilian;
  final String undercover;
  final String category;

  const WordPair({
    required this.civilian,
    required this.undercover,
    required this.category,
  });

  factory WordPair.fromJson(Map<String, dynamic> json) {
    return WordPair(
      civilian: (json['civilian'] ?? '').toString().trim(),
      undercover: (json['undercover'] ?? '').toString().trim(),
      category: (json['category'] ?? '').toString().trim(),
    );
  }
}

class WordPoolService {
  static const String _legacyAssetPath = 'assets/word_pairs.json';
  static const String _indexAssetPath = 'assets/wordbanks/index.json';
  static final Random _random = Random();
  static List<WordPair>? _cachedPairs;

  static Future<List<WordPair>> loadPairs() async {
    if (_cachedPairs != null) return _cachedPairs!;

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
    return _cachedPairs!;
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
    final indexString = await rootBundle.loadString(_indexAssetPath);
    final dynamic decodedIndex = jsonDecode(indexString);

    if (decodedIndex is! Map<String, dynamic>) {
      throw StateError('词库索引格式错误：根节点必须是对象');
    }

    final dynamic files = decodedIndex['files'];
    if (files is! List) {
      throw StateError('词库索引格式错误：files 必须是数组');
    }

    final List<WordPair> merged = [];
    final Set<String> dedup = <String>{};

    for (final item in files.whereType<Map<String, dynamic>>()) {
      final enabled = item['enabled'] != false;
      if (!enabled) continue;

      final path = (item['path'] ?? '').toString().trim();
      if (path.isEmpty) continue;

      final defaultCategory = (item['category'] ?? '').toString().trim();
      final bankString = await rootBundle.loadString(path);
      final dynamic decodedBank = jsonDecode(bankString);

      if (decodedBank is! Map<String, dynamic>) continue;
      final bankCategory = (decodedBank['category'] ?? defaultCategory).toString().trim();

      final dynamic rawPairs = decodedBank['pairs'];
      if (rawPairs is! List) continue;

      for (final raw in rawPairs.whereType<Map<String, dynamic>>()) {
        final normalized = <String, dynamic>{
          ...raw,
          if ((raw['category'] ?? '').toString().trim().isEmpty) 'category': bankCategory,
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

  static Future<WordPair> getRandomPair() async {
    final pairs = await loadPairs();
    final index = _random.nextInt(pairs.length);
    return pairs[index];
  }
}