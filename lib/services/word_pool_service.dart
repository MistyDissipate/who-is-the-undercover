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
  static const String _assetPath = 'assets/word_pairs.json';
  static final Random _random = Random();
  static List<WordPair>? _cachedPairs;

  static Future<List<WordPair>> loadPairs() async {
    if (_cachedPairs != null) return _cachedPairs!;

    final jsonString = await rootBundle.loadString(_assetPath);
    final dynamic decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('词库格式错误：根节点必须是对象');
    }

    final dynamic rawPairs = decoded['pairs'];
    if (rawPairs is! List) {
      throw StateError('词库格式错误：pairs 必须是数组');
    }

    final pairs = rawPairs
        .whereType<Map<String, dynamic>>()
        .map(WordPair.fromJson)
        .where((pair) => pair.civilian.isNotEmpty && pair.undercover.isNotEmpty)
        .toList();

    if (pairs.isEmpty) {
      throw StateError('词库为空：请在 assets/word_pairs.json 中添加词对');
    }

    _cachedPairs = pairs;
    return _cachedPairs!;
  }

  static Future<WordPair> getRandomPair() async {
    final pairs = await loadPairs();
    final index = _random.nextInt(pairs.length);
    return pairs[index];
  }
}